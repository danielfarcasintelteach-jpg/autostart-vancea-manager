-- Etapa 3.4A - rollback structural PROPUS, NEEXECUTAT.
-- Nu sterge programarile create cat timp 004 a fost activa si nu atinge 001-003.
-- Rulati numai dupa verificarea manuala ca 004 este singura schimbare peste 003.
BEGIN;
SET LOCAL search_path = '';

DO $preflight_rollback$
DECLARE
  v_schema oid;
  v_privata oid;
  v_wrapper oid;
BEGIN
  SELECT n.oid INTO v_schema FROM pg_catalog.pg_namespace n
    WHERE n.nspname = 'operatii' AND n.nspowner = current_user::regrole;
  v_privata := pg_catalog.to_regprocedure('operatii.creare_programare(uuid,uuid,timestamptz)');
  v_wrapper := pg_catalog.to_regprocedure('public.creare_programare(uuid,uuid,timestamptz)');
  IF v_schema IS NULL OR v_privata IS NULL OR v_wrapper IS NULL THEN
    RAISE EXCEPTION 'Obiectele 004 lipsesc sau schema operatii are alt proprietar';
  END IF;
  IF pg_catalog.obj_description(v_schema, 'pg_namespace') IS DISTINCT FROM
       'AUTOSTART VANCEA Etapa 3.4A migrarea 004: operatii private, neexpuse in Data API'
     OR pg_catalog.obj_description(v_privata, 'pg_proc') IS DISTINCT FROM
       'AUTOSTART VANCEA Etapa 3.4A migrarea 004: functie privata creare programare'
     OR pg_catalog.obj_description(v_wrapper, 'pg_proc') IS DISTINCT FROM
       'AUTOSTART VANCEA Etapa 3.4A migrarea 004: wrapper RPC creare programare' THEN
    RAISE EXCEPTION 'Marcajele obiectelor 004 nu corespund';
  END IF;
  IF (SELECT count(*) FROM pg_catalog.pg_proc WHERE pronamespace = v_schema) <> 1
     OR (SELECT count(*) FROM pg_catalog.pg_proc p
          JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
          WHERE n.nspname = 'public' AND p.proname = 'creare_programare') <> 1
     OR EXISTS (SELECT 1 FROM pg_catalog.pg_class WHERE relnamespace = v_schema)
     OR EXISTS (SELECT 1 FROM pg_catalog.pg_type
                 WHERE typnamespace = v_schema AND typisdefined) THEN
    RAISE EXCEPTION 'Au aparut obiecte suplimentare in sau langa operatii';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc p
       WHERE p.oid = v_privata AND p.proowner = current_user::regrole
         AND p.prorettype = 'uuid'::regtype
         AND p.provolatile = 'v' AND p.prosecdef
         AND p.proconfig @> ARRAY['search_path=""'])
     OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc p
       WHERE p.oid = v_wrapper AND p.proowner = current_user::regrole
         AND p.prorettype = 'uuid'::regtype
         AND p.provolatile = 'v' AND NOT p.prosecdef
         AND p.proconfig @> ARRAY['search_path=""']) THEN
    RAISE EXCEPTION 'Semnaturile, proprietarii sau configuratia functiilor 004 difera';
  END IF;
  IF NOT pg_catalog.has_schema_privilege('authenticated', 'operatii', 'USAGE')
     OR pg_catalog.has_schema_privilege('authenticated', 'operatii', 'CREATE')
     OR pg_catalog.has_schema_privilege('anon', 'operatii', 'USAGE, CREATE')
     OR NOT pg_catalog.has_function_privilege('authenticated', v_privata, 'EXECUTE')
     OR NOT pg_catalog.has_function_privilege('authenticated', v_wrapper, 'EXECUTE')
     OR pg_catalog.has_function_privilege('anon', v_privata, 'EXECUTE')
     OR pg_catalog.has_function_privilege('anon', v_wrapper, 'EXECUTE') THEN
    RAISE EXCEPTION 'Privilegiile 004 au fost modificate';
  END IF;
END;
$preflight_rollback$;

REVOKE EXECUTE ON FUNCTION public.creare_programare(uuid,uuid,timestamptz)
  FROM authenticated, anon, PUBLIC;
DROP FUNCTION public.creare_programare(uuid,uuid,timestamptz) RESTRICT;
REVOKE EXECUTE ON FUNCTION operatii.creare_programare(uuid,uuid,timestamptz)
  FROM authenticated, anon, PUBLIC;
DROP FUNCTION operatii.creare_programare(uuid,uuid,timestamptz) RESTRICT;
REVOKE ALL ON SCHEMA operatii FROM authenticated, anon, PUBLIC;
DROP SCHEMA operatii RESTRICT;

