-- ETAPA 3.3 - NEEXECUTAT. Nu rulati migratia din acest fisier.
-- Rulati sectiunile separat in SQL Editor, dupa aplicarea controlata a 003.
-- Fiecare sectiune are propria tranzactie si se termina cu ROLLBACK.
-- Editorul trebuie sa poata SET ROLE authenticated/anon; nu folositi date reale.

-- PREFLIGHT MANUAL INAINTE DE 003 (interogari numai de citire, de rulat separat):
-- SELECT current_user, current_database(), has_schema_privilege('authenticated','public','USAGE');
-- SELECT n.nspname,c.relname,c.relkind,c.relrowsecurity,c.relforcerowsecurity,
--        c.relowner::regrole AS proprietar
-- FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
-- WHERE n.nspname='public' AND c.relname IN
--   ('persoane','utilizatori','cursanti','instructori','vehicule','inscrieri','programari','plati','examene')
-- ORDER BY c.relname;
-- SELECT n.nspname,c.relname,p.polname,p.polcmd,p.polpermissive,p.polroles,
--        pg_get_expr(p.polqual,p.polrelid) AS using_expr,
--        pg_get_expr(p.polwithcheck,p.polrelid) AS check_expr
-- FROM pg_policy p JOIN pg_class c ON c.oid=p.polrelid
-- JOIN pg_namespace n ON n.oid=c.relnamespace
-- WHERE n.nspname='public' AND c.relname IN
--   ('persoane','utilizatori','cursanti','instructori','vehicule','inscrieri','programari','plati','examene');
-- SELECT table_name,grantee,privilege_type FROM information_schema.role_table_grants
-- WHERE table_schema='public' AND table_name IN
--   ('persoane','utilizatori','cursanti','instructori','vehicule','inscrieri','programari','plati','examene')
-- ORDER BY table_name,grantee,privilege_type;
-- SELECT table_name,column_name,grantee,privilege_type
-- FROM information_schema.role_column_grants
-- WHERE table_schema='public' AND table_name IN
--   ('persoane','utilizatori','cursanti','instructori','vehicule','inscrieri','programari','plati','examene')
-- ORDER BY table_name,column_name,grantee;
-- SELECT nspname FROM pg_namespace WHERE nspname='intern'; -- zero randuri
-- SELECT n.nspname,p.proname,p.proowner::regrole,p.prosecdef,p.provolatile,p.proconfig
-- FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
-- WHERE n.nspname='intern'; -- zero randuri
-- Verificare MANUALA in Supabase Dashboard > Project Settings > API > Exposed schemas:
-- intern trebuie sa lipseasca. SQL nu modifica aceasta setare.

-- 1. CATALOG: poate rula fara conturile Auth de mai jos.
BEGIN;
DO $catalog$
DECLARE
  v_tabela record;
  v_coloana record;
  v_politica record;
  v_asteptate text[];
  v_nume text;
