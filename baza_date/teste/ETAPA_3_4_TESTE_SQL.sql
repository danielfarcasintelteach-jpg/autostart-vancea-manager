-- Etapa 3.4A - NEEXECUTAT. Rulati sectiunile separat, dupa aplicarea controlata a 004.
-- SQL Editor trebuie sa permita SET ROLE authenticated/anon. Folositi doar proiectul demo.
-- O eroare opreste sectiunea; executati ROLLBACK in aceeasi sesiune.

-- 0. PREFLIGHT MANUAL INAINTE DE 004 (numai citire; executati separat):
-- SELECT current_user, current_database(),
--        has_database_privilege(current_user,current_database(),'CREATE') AS poate_crea_schema;
-- SELECT current_setting('transaction_isolation'); -- asteptat: read committed
-- SELECT n.nspname,c.relname,c.relrowsecurity,c.relforcerowsecurity,c.relowner::regrole
-- FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
-- WHERE n.nspname='public' AND c.relname IN
--   ('persoane','utilizatori','cursanti','instructori','vehicule',
--    'inscrieri','programari','plati','examene') ORDER BY c.relname;
-- SELECT c.relname,p.polname,p.polcmd,p.polpermissive,p.polroles,
--        pg_get_expr(p.polqual,p.polrelid) AS folosire
-- FROM pg_policy p JOIN pg_class c ON c.oid=p.polrelid
-- WHERE p.polrelid IN ('public.persoane'::regclass,'public.utilizatori'::regclass,
--   'public.cursanti'::regclass,'public.instructori'::regclass,'public.vehicule'::regclass,
--   'public.inscrieri'::regclass,'public.programari'::regclass,
--   'public.plati'::regclass,'public.examene'::regclass) ORDER BY c.relname,p.polname;
-- SELECT n.nspname,p.proname,p.proowner::regrole,p.prosecdef,p.provolatile,p.proconfig
-- FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
-- WHERE n.nspname='intern' ORDER BY p.proname;
-- SELECT nspname FROM pg_namespace WHERE nspname='operatii'; -- zero randuri
-- SELECT oid::regprocedure FROM pg_proc WHERE pronamespace='public'::regnamespace
--   AND proname='creare_programare'; -- zero randuri
-- SELECT tgname,tgenabled,tgfoid::regprocedure,tgtype FROM pg_trigger
-- WHERE tgrelid='public.programari'::regclass AND NOT tgisinternal;
-- SELECT conname,contype,pg_get_constraintdef(oid) FROM pg_constraint
-- WHERE conrelid='public.programari'::regclass ORDER BY conname;
-- Reexecutati sectiunea catalog din ETAPA_3_3_TESTE_SQL.sql si verificati
-- manual in Project Settings -> Data API -> Exposed schemas ca intern si
-- operatii nu sunt bifate. Repetati verificarea operatii dupa aplicarea 004.

-- 1. CATALOG DUPA 004: fara conturi Auth suplimentare, numai SELECT in catalog.
BEGIN;
DO $catalog$
DECLARE
  v_tabela record;
  v_coloana record;
  v_politica record;
  v_helper text;
  v_nume text;
  v_select_asteptate text[];
  v_politici text[] := ARRAY[
    'utilizatori.utilizatori_citire_profil_activ',
    'utilizatori.utilizatori_citire_administrator',
    'persoane.persoane_citire_roluri','cursanti.cursanti_citire_roluri',
    'instructori.instructori_citire_roluri','vehicule.vehicule_citire_roluri',
    'inscrieri.inscrieri_citire_roluri','programari.programari_citire_roluri',
    'plati.plati_citire_roluri','examene.examene_citire_roluri'];
  v_privata oid := to_regprocedure('operatii.creare_programare(uuid,uuid,timestamptz)');
  v_wrapper oid := to_regprocedure('public.creare_programare(uuid,uuid,timestamptz)');