-- Audit dupa eliminare, in aceeasi tranzactie: o abatere anuleaza rollback-ul.
DO $postflight_rollback$
DECLARE
  v_tabela record;
  v_coloana record;
  v_politica record;
  v_helper text;
  v_nume text;
  v_select_asteptate text[];
  v_asteptate text[] := ARRAY['persoane','utilizatori','cursanti','instructori',
    'vehicule','inscrieri','programari','plati','examene'];
  v_politici text[] := ARRAY[
    'utilizatori.utilizatori_citire_profil_activ',
    'utilizatori.utilizatori_citire_administrator',
    'persoane.persoane_citire_roluri',
    'cursanti.cursanti_citire_roluri',
    'instructori.instructori_citire_roluri',
    'vehicule.vehicule_citire_roluri',
    'inscrieri.inscrieri_citire_roluri',
    'programari.programari_citire_roluri',
    'plati.plati_citire_roluri',
    'examene.examene_citire_roluri'];
BEGIN
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_namespace WHERE nspname = 'operatii')
     OR pg_catalog.to_regprocedure('operatii.creare_programare(uuid,uuid,timestamptz)') IS NOT NULL
     OR pg_catalog.to_regprocedure('public.creare_programare(uuid,uuid,timestamptz)') IS NOT NULL THEN
    RAISE EXCEPTION 'Obiectele 004 exista inca dupa rollback';
  END IF;
  IF (SELECT count(*) FROM pg_catalog.pg_class c
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = ANY(v_asteptate)
        AND c.relkind = 'r' AND c.relrowsecurity AND NOT c.relforcerowsecurity
        AND c.relowner = current_user::regrole) <> 9 THEN
    RAISE EXCEPTION 'Cele 9 tabele, RLS sau proprietarii 001-003 nu corespund';
  END IF;
  IF (SELECT count(*) FROM pg_catalog.pg_policy p
      JOIN pg_catalog.pg_class c ON c.oid = p.polrelid
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = ANY(v_asteptate)) <> 10 THEN
    RAISE EXCEPTION 'Numarul politicilor SELECT 003 nu este 10';
  END IF;
  FOR v_politica IN
    SELECT p.*, c.relname FROM pg_catalog.pg_policy p
      JOIN pg_catalog.pg_class c ON c.oid = p.polrelid
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = ANY(v_asteptate)
  LOOP
    IF (v_politica.relname || '.' || v_politica.polname) <> ALL(v_politici)
       OR v_politica.polcmd <> 'r' OR NOT v_politica.polpermissive
       OR v_politica.polroles <> ARRAY['authenticated'::regrole::oid]
       OR v_politica.polqual IS NULL OR v_politica.polwithcheck IS NOT NULL THEN
      RAISE EXCEPTION 'Politica SELECT 003 modificata: %.%',
        v_politica.relname, v_politica.polname;
    END IF;
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_namespace
      WHERE nspname = 'intern' AND nspowner = current_user::regrole)
     OR NOT pg_catalog.has_schema_privilege('authenticated', 'intern', 'USAGE')
     OR pg_catalog.has_schema_privilege('authenticated', 'intern', 'CREATE')
     OR pg_catalog.has_schema_privilege('anon', 'intern', 'USAGE, CREATE')
     OR (SELECT count(*) FROM pg_catalog.pg_proc p
         JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'intern') <> 10 THEN
    RAISE EXCEPTION 'Schema intern sau cei 10 helperi 003 nu corespund';
  END IF;
  FOREACH v_helper IN ARRAY ARRAY[
    'rol_curent()','id_persoana_curenta()','id_cursant_curent()',
    'id_instructor_curent()','cursant_relevant(uuid)','instructor_relevant(uuid)',
    'persoana_relevanta(uuid)','vehicul_relevant(uuid)',
    'inscriere_a_cursantului(uuid)','inscriere_a_instructorului(uuid)'] LOOP
    IF pg_catalog.to_regprocedure('intern.' || v_helper) IS NULL
       OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc p
           WHERE p.oid = pg_catalog.to_regprocedure('intern.' || v_helper)
             AND p.proowner = current_user::regrole AND p.prosecdef
             AND p.provolatile = 's'
             AND p.proconfig @> ARRAY['search_path=""'])
       OR NOT pg_catalog.has_function_privilege('authenticated', 'intern.' || v_helper, 'EXECUTE')
       OR pg_catalog.has_function_privilege('anon', 'intern.' || v_helper, 'EXECUTE') THEN
      RAISE EXCEPTION 'Helper intern 003 modificat: %', v_helper;
    END IF;
  END LOOP;
  FOREACH v_helper IN ARRAY ARRAY[
    'actualizeaza_audit()','verifica_inscriere()','verifica_programare()',
    'protejeaza_vehicul()','protejeaza_instructor()','protejeaza_cursant()',
    'verifica_plata()','verifica_examen()'] LOOP
    IF pg_catalog.to_regprocedure('public.' || v_helper) IS NULL
       OR pg_catalog.has_function_privilege('anon', 'public.' || v_helper, 'EXECUTE')
       OR pg_catalog.has_function_privilege('authenticated', 'public.' || v_helper, 'EXECUTE') THEN
      RAISE EXCEPTION 'Functie trigger 001 lipsa sau accesibila direct: %', v_helper;
    END IF;
  END LOOP;
  FOR v_tabela IN
    SELECT c.oid, c.relname FROM pg_catalog.pg_class c
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = ANY(v_asteptate)
  LOOP
    IF pg_catalog.has_table_privilege('authenticated', v_tabela.oid,
         'INSERT, UPDATE, DELETE, TRUNCATE')
       OR pg_catalog.has_any_column_privilege('authenticated', v_tabela.oid,
         'INSERT, UPDATE')
       OR pg_catalog.has_table_privilege('anon', v_tabela.oid,
         'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
       OR pg_catalog.has_any_column_privilege('anon', v_tabela.oid,
         'SELECT, INSERT, UPDATE, REFERENCES') THEN
      RAISE EXCEPTION 'DML direct sau acces anon pe %', v_tabela.relname;
    END IF;
    v_select_asteptate := CASE v_tabela.relname
      WHEN 'utilizatori' THEN ARRAY['id_utilizator','rol','activ']
      WHEN 'persoane' THEN ARRAY['id_persoana','nume','prenume']
      WHEN 'cursanti' THEN ARRAY['id_cursant','id_persoana','stare']
      WHEN 'instructori' THEN ARRAY['id_instructor','id_persoana','stare']
      WHEN 'vehicule' THEN ARRAY['id_vehicul','numar_inmatriculare','marca','model','stare']
      WHEN 'inscrieri' THEN ARRAY['id_inscriere','id_cursant','id_instructor',
        'categorie','data_inscrierii','stare','data_finalizarii']
      WHEN 'programari' THEN ARRAY['id_programare','id_inscriere','id_instructor',
        'id_vehicul','inceput','sfarsit','stare']
      WHEN 'plati' THEN ARRAY['id_plata','id_inscriere','tip','suma','stare','data_platii']
      WHEN 'examene' THEN ARRAY['id_examen','id_inscriere','tip_examen',
        'numar_incercare','data_examenului','stare','rezultat','punctaj']
    END;
    IF pg_catalog.has_table_privilege('authenticated', v_tabela.oid, 'SELECT') THEN
      RAISE EXCEPTION 'SELECT la nivel de tabela neasteptat pe %', v_tabela.relname;
    END IF;
    FOREACH v_nume IN ARRAY v_select_asteptate LOOP
      IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_attribute a
          WHERE a.attrelid = v_tabela.oid AND a.attname = v_nume
            AND a.attnum > 0 AND NOT a.attisdropped) THEN
        RAISE EXCEPTION 'Coloana SELECT asteptata lipseste: %.%', v_tabela.relname, v_nume;
      END IF;
      IF NOT pg_catalog.has_column_privilege('authenticated', v_tabela.oid,
          v_nume, 'SELECT') THEN
        RAISE EXCEPTION 'Grant SELECT lipsa: %.%', v_tabela.relname, v_nume;
      END IF;
    END LOOP;
    FOR v_coloana IN
      SELECT a.attname FROM pg_catalog.pg_attribute a
      WHERE a.attrelid = v_tabela.oid AND a.attnum > 0 AND NOT a.attisdropped
    LOOP
      IF pg_catalog.has_column_privilege('authenticated', v_tabela.oid,
          v_coloana.attname, 'SELECT') IS DISTINCT FROM
          (v_coloana.attname = ANY(v_select_asteptate)) THEN
        RAISE EXCEPTION 'Grant SELECT neasteptat: %.%',
          v_tabela.relname, v_coloana.attname;
      END IF;
    END LOOP;
  END LOOP;
  IF pg_catalog.has_column_privilege('authenticated', 'public.cursanti', 'cnp', 'SELECT') THEN
    RAISE EXCEPTION 'CNP este citibil direct dupa rollback';
  END IF;
END;
$postflight_rollback$;
COMMIT;
