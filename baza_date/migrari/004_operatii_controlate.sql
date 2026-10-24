-- Etapa 3.4A - creare programare. NEAPLICAT.
-- Rulati numai dupa preflight-ul manual din ETAPA_3_4_TESTE_SQL.sql, ca proprietar
-- al obiectelor 001-003. Verificati dupa aplicare, in Supabase Dashboard:
-- Project Settings -> Data API -> Exposed schemas: operatii NU trebuie bifata.
-- Aceasta migrare nu modifica automat configuratia Data API.
BEGIN;
SET LOCAL search_path = '';

DO $preflight$
DECLARE
  v_tabela record;
  v_coloana record;
  v_politica record;
  v_helper text;
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
  IF pg_catalog.to_regrole('authenticated') IS NULL
     OR pg_catalog.to_regrole('anon') IS NULL
     OR NOT pg_catalog.has_database_privilege(current_user, current_database(), 'CREATE')
     OR NOT pg_catalog.has_schema_privilege('authenticated', 'public', 'USAGE') THEN
    RAISE EXCEPTION 'Rolurile API, dreptul CREATE sau USAGE public nu corespund';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_namespace WHERE nspname = 'operatii')
     OR EXISTS (SELECT 1 FROM pg_catalog.pg_proc p
          JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
          WHERE n.nspname = 'public' AND p.proname = 'creare_programare')
     OR pg_catalog.to_regprocedure('operatii.creare_programare(uuid,uuid,timestamptz)') IS NOT NULL THEN
    RAISE EXCEPTION 'Schema operatii sau functia/wrapperul 004 exista deja';
  END IF;
  IF (SELECT count(*) FROM pg_catalog.pg_class c
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = ANY(v_asteptate)
        AND c.relkind = 'r' AND c.relrowsecurity AND NOT c.relforcerowsecurity
        AND c.relowner = current_user::regrole) <> 9 THEN
    RAISE EXCEPTION 'Cele 9 tabele, RLS sau proprietarii nu corespund';
  END IF;
  IF (SELECT count(*) FROM pg_catalog.pg_policy p
      JOIN pg_catalog.pg_class c ON c.oid = p.polrelid
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = ANY(v_asteptate)) <> 10 THEN
    RAISE EXCEPTION 'Etapa 3.3 trebuie sa aiba exact 10 politici SELECT';
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
      RAISE EXCEPTION 'Politica SELECT neasteptata: %.%', v_politica.relname, v_politica.polname;
    END IF;
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_namespace
                 WHERE nspname = 'intern' AND nspowner = current_user::regrole)
     OR NOT pg_catalog.has_schema_privilege('authenticated', 'intern', 'USAGE')
     OR pg_catalog.has_schema_privilege('authenticated', 'intern', 'CREATE')
     OR pg_catalog.has_schema_privilege('anon', 'intern', 'USAGE, CREATE') THEN
    RAISE EXCEPTION 'Schema intern sau privilegiile ei nu corespund Etapei 3.3';
  END IF;
  IF (SELECT count(*) FROM pg_catalog.pg_proc p
      JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'intern') <> 10 THEN
    RAISE EXCEPTION 'Numarul helperilor intern nu este 10';
  END IF;
  FOREACH v_helper IN ARRAY ARRAY[
    'rol_curent()','id_persoana_curenta()','id_cursant_curent()',
    'id_instructor_curent()','cursant_relevant(uuid)','instructor_relevant(uuid)',
    'persoana_relevanta(uuid)','vehicul_relevant(uuid)',
    'inscriere_a_cursantului(uuid)','inscriere_a_instructorului(uuid)'] LOOP
    IF pg_catalog.to_regprocedure('intern.' || v_helper) IS NULL
       OR NOT pg_catalog.has_function_privilege('authenticated', 'intern.' || v_helper, 'EXECUTE')
       OR pg_catalog.has_function_privilege('anon', 'intern.' || v_helper, 'EXECUTE')
       OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc p
            WHERE p.oid = pg_catalog.to_regprocedure('intern.' || v_helper)
              AND p.proowner = current_user::regrole AND p.prosecdef
              AND p.provolatile = 's'
              AND p.proconfig @> ARRAY['search_path=""']) THEN
      RAISE EXCEPTION 'Helper intern modificat sau inaccesibil: %', v_helper;
    END IF;
  END LOOP;
  IF pg_catalog.to_regprocedure('auth.uid()') IS NULL
     OR NOT pg_catalog.has_function_privilege('authenticated', 'auth.uid()', 'EXECUTE') THEN
    RAISE EXCEPTION 'auth.uid() nu este disponibil pentru authenticated';
  END IF;
  FOREACH v_helper IN ARRAY ARRAY[
    'actualizeaza_audit()','verifica_inscriere()','verifica_programare()',
    'protejeaza_vehicul()','protejeaza_instructor()','protejeaza_cursant()',
    'verifica_plata()','verifica_examen()'] LOOP
    IF pg_catalog.to_regprocedure('public.' || v_helper) IS NULL
       OR pg_catalog.has_function_privilege('anon', 'public.' || v_helper, 'EXECUTE')
       OR pg_catalog.has_function_privilege('authenticated', 'public.' || v_helper, 'EXECUTE') THEN
      RAISE EXCEPTION 'Functie trigger 001 lipsa sau expusa direct: %', v_helper;
    END IF;
  END LOOP;
  FOR v_tabela IN
    SELECT c.oid, c.relname FROM pg_catalog.pg_class c
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = ANY(v_asteptate)
  LOOP
    IF pg_catalog.has_table_privilege('authenticated', v_tabela.oid,
           'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
       OR pg_catalog.has_any_column_privilege('authenticated', v_tabela.oid,
           'INSERT, UPDATE, REFERENCES')
       OR pg_catalog.has_table_privilege('anon', v_tabela.oid,
           'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
       OR pg_catalog.has_any_column_privilege('anon', v_tabela.oid,
           'SELECT, INSERT, UPDATE, REFERENCES') THEN
      RAISE EXCEPTION 'Grant direct neasteptat pe tabela %', v_tabela.relname;
    END IF;
    FOR v_coloana IN
      SELECT a.attname FROM pg_catalog.pg_attribute a
       WHERE a.attrelid = v_tabela.oid AND a.attnum > 0 AND NOT a.attisdropped
    LOOP
      IF pg_catalog.has_column_privilege('authenticated', v_tabela.oid,
           v_coloana.attname, 'SELECT') IS DISTINCT FROM
           (v_coloana.attname = ANY(CASE v_tabela.relname
             WHEN 'utilizatori' THEN ARRAY['id_utilizator','rol','activ']
             WHEN 'persoane' THEN ARRAY['id_persoana','nume','prenume']
             WHEN 'cursanti' THEN ARRAY['id_cursant','id_persoana','stare']
             WHEN 'instructori' THEN ARRAY['id_instructor','id_persoana','stare']
             WHEN 'vehicule' THEN ARRAY['id_vehicul','numar_inmatriculare','marca','model','stare']
             WHEN 'inscrieri' THEN ARRAY['id_inscriere','id_cursant','id_instructor','categorie','data_inscrierii','stare','data_finalizarii']
             WHEN 'programari' THEN ARRAY['id_programare','id_inscriere','id_instructor','id_vehicul','inceput','sfarsit','stare']
             WHEN 'plati' THEN ARRAY['id_plata','id_inscriere','tip','suma','stare','data_platii']
             ELSE ARRAY['id_examen','id_inscriere','tip_examen','numar_incercare','data_examenului','stare','rezultat','punctaj'] END)) THEN
        RAISE EXCEPTION 'Grant SELECT 003 modificat: %.%', v_tabela.relname, v_coloana.attname;
      END IF;
    END LOOP;
  END LOOP;
  IF pg_catalog.has_column_privilege('authenticated', 'public.cursanti', 'cnp', 'SELECT') THEN
    RAISE EXCEPTION 'CNP este citibil direct';
  END IF;
  IF EXISTS (
    SELECT 1 FROM (VALUES
      ('public.inscrieri'::regclass, 'id_inscriere', 'uuid'::regtype),
      ('public.inscrieri'::regclass, 'id_instructor', 'uuid'::regtype),
      ('public.inscrieri'::regclass, 'stare', 'character varying'::regtype),
      ('public.vehicule'::regclass, 'id_vehicul', 'uuid'::regtype),
      ('public.programari'::regclass, 'id_programare', 'uuid'::regtype),
      ('public.programari'::regclass, 'id_inscriere', 'uuid'::regtype),
      ('public.programari'::regclass, 'id_instructor', 'uuid'::regtype),
      ('public.programari'::regclass, 'id_vehicul', 'uuid'::regtype),
      ('public.programari'::regclass, 'inceput', 'timestamp with time zone'::regtype),
      ('public.programari'::regclass, 'id_utilizator_creare', 'uuid'::regtype)
    ) AS necesar(tabela, coloana, tip)
    WHERE NOT EXISTS (SELECT 1 FROM pg_catalog.pg_attribute a
      WHERE a.attrelid = necesar.tabela AND a.attname = necesar.coloana
        AND a.atttypid = necesar.tip AND NOT a.attisdropped)
  ) THEN
    RAISE EXCEPTION 'Coloanele necesare operatiei 004 nu corespund schemei 001';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_attribute
      WHERE attrelid = 'public.programari'::regclass AND attname = 'sfarsit'
        AND atttypid = 'timestamp with time zone'::regtype AND attnotnull AND NOT attisdropped)
     OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc
      WHERE oid = 'public.verifica_programare()'::regprocedure
        AND proowner = current_user::regrole AND prosecdef)
     OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_trigger
      WHERE tgrelid = 'public.programari'::regclass AND tgname = 'verifica_programare'
        AND tgfoid = 'public.verifica_programare()'::regprocedure
        AND tgenabled = 'O' AND tgtype = 23 AND NOT tgisinternal)
     OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_constraint
      WHERE conrelid = 'public.programari'::regclass
        AND conname = 'ck_programari_durata' AND contype = 'c' AND convalidated)
     OR (SELECT count(*) FROM pg_catalog.pg_constraint
      WHERE conrelid = 'public.programari'::regclass AND contype = 'x'
        AND conname IN ('ex_programari_instructor','ex_programari_vehicul')) <> 2 THEN
    RAISE EXCEPTION 'Regulile de 90 minute si anti-suprapunere din 001 nu corespund';
  END IF;