BEGIN
  IF NOT has_schema_privilege('authenticated','intern','USAGE')
     OR has_schema_privilege('authenticated','intern','CREATE')
     OR has_schema_privilege('anon','intern','USAGE')
     OR has_schema_privilege('anon','intern','CREATE') THEN
    RAISE EXCEPTION 'Privilegiile schemei intern sunt gresite';
  END IF;
  IF (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=ANY(ARRAY[
        'persoane','utilizatori','cursanti','instructori','vehicule',
        'inscrieri','programari','plati','examene'])
        AND c.relkind='r' AND c.relrowsecurity AND NOT c.relforcerowsecurity
        AND c.relowner=current_user::regrole)<>9 THEN
    RAISE EXCEPTION 'Tabelele, RLS sau proprietarul nu corespund';
  END IF;
  IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname='intern' AND p.proowner=current_user::regrole
        AND p.prosecdef AND p.provolatile='s'
        AND p.proconfig @> ARRAY['search_path=""']) <> 10 THEN
    RAISE EXCEPTION 'Helperii nu sunt cei zece SECURITY DEFINER STABLE asteptati';
  END IF;
  IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname='intern') <> 10 THEN
    RAISE EXCEPTION 'Exista helperi suplimentari in intern';
  END IF;
  FOR v_nume IN SELECT unnest(ARRAY[
    'rol_curent()','id_persoana_curenta()','id_cursant_curent()',
    'id_instructor_curent()','cursant_relevant(uuid)','instructor_relevant(uuid)',
    'persoana_relevanta(uuid)','vehicul_relevant(uuid)',
    'inscriere_a_cursantului(uuid)','inscriere_a_instructorului(uuid)'])
  LOOP
    IF to_regprocedure('intern.'||v_nume) IS NULL
       OR NOT has_function_privilege('authenticated','intern.'||v_nume,'EXECUTE')
       OR has_function_privilege('anon','intern.'||v_nume,'EXECUTE') THEN
      RAISE EXCEPTION 'EXECUTE sau semnatura neasteptata: %',v_nume;
    END IF;
  END LOOP;
  IF (SELECT count(*) FROM pg_policy p JOIN pg_class c ON c.oid=p.polrelid
      JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=ANY(ARRAY[
        'persoane','utilizatori','cursanti','instructori','vehicule',
        'inscrieri','programari','plati','examene'])) <> 10 THEN
    RAISE EXCEPTION 'Sunt asteptate exact 10 politici, inclusiv politica 002';
  END IF;
  FOR v_politica IN
    SELECT p.*,c.relname FROM pg_policy p JOIN pg_class c ON c.oid=p.polrelid
    JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname=ANY(ARRAY[
      'persoane','utilizatori','cursanti','instructori','vehicule',
      'inscrieri','programari','plati','examene'])
  LOOP
    IF v_politica.polcmd <> 'r' OR NOT v_politica.polpermissive
       OR v_politica.polroles <> ARRAY['authenticated'::regrole::oid]
       OR v_politica.polwithcheck IS NOT NULL
       OR v_politica.polname <> CASE v_politica.relname
          WHEN 'utilizatori' THEN CASE
            WHEN v_politica.polname='utilizatori_citire_profil_activ'
              THEN 'utilizatori_citire_profil_activ'
            ELSE 'utilizatori_citire_administrator' END
          ELSE v_politica.relname||'_citire_roluri' END THEN
      RAISE EXCEPTION 'Politica neasteptata pe %: %',v_politica.relname,v_politica.polname;
    END IF;
  END LOOP;
  FOR v_tabela IN
    SELECT c.oid,c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname=ANY(ARRAY[
      'persoane','utilizatori','cursanti','instructori','vehicule',
      'inscrieri','programari','plati','examene'])
  LOOP
    IF has_table_privilege('authenticated',v_tabela.oid,
                            'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
       OR has_table_privilege('anon',v_tabela.oid,
                              'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
       OR has_any_column_privilege('anon',v_tabela.oid,'SELECT, INSERT, UPDATE, REFERENCES') THEN
      RAISE EXCEPTION 'Grant la nivel de tabela sau anon: %',v_tabela.relname;
    END IF;
    v_asteptate := CASE v_tabela.relname
      WHEN 'utilizatori' THEN ARRAY['id_utilizator','rol','activ']
      WHEN 'persoane' THEN ARRAY['id_persoana','nume','prenume']
      WHEN 'cursanti' THEN ARRAY['id_cursant','id_persoana','stare']
      WHEN 'instructori' THEN ARRAY['id_instructor','id_persoana','stare']
      WHEN 'vehicule' THEN ARRAY['id_vehicul','numar_inmatriculare','marca','model','stare']
      WHEN 'inscrieri' THEN ARRAY['id_inscriere','id_cursant','id_instructor','categorie','data_inscrierii','stare','data_finalizarii']
      WHEN 'programari' THEN ARRAY['id_programare','id_inscriere','id_instructor','id_vehicul','inceput','sfarsit','stare']
      WHEN 'plati' THEN ARRAY['id_plata','id_inscriere','tip','suma','stare','data_platii']
      WHEN 'examene' THEN ARRAY['id_examen','id_inscriere','tip_examen','numar_incercare','data_examenului','stare','rezultat','punctaj']
    END;
    FOR v_coloana IN SELECT attname FROM pg_attribute
      WHERE attrelid=v_tabela.oid AND attnum>0 AND NOT attisdropped
    LOOP
      IF has_column_privilege('authenticated',v_tabela.oid,v_coloana.attname,'SELECT')
           IS DISTINCT FROM (v_coloana.attname=ANY(v_asteptate))
         OR has_column_privilege('authenticated',v_tabela.oid,v_coloana.attname,
                                 'INSERT, UPDATE, REFERENCES')
         OR has_column_privilege('anon',v_tabela.oid,v_coloana.attname,
                                 'SELECT, INSERT, UPDATE, REFERENCES') THEN
        RAISE EXCEPTION 'Grant incorect pe %.%',v_tabela.relname,v_coloana.attname;
      END IF;
    END LOOP;
  END LOOP;
  RAISE NOTICE 'Catalog Etapa 3.3: politici, RLS, helperi si granturi conforme';
END;
$catalog$;
ROLLBACK;

-- 2. END-TO-END: necesita 8 conturi Auth fictive, create MANUAL in Supabase Auth:
-- admin.demo@example.com (existent din 2B, profil administrator activ),
-- secretariat.demo@example.com, instructor.a.demo@example.com,
-- instructor.b.demo@example.com, cursant.a.demo@example.com,
-- cursant.b.demo@example.com, inactiv.demo@example.com,
-- fara.profil.demo@example.com. Ultimele 7 NU trebuie sa aiba profil public.utilizatori.
-- Nu inserati manual in auth.users. Folositi numai un proiect de dezvoltare.
BEGIN;
DO $fixture$
DECLARE
  a uuid; s uuid; ia uuid; ib uuid; ca uuid; cb uuid; x uuid; lipsa uuid;
  ps uuid; pia uuid; pib uuid; pca uuid; pcb uuid; px uuid;
  ria uuid; rib uuid; rca uuid; rcb uuid; rx uuid;
  va uuid; vb uuid; ea uuid; eb uuid;
  h1 uuid; h2 uuid; hc uuid; b1 uuid; b2 uuid;
  pa uuid; pb uuid; xa uuid; xb uuid;
  v text; v_nr bigint;
BEGIN
  SELECT id INTO a FROM auth.users WHERE email='admin.demo@example.com';
  SELECT id INTO s FROM auth.users WHERE email='secretariat.demo@example.com';
  SELECT id INTO ia FROM auth.users WHERE email='instructor.a.demo@example.com';
  SELECT id INTO ib FROM auth.users WHERE email='instructor.b.demo@example.com';
  SELECT id INTO ca FROM auth.users WHERE email='cursant.a.demo@example.com';
  SELECT id INTO cb FROM auth.users WHERE email='cursant.b.demo@example.com';
  SELECT id INTO x FROM auth.users WHERE email='inactiv.demo@example.com';
  SELECT id INTO lipsa FROM auth.users WHERE email='fara.profil.demo@example.com';
  IF a IS NULL OR s IS NULL OR ia IS NULL OR ib IS NULL OR ca IS NULL
     OR cb IS NULL OR x IS NULL OR lipsa IS NULL THEN
    RAISE EXCEPTION 'Creati mai intai toate cele 8 conturi Auth fictive listate';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.utilizatori
                 WHERE id_utilizator=a AND rol='administrator' AND activ IS TRUE)
     OR EXISTS (SELECT 1 FROM public.utilizatori
                 WHERE id_utilizator IN (s,ia,ib,ca,cb,x,lipsa)) THEN
    RAISE EXCEPTION 'Profilurile initiale nu corespund scenariului';
  END IF;
  INSERT INTO public.persoane(nume,prenume) VALUES ('Demo','Secretariat') RETURNING id_persoana INTO ps;
  INSERT INTO public.persoane(nume,prenume) VALUES ('Demo','InstructorA') RETURNING id_persoana INTO pia;
  INSERT INTO public.persoane(nume,prenume) VALUES ('Demo','InstructorB') RETURNING id_persoana INTO pib;
  INSERT INTO public.persoane(nume,prenume) VALUES ('Demo','CursantA') RETURNING id_persoana INTO pca;
  INSERT INTO public.persoane(nume,prenume) VALUES ('Demo','CursantB') RETURNING id_persoana INTO pcb;
  INSERT INTO public.persoane(nume,prenume) VALUES ('Demo','Inactiv') RETURNING id_persoana INTO px;
  INSERT INTO public.utilizatori(id_utilizator,id_persoana,rol) VALUES
    (s,ps,'secretariat'),(ia,pia,'instructor'),(ib,pib,'instructor'),
    (ca,pca,'cursant'),(cb,pcb,'cursant');
  INSERT INTO public.utilizatori(id_utilizator,id_persoana,rol,activ)
    VALUES (x,px,'cursant',false);
  INSERT INTO public.instructori(id_persoana) VALUES(pia) RETURNING id_instructor INTO ria;
  INSERT INTO public.instructori(id_persoana) VALUES(pib) RETURNING id_instructor INTO rib;
  INSERT INTO public.cursanti(id_persoana,cnp) VALUES(pca,'0000000000001') RETURNING id_cursant INTO rca;
  INSERT INTO public.cursanti(id_persoana,cnp) VALUES(pcb,'0000000000002') RETURNING id_cursant INTO rcb;
  INSERT INTO public.cursanti(id_persoana,cnp) VALUES(px,'0000000000003') RETURNING id_cursant INTO rx;
  INSERT INTO public.vehicule(numar_inmatriculare,marca,model)
    VALUES('DEMO33A','Demo','A') RETURNING id_vehicul INTO va;
  INSERT INTO public.vehicule(numar_inmatriculare,marca,model)
    VALUES('DEMO33B','Demo','B') RETURNING id_vehicul INTO vb;
  INSERT INTO public.inscrieri(id_cursant,id_instructor,tarif_curs)
    VALUES(rca,ria,1000) RETURNING id_inscriere INTO ea;
  INSERT INTO public.inscrieri(id_cursant,id_instructor,tarif_curs)
    VALUES(rcb,ria,1000) RETURNING id_inscriere INTO eb;
  -- A: sedinta finalizata, absent si anulata la instructorul A.
  INSERT INTO public.programari(id_inscriere,id_instructor,id_vehicul,inceput,sfarsit,id_utilizator_creare)
    VALUES(ea,ria,va,'2025-01-10 10:00+02','2025-01-10 11:30+02',a)
    RETURNING id_programare INTO h1;
  UPDATE public.programari SET stare='finalizata' WHERE id_programare=h1;
  INSERT INTO public.programari(id_inscriere,id_instructor,id_vehicul,inceput,sfarsit,id_utilizator_creare)
    VALUES(ea,ria,va,'2025-01-11 10:00+02','2025-01-11 11:30+02',a)
    RETURNING id_programare INTO h2;
  UPDATE public.programari SET stare='absent' WHERE id_programare=h2;
  INSERT INTO public.programari(id_inscriere,id_instructor,id_vehicul,inceput,sfarsit,id_utilizator_creare)
    VALUES(eb,ria,vb,'2025-02-01 10:00+02','2025-02-01 11:30+02',a)
    RETURNING id_programare INTO hc;
  UPDATE public.programari SET stare='anulata' WHERE id_programare=hc;
  -- Repartizare ulterioara la B. A pastreaza numai propriile sedinte istorice.
  UPDATE public.inscrieri SET id_instructor=rib WHERE id_inscriere IN (ea,eb);
  INSERT INTO public.programari(id_inscriere,id_instructor,id_vehicul,inceput,sfarsit,id_utilizator_creare)
    VALUES(ea,rib,va,'2027-01-05 10:00+02','2027-01-05 11:30+02',a)
    RETURNING id_programare INTO b1;
  INSERT INTO public.programari(id_inscriere,id_instructor,id_vehicul,inceput,sfarsit,id_utilizator_creare)
    VALUES(eb,rib,vb,'2027-01-06 10:00+02','2027-01-06 11:30+02',a)
    RETURNING id_programare INTO b2;
  INSERT INTO public.plati(id_inscriere,id_utilizator_inregistrare,tip,suma,stare)
    VALUES(ea,a,'plata',100,'confirmata') RETURNING id_plata INTO pa;
  INSERT INTO public.plati(id_inscriere,id_utilizator_inregistrare,tip,suma,stare)
    VALUES(eb,a,'plata',200,'confirmata') RETURNING id_plata INTO pb;
  INSERT INTO public.examene(id_inscriere,tip_examen,numar_incercare,data_examenului)
    VALUES(ea,'teoretic',1,'2027-02-01 10:00+02') RETURNING id_examen INTO xa;
  INSERT INTO public.examene(id_inscriere,tip_examen,numar_incercare,data_examenului)
    VALUES(eb,'teoretic',1,'2027-02-02 10:00+02') RETURNING id_examen INTO xb;
  PERFORM set_config('av.test.admin',a::text,true);
  PERFORM set_config('av.test.secretariat',s::text,true);
  PERFORM set_config('av.test.ia',ia::text,true);
  PERFORM set_config('av.test.ib',ib::text,true);
  PERFORM set_config('av.test.ca',ca::text,true);
  PERFORM set_config('av.test.cb',cb::text,true);
  PERFORM set_config('av.test.inactiv',x::text,true);
  PERFORM set_config('av.test.lipsa',lipsa::text,true);
  PERFORM set_config('av.test.rca',rca::text,true);
  PERFORM set_config('av.test.rcb',rcb::text,true);
  PERFORM set_config('av.test.pia',pia::text,true);
  PERFORM set_config('av.test.pib',pib::text,true);
  PERFORM set_config('av.test.pca',pca::text,true);
  PERFORM set_config('av.test.pcb',pcb::text,true);
  PERFORM set_config('av.test.ria',ria::text,true);
  PERFORM set_config('av.test.rib',rib::text,true);
  PERFORM set_config('av.test.va',va::text,true);
  PERFORM set_config('av.test.vb',vb::text,true);
  PERFORM set_config('av.test.ea',ea::text,true);
  PERFORM set_config('av.test.eb',eb::text,true);
  PERFORM set_config('av.test.h1',h1::text,true);
  PERFORM set_config('av.test.h2',h2::text,true);
  PERFORM set_config('av.test.hc',hc::text,true);
  PERFORM set_config('av.test.b1',b1::text,true);
  PERFORM set_config('av.test.b2',b2::text,true);
  PERFORM set_config('av.test.pa',pa::text,true);
  PERFORM set_config('av.test.pb',pb::text,true);
  PERFORM set_config('av.test.xa',xa::text,true);
  PERFORM set_config('av.test.xb',xb::text,true);
  -- Numarul tuturor randurilor, pentru a dovedi citirea completa admin/secretariat.
  FOR v IN SELECT unnest(ARRAY['persoane','cursanti','instructori','vehicule',
                               'inscrieri','programari','plati','examene','utilizatori']) LOOP
    EXECUTE format('SELECT count(*) FROM public.%I',v) INTO v_nr;
    PERFORM set_config('av.test.count_'||v,v_nr::text,true);
  END LOOP;
END;
$fixture$;

-- Actor: administrator activ.
SELECT set_config('request.jwt.claim.sub',current_setting('av.test.admin'),true);
SET LOCAL ROLE authenticated;
DO $admin$
DECLARE v_t text; v_total bigint; v_vazute bigint;
BEGIN
  IF intern.rol_curent()<>'administrator' THEN RAISE EXCEPTION 'Rol admin'; END IF;
  FOR v_t IN SELECT unnest(ARRAY['persoane','utilizatori','cursanti','instructori',
                                 'vehicule','inscrieri','programari','plati','examene']) LOOP
    EXECUTE format('SELECT count(%I) FROM public.%I',
      CASE v_t WHEN 'persoane' THEN 'id_persoana'
        WHEN 'utilizatori' THEN 'id_utilizator'
        WHEN 'cursanti' THEN 'id_cursant'
        WHEN 'instructori' THEN 'id_instructor'
        WHEN 'vehicule' THEN 'id_vehicul'
        WHEN 'inscrieri' THEN 'id_inscriere'
        WHEN 'programari' THEN 'id_programare'
        WHEN 'plati' THEN 'id_plata' ELSE 'id_examen' END,v_t) INTO v_vazute;
    v_total := current_setting('av.test.count_'||v_t)::bigint;
    IF v_vazute <> v_total THEN RAISE EXCEPTION 'Admin nu vede toate randurile din %',v_t; END IF;
  END LOOP;
  IF NOT EXISTS(SELECT 1 FROM public.utilizatori
                WHERE id_utilizator=current_setting('av.test.cb')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.plati
                   WHERE id_plata=current_setting('av.test.pb')::uuid) THEN
    RAISE EXCEPTION 'Admin nu vede toate profilurile/platile fixture';
  END IF;
  BEGIN EXECUTE 'SELECT cnp FROM public.cursanti LIMIT 1';
    RAISE EXCEPTION 'CNP permis'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN EXECUTE 'SELECT * FROM public.cursanti LIMIT 1';
    RAISE EXCEPTION 'SELECT * permis'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN EXECUTE 'SELECT telefon,email,adresa FROM public.persoane LIMIT 1';
    RAISE EXCEPTION 'Contact permis'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN EXECUTE 'SELECT tarif_curs FROM public.inscrieri LIMIT 1';
    RAISE EXCEPTION 'Tarif permis'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END;
$admin$;
RESET ROLE;

-- Actor: secretariat activ; propriul profil, toate randurile operationale.
SELECT set_config('request.jwt.claim.sub',current_setting('av.test.secretariat'),true);
SET LOCAL ROLE authenticated;
DO $secretariat$
DECLARE v_t text; v_vazute bigint; v_total bigint;
BEGIN
  IF intern.rol_curent()<>'secretariat' THEN RAISE EXCEPTION 'Rol secretariat'; END IF;
  IF (SELECT count(id_utilizator) FROM public.utilizatori)<>1 THEN
    RAISE EXCEPTION 'Secretariatul vede profiluri straine';
  END IF;
  FOR v_t IN SELECT unnest(ARRAY['persoane','cursanti','instructori','vehicule',
                                 'inscrieri','programari','plati','examene']) LOOP
    EXECUTE format('SELECT count(%I) FROM public.%I',
      CASE v_t WHEN 'persoane' THEN 'id_persoana'
        WHEN 'cursanti' THEN 'id_cursant'
        WHEN 'instructori' THEN 'id_instructor'
        WHEN 'vehicule' THEN 'id_vehicul'
        WHEN 'inscrieri' THEN 'id_inscriere'
        WHEN 'programari' THEN 'id_programare'
        WHEN 'plati' THEN 'id_plata' ELSE 'id_examen' END,v_t) INTO v_vazute;
    v_total := current_setting('av.test.count_'||v_t)::bigint;
    IF v_vazute <> v_total THEN RAISE EXCEPTION 'Secretariatul nu vede toate randurile din %',v_t; END IF;
  END LOOP;
  IF NOT EXISTS(SELECT 1 FROM public.plati WHERE id_plata=current_setting('av.test.pb')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.cursanti WHERE id_cursant=current_setting('av.test.rcb')::uuid) THEN
    RAISE EXCEPTION 'Secretariatul nu vede datele operationale fixture';
  END IF;
  BEGIN EXECUTE 'SELECT cnp FROM public.cursanti LIMIT 1';
    RAISE EXCEPTION 'CNP permis'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END;
$secretariat$;
RESET ROLE;

-- Actor: instructor A, dupa schimbarea repartizarii catre B.
SELECT set_config('request.jwt.claim.sub',current_setting('av.test.ia'),true);
SET LOCAL ROLE authenticated;
DO $instructor_a$
BEGIN
  IF (SELECT count(id_utilizator) FROM public.utilizatori)<>1
     OR NOT EXISTS(SELECT 1 FROM public.instructori
                   WHERE id_instructor=current_setting('av.test.ria')::uuid)
     OR EXISTS(SELECT 1 FROM public.instructori
               WHERE id_instructor=current_setting('av.test.rib')::uuid) THEN
    RAISE EXCEPTION 'Profil/instructor propriu versus strain';
  END IF;
  IF EXISTS(SELECT 1 FROM public.inscrieri WHERE id_inscriere=current_setting('av.test.ea')::uuid)
     OR EXISTS(SELECT 1 FROM public.examene WHERE id_examen=current_setting('av.test.xa')::uuid)
     OR EXISTS(SELECT 1 FROM public.programari WHERE id_programare=current_setting('av.test.b1')::uuid)
     OR EXISTS(SELECT 1 FROM public.programari WHERE id_programare=current_setting('av.test.b2')::uuid)
     OR EXISTS(SELECT 1 FROM public.cursanti WHERE id_cursant=current_setting('av.test.rcb')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.persoane WHERE id_persoana=current_setting('av.test.pia')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.persoane WHERE id_persoana=current_setting('av.test.pca')::uuid)
     OR EXISTS(SELECT 1 FROM public.persoane WHERE id_persoana=current_setting('av.test.pcb')::uuid) THEN
    RAISE EXCEPTION 'Instructorul A vede repartizarea B sau cursantul doar cu sedinta anulata';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.programari WHERE id_programare=current_setting('av.test.h1')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.programari WHERE id_programare=current_setting('av.test.h2')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.programari WHERE id_programare=current_setting('av.test.hc')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.cursanti WHERE id_cursant=current_setting('av.test.rca')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.vehicule WHERE id_vehicul=current_setting('av.test.va')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.vehicule WHERE id_vehicul=current_setting('av.test.vb')::uuid)
     OR EXISTS(SELECT id_plata FROM public.plati) THEN
    RAISE EXCEPTION 'Istoric finalizata/absent/anulata, vehicul sau plati gresite';
  END IF;