BEGIN
  IF v_privata IS NULL OR v_wrapper IS NULL
     OR (SELECT count(*) FROM pg_proc WHERE pronamespace='operatii'::regnamespace)<>1
     OR (SELECT count(*) FROM pg_proc WHERE pronamespace='public'::regnamespace
         AND proname='creare_programare')<>1 THEN
    RAISE EXCEPTION 'Functiile 004 lipsesc sau exista variante suplimentare';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE oid=v_privata AND proowner=current_user::regrole
      AND prorettype='uuid'::regtype AND pronargs=3
      AND prosecdef AND provolatile='v' AND proconfig @> ARRAY['search_path=""'])
     OR NOT EXISTS (SELECT 1 FROM pg_proc WHERE oid=v_wrapper AND proowner=current_user::regrole
      AND prorettype='uuid'::regtype AND pronargs=3
      AND NOT prosecdef AND provolatile='v' AND proconfig @> ARRAY['search_path=""']) THEN
    RAISE EXCEPTION 'Semnatura sau securitatea functiilor 004 nu corespund';
  END IF;
  IF NOT has_schema_privilege('authenticated','operatii','USAGE')
     OR has_schema_privilege('authenticated','operatii','CREATE')
     OR has_schema_privilege('anon','operatii','USAGE, CREATE')
     OR NOT has_function_privilege('authenticated',v_privata,'EXECUTE')
     OR NOT has_function_privilege('authenticated',v_wrapper,'EXECUTE')
     OR has_function_privilege('anon',v_privata,'EXECUTE')
     OR has_function_privilege('anon',v_wrapper,'EXECUTE') THEN
    RAISE EXCEPTION 'Privilegiile schemelor/functiilor 004 nu corespund';
  END IF;
  IF (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=ANY(ARRAY[
        'persoane','utilizatori','cursanti','instructori','vehicule',
        'inscrieri','programari','plati','examene']) AND c.relkind='r'
        AND c.relrowsecurity AND NOT c.relforcerowsecurity
        AND c.relowner=current_user::regrole)<>9 THEN
    RAISE EXCEPTION 'Tabelele/RLS/proprietarii din 001-003 s-au schimbat';
  END IF;
  IF (SELECT count(*) FROM pg_policy p JOIN pg_class c ON c.oid=p.polrelid
      JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=ANY(ARRAY[
        'persoane','utilizatori','cursanti','instructori','vehicule',
        'inscrieri','programari','plati','examene']))<>10 THEN
    RAISE EXCEPTION 'Numarul politicilor SELECT 003 s-a schimbat';
  END IF;
  FOR v_politica IN SELECT p.*,c.relname FROM pg_policy p
      JOIN pg_class c ON c.oid=p.polrelid JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=ANY(ARRAY[
        'persoane','utilizatori','cursanti','instructori','vehicule',
        'inscrieri','programari','plati','examene']) LOOP
    IF (v_politica.relname||'.'||v_politica.polname)<>ALL(v_politici)
       OR v_politica.polcmd<>'r' OR NOT v_politica.polpermissive
       OR v_politica.polroles<>ARRAY['authenticated'::regrole::oid]
       OR v_politica.polqual IS NULL OR v_politica.polwithcheck IS NOT NULL THEN
      RAISE EXCEPTION 'Politica 003 diferita: %.%',v_politica.relname,v_politica.polname;
    END IF;
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM pg_namespace
      WHERE nspname='intern' AND nspowner=current_user::regrole)
     OR NOT has_schema_privilege('authenticated','intern','USAGE')
     OR has_schema_privilege('authenticated','intern','CREATE')
     OR has_schema_privilege('anon','intern','USAGE, CREATE')
     OR (SELECT count(*) FROM pg_proc WHERE pronamespace='intern'::regnamespace)<>10 THEN
    RAISE EXCEPTION 'Schema intern sau numarul helperilor 003 nu corespund';
  END IF;
  FOREACH v_helper IN ARRAY ARRAY[
    'rol_curent()','id_persoana_curenta()','id_cursant_curent()',
    'id_instructor_curent()','cursant_relevant(uuid)','instructor_relevant(uuid)',
    'persoana_relevanta(uuid)','vehicul_relevant(uuid)',
    'inscriere_a_cursantului(uuid)','inscriere_a_instructorului(uuid)'] LOOP
    IF to_regprocedure('intern.'||v_helper) IS NULL
       OR NOT EXISTS (SELECT 1 FROM pg_proc p
          WHERE p.oid=to_regprocedure('intern.'||v_helper)
            AND p.proowner=current_user::regrole AND p.prosecdef
            AND p.provolatile='s' AND p.proconfig @> ARRAY['search_path=""'])
       OR NOT has_function_privilege('authenticated','intern.'||v_helper,'EXECUTE')
       OR has_function_privilege('anon','intern.'||v_helper,'EXECUTE') THEN
      RAISE EXCEPTION 'Helper intern 003 modificat: %',v_helper;
    END IF;
  END LOOP;
  FOR v_tabela IN SELECT c.oid,c.relname FROM pg_class c
      JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public'
      AND c.relname=ANY(ARRAY['persoane','utilizatori','cursanti','instructori',
        'vehicule','inscrieri','programari','plati','examene']) LOOP
    IF has_table_privilege('authenticated',v_tabela.oid,
         'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
       OR has_any_column_privilege('authenticated',v_tabela.oid,'INSERT, UPDATE, REFERENCES')
       OR has_table_privilege('anon',v_tabela.oid,
         'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
       OR has_any_column_privilege('anon',v_tabela.oid,'SELECT, INSERT, UPDATE, REFERENCES') THEN
      RAISE EXCEPTION 'SELECT la nivel de tabela, DML direct sau acces anon pe %',v_tabela.relname;
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
    FOREACH v_nume IN ARRAY v_select_asteptate LOOP
      IF NOT EXISTS (SELECT 1 FROM pg_attribute a
          WHERE a.attrelid=v_tabela.oid AND a.attname=v_nume
            AND a.attnum>0 AND NOT a.attisdropped) THEN
        RAISE EXCEPTION 'Coloana SELECT asteptata lipseste: %.%',v_tabela.relname,v_nume;
      END IF;
      IF NOT has_column_privilege('authenticated',v_tabela.oid,v_nume,'SELECT') THEN
        RAISE EXCEPTION 'Grant SELECT lipsa: %.%',v_tabela.relname,v_nume;
      END IF;
    END LOOP;
    FOR v_coloana IN SELECT attname FROM pg_attribute
        WHERE attrelid=v_tabela.oid AND attnum>0 AND NOT attisdropped LOOP
      IF has_column_privilege('authenticated',v_tabela.oid,v_coloana.attname,
           'INSERT, UPDATE, REFERENCES') THEN
        RAISE EXCEPTION 'DML direct pe %.%',v_tabela.relname,v_coloana.attname;
      END IF;
      IF has_column_privilege('authenticated',v_tabela.oid,v_coloana.attname,'SELECT')
           IS DISTINCT FROM (v_coloana.attname=ANY(v_select_asteptate)) THEN
        RAISE EXCEPTION 'Grant SELECT neasteptat: %.%',v_tabela.relname,v_coloana.attname;
      END IF;
    END LOOP;
  END LOOP;
  IF has_column_privilege('authenticated','public.cursanti','cnp','SELECT') THEN
    RAISE EXCEPTION 'CNP a devenit citibil direct';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname IN ('public','operatii') AND p.proname=ANY(ARRAY[
        'creare_cursant','modifica_persoana','schimba_stare_cursant',
        'creare_instructor','modifica_instructor','schimba_stare_instructor',
        'creare_vehicul','modifica_vehicul','schimba_stare_vehicul',
        'creare_inscriere','finalizeaza_inscriere','anuleaza_inscriere',
        'realoca_instructor','anuleaza_programare','marcheaza_programare',
        'inregistreaza_plata','confirma_plata','anuleaza_plata_in_asteptare',
        'inregistreaza_rambursare','inregistreaza_examen','inregistreaza_rezultat',
        'anuleaza_examen','creare_profil','schimba_rol_profil','schimba_activ_profil',
        'corecteaza_cnp','consulta_cnp'])) THEN
    RAISE EXCEPTION 'Exista deja operatii din 3.4B/3.4C';
  END IF;
  RAISE NOTICE 'Catalog 004: wrapper/privata, 10 politici SELECT, 10 helperi, fara DML direct';
END;
$catalog$;
ROLLBACK;

-- 2. TESTE FUNCTIONALE TRANZACTIONALE. Creati MANUAL in Supabase Auth, inainte:
-- admin.demo@example.com (profil administrator activ existent),
-- secretariat.demo@example.com, instructor.a.demo@example.com,
-- cursant.a.demo@example.com, inactiv.demo@example.com,
-- fara.profil.demo@example.com. Ultimele cinci trebuie sa fie fara profil
-- public.utilizatori inainte de test. Nu inserati manual in auth.users.
-- Rulati pe baza de dezvoltare cu un rol proprietar al tabelelor.
BEGIN;
DO $fixture$
DECLARE
  a uuid; s uuid; ia uuid; ca uuid; x uuid; lipsa uuid;
  ps uuid; pia uuid; pca uuid; px uuid; pc2 uuid; pc3 uuid; pi2 uuid; pivechi uuid;
  c1 uuid; c2 uuid; c3 uuid; i1 uuid; i2 uuid; ivechi uuid;
  e1 uuid; e2 uuid; e3 uuid; eveche uuid;
  v1 uuid; v2 uuid; v3 uuid; vvechi uuid;
  t0 timestamptz; tvechi timestamptz;
BEGIN
  SELECT id INTO a FROM auth.users WHERE email='admin.demo@example.com';
  SELECT id INTO s FROM auth.users WHERE email='secretariat.demo@example.com';
  SELECT id INTO ia FROM auth.users WHERE email='instructor.a.demo@example.com';
  SELECT id INTO ca FROM auth.users WHERE email='cursant.a.demo@example.com';
  SELECT id INTO x FROM auth.users WHERE email='inactiv.demo@example.com';
  SELECT id INTO lipsa FROM auth.users WHERE email='fara.profil.demo@example.com';
  IF a IS NULL OR s IS NULL OR ia IS NULL OR ca IS NULL OR x IS NULL OR lipsa IS NULL
     OR NOT EXISTS (SELECT 1 FROM public.utilizatori
                    WHERE id_utilizator=a AND rol='administrator' AND activ IS TRUE)
     OR EXISTS (SELECT 1 FROM public.utilizatori
                WHERE id_utilizator IN (s,ia,ca,x,lipsa)) THEN
    RAISE EXCEPTION 'Pregatiti cele sase conturi Auth si profilul admin conform listei';
  END IF;
  INSERT INTO public.persoane(nume,prenume) VALUES ('Demo34','Secretariat') RETURNING id_persoana INTO ps;
  INSERT INTO public.persoane(nume,prenume) VALUES ('Demo34','InstructorA') RETURNING id_persoana INTO pia;
  INSERT INTO public.persoane(nume,prenume) VALUES ('Demo34','CursantA') RETURNING id_persoana INTO pca;
  INSERT INTO public.persoane(nume,prenume) VALUES ('Demo34','Inactiv') RETURNING id_persoana INTO px;
  INSERT INTO public.persoane(nume,prenume) VALUES ('Demo34','Cursant2') RETURNING id_persoana INTO pc2;
  INSERT INTO public.persoane(nume,prenume) VALUES ('Demo34','Cursant3') RETURNING id_persoana INTO pc3;
  INSERT INTO public.persoane(nume,prenume) VALUES ('Demo34','Instructor2') RETURNING id_persoana INTO pi2;
  INSERT INTO public.persoane(nume,prenume) VALUES ('Demo34','InstructorVechi') RETURNING id_persoana INTO pivechi;
  INSERT INTO public.utilizatori(id_utilizator,id_persoana,rol) VALUES
    (s,ps,'secretariat'),(ia,pia,'instructor'),(ca,pca,'cursant');
  INSERT INTO public.utilizatori(id_utilizator,id_persoana,rol,activ)
    VALUES (x,px,'secretariat',false);
  INSERT INTO public.cursanti(id_persoana,cnp) VALUES(pca,'0000000000034') RETURNING id_cursant INTO c1;
  INSERT INTO public.cursanti(id_persoana,cnp) VALUES(pc2,'0000000000035') RETURNING id_cursant INTO c2;
  INSERT INTO public.cursanti(id_persoana,cnp) VALUES(pc3,'0000000000036') RETURNING id_cursant INTO c3;
  INSERT INTO public.instructori(id_persoana) VALUES(pia) RETURNING id_instructor INTO i1;
  INSERT INTO public.instructori(id_persoana) VALUES(pi2) RETURNING id_instructor INTO i2;
  INSERT INTO public.instructori(id_persoana) VALUES(pivechi) RETURNING id_instructor INTO ivechi;
  INSERT INTO public.vehicule(numar_inmatriculare,marca,model)
    VALUES('DEMO34A','Demo','A') RETURNING id_vehicul INTO v1;
  INSERT INTO public.vehicule(numar_inmatriculare,marca,model)
    VALUES('DEMO34B','Demo','B') RETURNING id_vehicul INTO v2;
  INSERT INTO public.vehicule(numar_inmatriculare,marca,model)
    VALUES('DEMO34C','Demo','C') RETURNING id_vehicul INTO v3;
  INSERT INTO public.vehicule(numar_inmatriculare,marca,model)
    VALUES('DEMO34D','Demo','Vechi') RETURNING id_vehicul INTO vvechi;
  t0 := date_trunc('day',now()) + interval '30 days 10 hours';
  tvechi := date_trunc('day',now()) - interval '30 days' + interval '10 hours';
  INSERT INTO public.inscrieri(id_cursant,id_instructor,tarif_curs)
    VALUES(c1,ivechi,1000) RETURNING id_inscriere INTO eveche;
  INSERT INTO public.programari(id_inscriere,id_instructor,id_vehicul,inceput,id_utilizator_creare)
    VALUES(eveche,ivechi,vvechi,tvechi,a);
  UPDATE public.programari SET stare='finalizata' WHERE id_inscriere=eveche;
  UPDATE public.inscrieri SET stare='finalizata',data_finalizarii=current_date
    WHERE id_inscriere=eveche;
  INSERT INTO public.inscrieri(id_cursant,id_instructor,tarif_curs)
    VALUES(c1,i1,1000) RETURNING id_inscriere INTO e1;
  INSERT INTO public.inscrieri(id_cursant,id_instructor,tarif_curs)
    VALUES(c2,i1,1000) RETURNING id_inscriere INTO e2;
  INSERT INTO public.inscrieri(id_cursant,id_instructor,tarif_curs)
    VALUES(c3,i2,1000) RETURNING id_inscriere INTO e3;
  PERFORM set_config('av34.a',a::text,true); PERFORM set_config('av34.s',s::text,true);
  PERFORM set_config('av34.ia',ia::text,true); PERFORM set_config('av34.ca',ca::text,true);
  PERFORM set_config('av34.x',x::text,true); PERFORM set_config('av34.lipsa',lipsa::text,true);
  PERFORM set_config('av34.e1',e1::text,true); PERFORM set_config('av34.e2',e2::text,true);
  PERFORM set_config('av34.e3',e3::text,true); PERFORM set_config('av34.eveche',eveche::text,true);
  PERFORM set_config('av34.i1',i1::text,true); PERFORM set_config('av34.v1',v1::text,true);
  PERFORM set_config('av34.v2',v2::text,true); PERFORM set_config('av34.v3',v3::text,true);
  PERFORM set_config('av34.t0',t0::text,true);
  PERFORM set_config('av34.tvechi',tvechi::text,true);
END;
$fixture$;

-- Administrator: creare, interval consecutiv, erori de resursa/stare/conflict.
SELECT set_config('request.jwt.claim.sub',current_setting('av34.a'),true);
SET LOCAL ROLE authenticated;
DO $administrator$
DECLARE
  v_id uuid;
  v_al_doilea uuid;
  t0 timestamptz := current_setting('av34.t0')::timestamptz;
BEGIN
  v_id := public.creare_programare(current_setting('av34.e1')::uuid,
    current_setting('av34.v1')::uuid,t0);
  v_al_doilea := public.creare_programare(current_setting('av34.e1')::uuid,
    current_setting('av34.v1')::uuid,t0+interval '90 minutes');
  IF v_id IS NULL OR v_al_doilea IS NULL OR v_id=v_al_doilea THEN
    RAISE EXCEPTION 'Administratorul nu a creat doua programari consecutive';
  END IF;
  PERFORM set_config('av34.pid_admin',v_id::text,true);
  PERFORM set_config('av34.pid_consecutiv',v_al_doilea::text,true);
  BEGIN
    PERFORM public.creare_programare(gen_random_uuid(),current_setting('av34.v1')::uuid,t0);
    RAISE EXCEPTION 'Inscrierea inexistenta a fost acceptata';
  EXCEPTION WHEN SQLSTATE 'PZ002' THEN NULL; END;
  BEGIN
    PERFORM public.creare_programare(current_setting('av34.e1')::uuid,gen_random_uuid(),t0);
    RAISE EXCEPTION 'Vehiculul inexistent a fost acceptat';
  EXCEPTION WHEN SQLSTATE 'PZ002' THEN NULL; END;
  BEGIN
    PERFORM public.creare_programare(current_setting('av34.eveche')::uuid,
      current_setting('av34.v1')::uuid,t0);
    RAISE EXCEPTION 'Inscrierea finalizata a fost acceptata';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  BEGIN
    PERFORM public.creare_programare(current_setting('av34.e2')::uuid,
      current_setting('av34.v2')::uuid,t0+interval '30 minutes');
    RAISE EXCEPTION 'Suprapunerea instructorului a fost acceptata';
  EXCEPTION WHEN SQLSTATE '23P01' THEN NULL; END;
  BEGIN
    PERFORM public.creare_programare(current_setting('av34.e3')::uuid,
      current_setting('av34.v1')::uuid,t0+interval '30 minutes');
    RAISE EXCEPTION 'Suprapunerea vehiculului a fost acceptata';
  EXCEPTION WHEN SQLSTATE '23P01' THEN NULL; END;
  BEGIN
    PERFORM public.creare_programare(current_setting('av34.e1')::uuid,
      current_setting('av34.v3')::uuid,
      current_setting('av34.tvechi')::timestamptz+interval '30 minutes');
    RAISE EXCEPTION 'Suprapunerea cursantului prin inscriere veche a fost acceptata';
  EXCEPTION WHEN SQLSTATE '23P01' THEN NULL; END;
END;
$administrator$;
RESET ROLE;

-- Secretariat: aceeasi operatie, cu identitatea sa drept creator.
SELECT set_config('request.jwt.claim.sub',current_setting('av34.s'),true);
SET LOCAL ROLE authenticated;
DO $secretariat$
DECLARE v_id uuid;
BEGIN
  v_id := public.creare_programare(current_setting('av34.e2')::uuid,
    current_setting('av34.v2')::uuid,
    current_setting('av34.t0')::timestamptz+interval '3 hours');
  IF v_id IS NULL THEN RAISE EXCEPTION 'Secretariatul nu poate crea'; END IF;
  PERFORM set_config('av34.pid_secretariat',v_id::text,true);
END;
$secretariat$;
RESET ROLE;

-- Verificare privilegiata a coloanelor neexpuse prin grantul SELECT 003.
DO $rezultate$
DECLARE v_p public.programari%ROWTYPE;
BEGIN
  SELECT * INTO v_p FROM public.programari
    WHERE id_programare=current_setting('av34.pid_admin')::uuid;
  IF NOT FOUND OR v_p.id_inscriere<>current_setting('av34.e1')::uuid
     OR v_p.id_instructor<>current_setting('av34.i1')::uuid
     OR v_p.id_vehicul<>current_setting('av34.v1')::uuid
     OR v_p.id_utilizator_creare<>current_setting('av34.a')::uuid
     OR v_p.sfarsit<>v_p.inceput+interval '90 minutes'
     OR v_p.stare<>'programata' THEN
    RAISE EXCEPTION 'Instructorul, creatorul, durata sau starea programarii admin difera';
  END IF;
  SELECT * INTO v_p FROM public.programari
    WHERE id_programare=current_setting('av34.pid_secretariat')::uuid;
  IF NOT FOUND OR v_p.id_utilizator_creare<>current_setting('av34.s')::uuid
     OR v_p.id_instructor<>current_setting('av34.i1')::uuid
     OR v_p.sfarsit<>v_p.inceput+interval '90 minutes' THEN
    RAISE EXCEPTION 'Creatorul, instructorul sau durata programarii secretariat difera';
  END IF;
  IF (SELECT count(*) FROM public.programari
      WHERE id_programare IN (current_setting('av34.pid_admin')::uuid,
                             current_setting('av34.pid_consecutiv')::uuid))<>2 THEN
    RAISE EXCEPTION 'Programarile consecutive nu au fost pastrate';
  END IF;
END;
$rezultate$;

-- Resursa in service/indisponibila: 23514 provine din triggerul 001.
UPDATE public.vehicule SET stare='service' WHERE id_vehicul=current_setting('av34.v3')::uuid;
SELECT set_config('request.jwt.claim.sub',current_setting('av34.a'),true);
SET LOCAL ROLE authenticated;
DO $service$
BEGIN
  BEGIN
    PERFORM public.creare_programare(current_setting('av34.e3')::uuid,
      current_setting('av34.v3')::uuid,
      current_setting('av34.t0')::timestamptz+interval '6 hours');
    RAISE EXCEPTION 'Vehiculul service a fost acceptat';
  EXCEPTION WHEN SQLSTATE '23514' THEN NULL; END;
END;
$service$;
RESET ROLE;
UPDATE public.vehicule SET stare='indisponibil'
  WHERE id_vehicul=current_setting('av34.v3')::uuid;
SET LOCAL ROLE authenticated;
DO $indisponibil$
BEGIN
  BEGIN
    PERFORM public.creare_programare(current_setting('av34.e3')::uuid,
      current_setting('av34.v3')::uuid,
      current_setting('av34.t0')::timestamptz+interval '6 hours');
    RAISE EXCEPTION 'Vehiculul indisponibil a fost acceptat';
  EXCEPTION WHEN SQLSTATE '23514' THEN NULL; END;
END;
$indisponibil$;
RESET ROLE;

-- Instructor si cursant activi: inclusiv apelul direct al functiei private.
SELECT set_config('request.jwt.claim.sub',current_setting('av34.ia'),true);
SET LOCAL ROLE authenticated;
DO $instructor_refuzat$
BEGIN
  BEGIN
    PERFORM public.creare_programare(current_setting('av34.e1')::uuid,
      current_setting('av34.v1')::uuid,current_setting('av34.t0')::timestamptz);
    RAISE EXCEPTION 'Instructorul a creat prin wrapper';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL; END;
  BEGIN
    PERFORM operatii.creare_programare(current_setting('av34.e1')::uuid,
      current_setting('av34.v1')::uuid,current_setting('av34.t0')::timestamptz);
    RAISE EXCEPTION 'Instructorul a creat prin functia privata';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL; END;
END;
$instructor_refuzat$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('av34.ca'),true);
SET LOCAL ROLE authenticated;
DO $cursant_refuzat$
BEGIN
  BEGIN
    PERFORM public.creare_programare(current_setting('av34.e1')::uuid,
      current_setting('av34.v1')::uuid,current_setting('av34.t0')::timestamptz);
    RAISE EXCEPTION 'Cursantul a creat programare';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL; END;