END;
$preflight$;

CREATE SCHEMA operatii;
COMMENT ON SCHEMA operatii IS 'AUTOSTART VANCEA Etapa 3.4A migrarea 004: operatii private, neexpuse in Data API';
REVOKE ALL ON SCHEMA operatii FROM PUBLIC;
REVOKE ALL ON SCHEMA operatii FROM anon, authenticated;
-- Wrapperul SECURITY INVOKER are nevoie de USAGE pe schema privata.
GRANT USAGE ON SCHEMA operatii TO authenticated;

CREATE FUNCTION operatii.creare_programare(
  p_id_inscriere uuid, p_id_vehicul uuid, p_inceput timestamptz
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor uuid;
  v_rol varchar(20);
  v_stare varchar(12);
  v_instructor uuid;
  v_id_programare uuid;
BEGIN
  v_actor := auth.uid();
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE = 'PZ001';
  END IF;
  -- FOR SHARE blocheaza UPDATE/DELETE ale profilului pana la sfarsitul tranzactiei.
  -- Nu cere blocarea exclusiva a profilului pentru aceasta citire de autorizare.
  SELECT u.rol INTO v_rol FROM public.utilizatori AS u
    WHERE u.id_utilizator = v_actor AND u.activ IS TRUE FOR SHARE;
  IF NOT FOUND OR (v_rol IN ('administrator','secretariat')) IS NOT TRUE THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE = 'PZ001';
  END IF;

  -- Ordine blocari: profil apelant -> inscriere -> trigger-ele resurselor.
  -- Blocarea inscrierii serializeaza aceasta creare cu viitoarea realocare.
  PERFORM 1 FROM public.inscrieri WHERE id_inscriere = p_id_inscriere FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Inscriere inexistenta' USING ERRCODE = 'PZ002';
  END IF;
  -- READ COMMITTED: o interogare noua dupa lock vede starea si instructorul actuale.
  SELECT i.stare, i.id_instructor INTO v_stare, v_instructor
    FROM public.inscrieri AS i WHERE i.id_inscriere = p_id_inscriere;
  IF v_stare IS DISTINCT FROM 'activa' THEN
    RAISE EXCEPTION 'Inscriere incompatibila cu o programare noua' USING ERRCODE = 'PZ003';
  END IF;
  IF p_id_vehicul IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.vehicule WHERE id_vehicul = p_id_vehicul) THEN
    RAISE EXCEPTION 'Vehicul inexistent' USING ERRCODE = 'PZ002';
  END IF;

  -- sfarsit, stare si auditul sunt stabilite de trigger/defaulturile din 001.
  INSERT INTO public.programari
    (id_inscriere, id_instructor, id_vehicul, inceput, id_utilizator_creare)
  VALUES (p_id_inscriere, v_instructor, p_id_vehicul, p_inceput, v_actor)
  RETURNING id_programare INTO v_id_programare;
  RETURN v_id_programare;