END;
$instructor_a$;
RESET ROLE;

-- Actor: instructor B, repartizare prezenta.
SELECT set_config('request.jwt.claim.sub',current_setting('av.test.ib'),true);
SET LOCAL ROLE authenticated;
DO $instructor_b$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.inscrieri WHERE id_inscriere=current_setting('av.test.ea')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.examene WHERE id_examen=current_setting('av.test.xa')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.cursanti WHERE id_cursant=current_setting('av.test.rca')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.cursanti WHERE id_cursant=current_setting('av.test.rcb')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.persoane WHERE id_persoana=current_setting('av.test.pib')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.persoane WHERE id_persoana=current_setting('av.test.pca')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.persoane WHERE id_persoana=current_setting('av.test.pcb')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.programari WHERE id_programare=current_setting('av.test.b1')::uuid)
     OR EXISTS(SELECT 1 FROM public.programari WHERE id_programare=current_setting('av.test.h1')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.vehicule WHERE id_vehicul=current_setting('av.test.va')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.vehicule WHERE id_vehicul=current_setting('av.test.vb')::uuid)
     OR EXISTS(SELECT id_plata FROM public.plati) THEN
    RAISE EXCEPTION 'Instructorul B vede randuri incorecte';
  END IF;
END;
$instructor_b$;
RESET ROLE;