END;
$cursant_refuzat$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('av34.x'),true);
SET LOCAL ROLE authenticated;
DO $inactiv_refuzat$
BEGIN
  BEGIN
    PERFORM public.creare_programare(current_setting('av34.e1')::uuid,
      current_setting('av34.v1')::uuid,current_setting('av34.t0')::timestamptz);
    RAISE EXCEPTION 'Profilul inactiv a creat programare';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL; END;
END;
$inactiv_refuzat$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',current_setting('av34.lipsa'),true);
SET LOCAL ROLE authenticated;
DO $fara_profil_refuzat$
BEGIN
  BEGIN
    PERFORM public.creare_programare(current_setting('av34.e1')::uuid,
      current_setting('av34.v1')::uuid,current_setting('av34.t0')::timestamptz);
    RAISE EXCEPTION 'Contul fara profil a creat programare';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL; END;
END;
$fara_profil_refuzat$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','',true);
SET LOCAL ROLE authenticated;
DO $fara_identitate_refuzat$
BEGIN
  BEGIN
    PERFORM public.creare_programare(current_setting('av34.e1')::uuid,
      current_setting('av34.v1')::uuid,current_setting('av34.t0')::timestamptz);
    RAISE EXCEPTION 'Cererea fara auth.uid() a creat programare';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL; END;