END;
$$;
COMMENT ON FUNCTION operatii.creare_programare(uuid,uuid,timestamptz)
  IS 'AUTOSTART VANCEA Etapa 3.4A migrarea 004: functie privata creare programare';
REVOKE EXECUTE ON FUNCTION operatii.creare_programare(uuid,uuid,timestamptz)
  FROM PUBLIC, anon, authenticated;
-- SECURITY INVOKER pe wrapper impune EXECUTE si pe functia apelata.
-- Functia privata verifica singura auth.uid(), profilul activ si rolul.
GRANT EXECUTE ON FUNCTION operatii.creare_programare(uuid,uuid,timestamptz)
  TO authenticated;

CREATE FUNCTION public.creare_programare(
  p_id_inscriere uuid, p_id_vehicul uuid, p_inceput timestamptz
) RETURNS uuid
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = '' AS $$
  SELECT operatii.creare_programare(p_id_inscriere, p_id_vehicul, p_inceput)
$$;
COMMENT ON FUNCTION public.creare_programare(uuid,uuid,timestamptz)
  IS 'AUTOSTART VANCEA Etapa 3.4A migrarea 004: wrapper RPC creare programare';
REVOKE EXECUTE ON FUNCTION public.creare_programare(uuid,uuid,timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.creare_programare(uuid,uuid,timestamptz)
  TO authenticated;

-- Audit post-creare in aceeasi tranzactie: orice abatere anuleaza integral 004.
DO $postflight$
DECLARE
  v_privata oid := pg_catalog.to_regprocedure('operatii.creare_programare(uuid,uuid,timestamptz)');
  v_wrapper oid := pg_catalog.to_regprocedure('public.creare_programare(uuid,uuid,timestamptz)');
  v_tabela record;
  v_politica record;
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
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_namespace
      WHERE nspname = 'operatii' AND nspowner = current_user::regrole)
     OR NOT pg_catalog.has_schema_privilege('authenticated', 'operatii', 'USAGE')
     OR pg_catalog.has_schema_privilege('authenticated', 'operatii', 'CREATE')
     OR pg_catalog.has_schema_privilege('anon', 'operatii', 'USAGE, CREATE') THEN
    RAISE EXCEPTION 'Schema operatii sau privilegiile ei nu corespund 004';
  END IF;
  IF v_privata IS NULL OR v_wrapper IS NULL
     OR (SELECT count(*) FROM pg_catalog.pg_proc p
         JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'operatii') <> 1
     OR (SELECT count(*) FROM pg_catalog.pg_proc p
         JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public' AND p.proname = 'creare_programare') <> 1 THEN
    RAISE EXCEPTION 'Functiile 004 lipsesc sau au aparut semnaturi suplimentare';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc p
      WHERE p.oid = v_privata AND p.proowner = current_user::regrole
        AND p.prorettype = 'uuid'::regtype AND p.provolatile = 'v'
        AND p.prosecdef AND p.proconfig @> ARRAY['search_path=""'])
     OR NOT pg_catalog.has_function_privilege('authenticated', v_privata, 'EXECUTE')
     OR pg_catalog.has_function_privilege('anon', v_privata, 'EXECUTE') THEN
    RAISE EXCEPTION 'Functia privata 004 sau EXECUTE nu corespunde';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc p
      WHERE p.oid = v_wrapper AND p.proowner = current_user::regrole
        AND p.prorettype = 'uuid'::regtype AND p.provolatile = 'v'
        AND NOT p.prosecdef AND p.proconfig @> ARRAY['search_path=""'])
     OR NOT pg_catalog.has_function_privilege('authenticated', v_wrapper, 'EXECUTE')
     OR pg_catalog.has_function_privilege('anon', v_wrapper, 'EXECUTE') THEN
    RAISE EXCEPTION 'Wrapperul 004 sau EXECUTE nu corespunde';
  END IF;
  IF (SELECT count(*) FROM pg_catalog.pg_policy p
      JOIN pg_catalog.pg_class c ON c.oid = p.polrelid
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = ANY(v_asteptate)) <> 10 THEN
    RAISE EXCEPTION 'Numarul politicilor SELECT 003 s-a schimbat';
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
  IF (SELECT count(*) FROM pg_catalog.pg_class c
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = ANY(v_asteptate)
        AND c.relkind = 'r') <> 9 THEN
    RAISE EXCEPTION 'Cele 9 tabele proprii nu mai corespund';
  END IF;
  FOR v_tabela IN
    SELECT c.oid, c.relname FROM pg_catalog.pg_class c
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = ANY(v_asteptate)
  LOOP
    IF pg_catalog.has_table_privilege('authenticated', v_tabela.oid,
         'INSERT, UPDATE, DELETE, TRUNCATE')
       OR pg_catalog.has_any_column_privilege('authenticated', v_tabela.oid,
         'INSERT, UPDATE') THEN
      RAISE EXCEPTION 'DML direct neasteptat pe %', v_tabela.relname;
    END IF;
  END LOOP;
  IF pg_catalog.has_column_privilege('authenticated', 'public.cursanti', 'cnp', 'SELECT') THEN
    RAISE EXCEPTION 'CNP este citibil direct dupa 004';
  END IF;
END;
$postflight$;

-- Coduri noi: PZ001 acces refuzat, PZ002 resursa absenta, PZ003 stare incompatibila.
-- Erorile native 23P01, 23505 si 23514 se propaga fara interceptare.
COMMIT;