-- Actor: cursant A, inclusiv instructorul A din sedintele sale istorice.
SELECT set_config('request.jwt.claim.sub',current_setting('av.test.ca'),true);
SET LOCAL ROLE authenticated;
DO $cursant_a$
BEGIN
  IF (SELECT count(id_utilizator) FROM public.utilizatori)<>1
     OR NOT EXISTS(SELECT 1 FROM public.cursanti WHERE id_cursant=current_setting('av.test.rca')::uuid)
     OR EXISTS(SELECT 1 FROM public.cursanti WHERE id_cursant=current_setting('av.test.rcb')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.inscrieri WHERE id_inscriere=current_setting('av.test.ea')::uuid)
     OR EXISTS(SELECT 1 FROM public.inscrieri WHERE id_inscriere=current_setting('av.test.eb')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.programari WHERE id_programare=current_setting('av.test.h1')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.programari WHERE id_programare=current_setting('av.test.b1')::uuid)
     OR EXISTS(SELECT 1 FROM public.programari WHERE id_programare=current_setting('av.test.b2')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.plati WHERE id_plata=current_setting('av.test.pa')::uuid)
     OR EXISTS(SELECT 1 FROM public.plati WHERE id_plata=current_setting('av.test.pb')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.examene WHERE id_examen=current_setting('av.test.xa')::uuid)
     OR EXISTS(SELECT 1 FROM public.examene WHERE id_examen=current_setting('av.test.xb')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.instructori WHERE id_instructor=current_setting('av.test.ria')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.instructori WHERE id_instructor=current_setting('av.test.rib')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.vehicule WHERE id_vehicul=current_setting('av.test.va')::uuid)
     OR EXISTS(SELECT 1 FROM public.vehicule WHERE id_vehicul=current_setting('av.test.vb')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.persoane WHERE id_persoana=current_setting('av.test.pca')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.persoane WHERE id_persoana=current_setting('av.test.pia')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.persoane WHERE id_persoana=current_setting('av.test.pib')::uuid)
     OR EXISTS(SELECT 1 FROM public.persoane WHERE id_persoana=current_setting('av.test.pcb')::uuid) THEN
    RAISE EXCEPTION 'Cursantul A vede date straine sau pierde date proprii';
  END IF;