END;
$fara_identitate_refuzat$;
RESET ROLE;
SET LOCAL ROLE anon;
DO $anon_refuzat$
BEGIN
  BEGIN
    PERFORM public.creare_programare(current_setting('av34.e1')::uuid,
      current_setting('av34.v1')::uuid,current_setting('av34.t0')::timestamptz);
    RAISE EXCEPTION 'anon a apelat wrapperul';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM operatii.creare_programare(current_setting('av34.e1')::uuid,
      current_setting('av34.v1')::uuid,current_setting('av34.t0')::timestamptz);
    RAISE EXCEPTION 'anon a apelat functia privata';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END;
$anon_refuzat$;
RESET ROLE;
ROLLBACK;

-- 3. CONCURENTA - DOUA SESIUNI DISTINCTE, executati manual pe date demo
-- deja COMMISE: o inscriere activa, vehicul activ si o programare existenta
-- pentru acea inscriere. Nu creati conturi Auth si nu folositi date reale.
-- Inlocuiti placeholder-ele cu ID-uri si un timp suprapus programarii existente.
-- Sesiunea A (rol proprietar; tineti tranzactia deschisa):
-- BEGIN;
-- SELECT id_inscriere FROM public.inscrieri
--   WHERE id_inscriere='<ID_INSCRIERE_DEMO>'::uuid FOR UPDATE;
-- Sesiunea B (ID-ul unui cont Auth demo cu profil activ administrator/secretariat):
-- BEGIN;
-- SELECT set_config('request.jwt.claim.sub','<ID_CONT_AUTH_DEMO>',true);
-- SET LOCAL ROLE authenticated;
-- SELECT public.creare_programare('<ID_INSCRIERE_DEMO>'::uuid,
--   '<ID_VEHICUL_ACTIV_DEMO>'::uuid,'<INCEPUT_SUPRAPUS>'::timestamptz);
-- Apelul B trebuie sa astepte blocarea A. In A: ROLLBACK;
-- Dupa deblocare B trebuie sa primeasca 23P01 din conflictul deja salvat.
-- In B: ROLLBACK; verificati ca numarul programarilor nu s-a schimbat.
-- Pentru o cursa intre DOUA inserari necommise, A poate crea in BEGIN iar B
-- asteapta: daca A face ROLLBACK, B poate reusi, apoi face si B ROLLBACK.
-- Dovada refuzului dupa COMMIT A necesita un rand persistent si curatare
-- controlata separata; nu este demonstrata de un singur test cu ROLLBACK.