END;
$cursant_a$;
RESET ROLE;

-- Actor: cursant B. Vehiculul comun A/B este vizibil numai daca are programare proprie;
-- in fixture B are doar vb, desi instructorul curent B a folosit si va.
SELECT set_config('request.jwt.claim.sub',current_setting('av.test.cb'),true);
SET LOCAL ROLE authenticated;
DO $cursant_b$
BEGIN
  IF (SELECT count(id_utilizator) FROM public.utilizatori)<>1
     OR EXISTS(SELECT 1 FROM public.cursanti WHERE id_cursant=current_setting('av.test.rca')::uuid)
     OR EXISTS(SELECT 1 FROM public.inscrieri WHERE id_inscriere=current_setting('av.test.ea')::uuid)
     OR EXISTS(SELECT 1 FROM public.programari WHERE id_programare=current_setting('av.test.b1')::uuid)
     OR EXISTS(SELECT 1 FROM public.plati WHERE id_plata=current_setting('av.test.pa')::uuid)
     OR EXISTS(SELECT 1 FROM public.examene WHERE id_examen=current_setting('av.test.xa')::uuid)
     OR EXISTS(SELECT 1 FROM public.vehicule WHERE id_vehicul=current_setting('av.test.va')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.inscrieri WHERE id_inscriere=current_setting('av.test.eb')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.examene WHERE id_examen=current_setting('av.test.xb')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.instructori WHERE id_instructor=current_setting('av.test.ria')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.instructori WHERE id_instructor=current_setting('av.test.rib')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.vehicule WHERE id_vehicul=current_setting('av.test.vb')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.programari WHERE id_programare=current_setting('av.test.b2')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.plati WHERE id_plata=current_setting('av.test.pb')::uuid)
     OR NOT EXISTS(SELECT 1 FROM public.persoane WHERE id_persoana=current_setting('av.test.pcb')::uuid)
     OR EXISTS(SELECT 1 FROM public.persoane WHERE id_persoana=current_setting('av.test.pca')::uuid) THEN
    RAISE EXCEPTION 'Cursantul B vede datele lui A sau nu vede datele proprii';
  END IF;
END;
$cursant_b$;
RESET ROLE;

-- Profil inactiv: zero randuri in toate tabelele.
SELECT set_config('request.jwt.claim.sub',current_setting('av.test.inactiv'),true);
SET LOCAL ROLE authenticated;
DO $inactiv$
DECLARE v_t text; v_nr bigint;
BEGIN
  IF intern.rol_curent() IS NOT NULL THEN RAISE EXCEPTION 'Rol inactiv'; END IF;
  FOR v_t IN SELECT unnest(ARRAY['persoane','utilizatori','cursanti','instructori',
                                 'vehicule','inscrieri','programari','plati','examene']) LOOP
    EXECUTE format('SELECT count(%I) FROM public.%I',
      CASE v_t WHEN 'persoane' THEN 'id_persoana'
        WHEN 'utilizatori' THEN 'id_utilizator'
        WHEN 'cursanti' THEN 'id_cursant'
        WHEN 'instructori' THEN 'id_instructor'
        WHEN 'vehicule' THEN 'id_vehicul'
        WHEN 'inscrieri' THEN 'id_inscriere'
        WHEN 'programari' THEN 'id_programare'
        WHEN 'plati' THEN 'id_plata' ELSE 'id_examen' END,v_t) INTO v_nr;
    IF v_nr<>0 THEN RAISE EXCEPTION 'Profilul inactiv vede %',v_t; END IF;
  END LOOP;
END;
$inactiv$;
RESET ROLE;

-- Cont Auth fara profil: zero randuri.
SELECT set_config('request.jwt.claim.sub',current_setting('av.test.lipsa'),true);
SET LOCAL ROLE authenticated;
DO $fara_profil$
DECLARE v_t text; v_nr bigint;
BEGIN
  IF intern.rol_curent() IS NOT NULL THEN RAISE EXCEPTION 'Rol fara profil'; END IF;
  FOR v_t IN SELECT unnest(ARRAY['persoane','utilizatori','cursanti','instructori',
                                 'vehicule','inscrieri','programari','plati','examene']) LOOP
    EXECUTE format('SELECT count(%I) FROM public.%I',
      CASE v_t WHEN 'persoane' THEN 'id_persoana'
        WHEN 'utilizatori' THEN 'id_utilizator'
        WHEN 'cursanti' THEN 'id_cursant'
        WHEN 'instructori' THEN 'id_instructor'
        WHEN 'vehicule' THEN 'id_vehicul'
        WHEN 'inscrieri' THEN 'id_inscriere'
        WHEN 'programari' THEN 'id_programare'
        WHEN 'plati' THEN 'id_plata' ELSE 'id_examen' END,v_t) INTO v_nr;
    IF v_nr<>0 THEN RAISE EXCEPTION 'Contul fara profil vede %',v_t; END IF;
  END LOOP;
END;
$fara_profil$;
RESET ROLE;

-- Granturile sunt comune authenticated. DML se probeaza pentru fiecare tabela;
-- WHERE FALSE evita modificari, iar TRUNCATE reusit ar fi anulat in subtranzactie.
SELECT set_config('request.jwt.claim.sub',current_setting('av.test.admin'),true);
SET LOCAL ROLE authenticated;
DO $interzis$
DECLARE v_t text; v_pk text;
BEGIN
  FOR v_t,v_pk IN SELECT * FROM (VALUES
    ('persoane','id_persoana'),('utilizatori','id_utilizator'),
    ('cursanti','id_cursant'),('instructori','id_instructor'),
    ('vehicule','id_vehicul'),('inscrieri','id_inscriere'),
    ('programari','id_programare'),('plati','id_plata'),('examene','id_examen')) t(tabela,pk)
  LOOP
    BEGIN EXECUTE format('SELECT * FROM public.%I LIMIT 1',v_t);
      RAISE EXCEPTION 'SELECT * permis pe %',v_t;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    BEGIN EXECUTE format('INSERT INTO public.%I (%I) SELECT NULL::uuid WHERE FALSE',v_t,v_pk);
      RAISE EXCEPTION 'INSERT permis pe %',v_t;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    BEGIN EXECUTE format('UPDATE public.%I SET %I=%I WHERE FALSE',v_t,v_pk,v_pk);
      RAISE EXCEPTION 'UPDATE permis pe %',v_t;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    BEGIN EXECUTE format('DELETE FROM public.%I WHERE FALSE',v_t);
      RAISE EXCEPTION 'DELETE permis pe %',v_t;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    BEGIN EXECUTE format('TRUNCATE public.%I',v_t);
      RAISE EXCEPTION 'TRUNCATE permis pe %',v_t;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  END LOOP;
END;
$interzis$;
RESET ROLE;

-- anon: fara schema intern, fara SELECT direct si fara mutatii.
SELECT set_config('request.jwt.claim.sub','',true);
SET LOCAL ROLE anon;
DO $anon$
DECLARE v_t text; v_pk text;
BEGIN
  BEGIN EXECUTE 'SELECT intern.rol_curent()';
    RAISE EXCEPTION 'anon helper permis'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  FOR v_t,v_pk IN SELECT * FROM (VALUES
    ('persoane','id_persoana'),('utilizatori','id_utilizator'),
    ('cursanti','id_cursant'),('instructori','id_instructor'),
    ('vehicule','id_vehicul'),('inscrieri','id_inscriere'),
    ('programari','id_programare'),('plati','id_plata'),('examene','id_examen')) t(tabela,pk)
  LOOP
    BEGIN EXECUTE format('SELECT %I FROM public.%I LIMIT 1',v_pk,v_t);
      RAISE EXCEPTION 'anon SELECT permis pe %',v_t;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    BEGIN EXECUTE format('INSERT INTO public.%I (%I) SELECT NULL::uuid WHERE FALSE',v_t,v_pk);
      RAISE EXCEPTION 'anon INSERT permis pe %',v_t;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    BEGIN EXECUTE format('UPDATE public.%I SET %I=%I WHERE FALSE',v_t,v_pk,v_pk);
      RAISE EXCEPTION 'anon UPDATE permis pe %',v_t;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    BEGIN EXECUTE format('DELETE FROM public.%I WHERE FALSE',v_t);
      RAISE EXCEPTION 'anon DELETE permis pe %',v_t;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    BEGIN EXECUTE format('TRUNCATE public.%I',v_t);
      RAISE EXCEPTION 'anon TRUNCATE permis pe %',v_t;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  END LOOP;
END;
$anon$;
RESET ROLE;
ROLLBACK;
