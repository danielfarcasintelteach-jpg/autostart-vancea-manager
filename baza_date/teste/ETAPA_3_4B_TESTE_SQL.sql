-- Etapa 3.4B: TESTE SQL, NEEXECUTAT. Numai pe baza de dezvoltare.
-- Executati fiecare sectiune separat. La eroare rulati ROLLBACK in aceeasi sesiune.
-- 1. CATALOG dupa 005: rol proprietar, fara conturi demo.
BEGIN;
SET LOCAL search_path = '';
DO $catalog$
DECLARE
  v_tabela record;
  v_coloana record;
  v_politica record;
  v_nume text;
  v_select text[];
  v_tabele text[] := ARRAY['persoane','utilizatori','cursanti','instructori',
    'vehicule','inscrieri','programari','plati','examene'];
  v_politici text[] := ARRAY[
    'utilizatori.utilizatori_citire_profil_activ',
    'utilizatori.utilizatori_citire_administrator',
    'persoane.persoane_citire_roluri','cursanti.cursanti_citire_roluri',
    'instructori.instructori_citire_roluri','vehicule.vehicule_citire_roluri',
    'inscrieri.inscrieri_citire_roluri','programari.programari_citire_roluri',
    'plati.plati_citire_roluri','examene.examene_citire_roluri'];
  v_nume_005 text[] := ARRAY[
    'creare_cursant','modifica_persoana','schimba_stare_cursant',
    'creare_instructor','modifica_instructor','schimba_stare_instructor',
    'creare_vehicul','modifica_vehicul','schimba_stare_vehicul',
    'creare_inscriere','modifica_inscriere','finalizeaza_inscriere',
    'anuleaza_inscriere','realoca_instructor','anuleaza_programare',
    'marcheaza_programare','modifica_cursant'];
  v_004_priv oid := pg_catalog.to_regprocedure(
    'operatii.creare_programare(uuid,uuid,timestamp with time zone)');
  v_004_pub oid := pg_catalog.to_regprocedure(
    'public.creare_programare(uuid,uuid,timestamp with time zone)');
BEGIN
  IF pg_catalog.to_regrole('authenticated') IS NULL
     OR pg_catalog.to_regrole('anon') IS NULL
     OR pg_catalog.to_regprocedure('auth.uid()') IS NULL
     OR NOT pg_catalog.has_function_privilege('authenticated','auth.uid()','EXECUTE')
     OR NOT pg_catalog.has_schema_privilege('authenticated','public','USAGE') THEN
    RAISE EXCEPTION 'Rolurile API sau auth.uid() nu corespund';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_namespace
      WHERE nspname='operatii' AND nspowner=current_user::regrole)
     OR NOT pg_catalog.has_schema_privilege('authenticated','operatii','USAGE')
     OR pg_catalog.has_schema_privilege('authenticated','operatii','CREATE')
     OR pg_catalog.has_schema_privilege('anon','operatii','USAGE, CREATE')
     OR (SELECT count(*) FROM pg_catalog.pg_proc
         WHERE pronamespace='operatii'::regnamespace)<>18
     OR (SELECT count(*) FROM pg_catalog.pg_proc p
         JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
         WHERE n.nspname='public' AND p.proname='creare_programare')<>1
     OR v_004_priv IS NULL OR v_004_pub IS NULL THEN
    RAISE EXCEPTION 'Schema sau functiile 004 nu corespund';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc
      WHERE oid=v_004_priv AND proowner=current_user::regrole
        AND prorettype='uuid'::regtype AND prosecdef AND provolatile='v'
        AND proconfig @> ARRAY['search_path=""'])
     OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc
      WHERE oid=v_004_pub AND proowner=current_user::regrole
        AND prorettype='uuid'::regtype AND NOT prosecdef AND provolatile='v'
        AND proconfig @> ARRAY['search_path=""'])
     OR NOT pg_catalog.has_function_privilege('authenticated',v_004_priv,'EXECUTE')
     OR NOT pg_catalog.has_function_privilege('authenticated',v_004_pub,'EXECUTE')
     OR pg_catalog.has_function_privilege('anon',v_004_priv,'EXECUTE')
     OR pg_catalog.has_function_privilege('anon',v_004_pub,'EXECUTE') THEN
    RAISE EXCEPTION 'Securitatea 004 nu corespunde';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc p
      JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname IN ('public','operatii') AND p.proname=ANY(ARRAY[
        'inregistreaza_plata','confirma_plata','anuleaza_plata_in_asteptare',
        'inregistreaza_rambursare','inregistreaza_examen',
        'inregistreaza_rezultat','anuleaza_examen','creare_profil',
        'schimba_rol_profil','schimba_activ_profil','corecteaza_cnp',
        'consulta_cnp'])) THEN
    RAISE EXCEPTION 'Operatiile 3.4C trebuie sa lipseasca inainte de 005';
  END IF;
  IF (SELECT count(*) FROM pg_catalog.pg_class c
      JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=ANY(v_tabele)
        AND c.relkind='r' AND c.relrowsecurity AND NOT c.relforcerowsecurity
        AND c.relowner=current_user::regrole)<>9 THEN
    RAISE EXCEPTION 'Tabelele 001, proprietarul sau RLS nu corespund';
  END IF;
  IF (SELECT count(*) FROM pg_catalog.pg_policy p
      JOIN pg_catalog.pg_class c ON c.oid=p.polrelid
      JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=ANY(v_tabele))<>10 THEN
    RAISE EXCEPTION 'Nu exista exact 10 politici 002-003';
  END IF;
  FOR v_politica IN SELECT p.*,c.relname FROM pg_catalog.pg_policy p
      JOIN pg_catalog.pg_class c ON c.oid=p.polrelid
      JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=ANY(v_tabele) LOOP
    IF v_politica.relname||'.'||v_politica.polname<>ALL(v_politici)
       OR v_politica.polcmd<>'r' OR NOT v_politica.polpermissive
       OR v_politica.polroles<>ARRAY['authenticated'::regrole::oid]
       OR v_politica.polqual IS NULL OR v_politica.polwithcheck IS NOT NULL THEN
      RAISE EXCEPTION 'Politica 002-003 neasteptata: %.%',
        v_politica.relname,v_politica.polname;
    END IF;
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_namespace
      WHERE nspname='intern' AND nspowner=current_user::regrole)
     OR NOT pg_catalog.has_schema_privilege('authenticated','intern','USAGE')
     OR pg_catalog.has_schema_privilege('authenticated','intern','CREATE')
     OR pg_catalog.has_schema_privilege('anon','intern','USAGE, CREATE')
     OR (SELECT count(*) FROM pg_catalog.pg_proc
         WHERE pronamespace='intern'::regnamespace)<>10 THEN
    RAISE EXCEPTION 'Schema intern nu corespunde 003';
  END IF;
  FOREACH v_nume IN ARRAY ARRAY[
    'rol_curent()','id_persoana_curenta()','id_cursant_curent()',
    'id_instructor_curent()','cursant_relevant(uuid)',
    'instructor_relevant(uuid)','persoana_relevanta(uuid)',
    'vehicul_relevant(uuid)','inscriere_a_cursantului(uuid)',
    'inscriere_a_instructorului(uuid)'] LOOP
    IF pg_catalog.to_regprocedure('intern.'||v_nume) IS NULL
       OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc
          WHERE oid=pg_catalog.to_regprocedure('intern.'||v_nume)
            AND proowner=current_user::regrole AND prosecdef
            AND provolatile='s' AND proconfig @> ARRAY['search_path=""'])
       OR NOT pg_catalog.has_function_privilege(
          'authenticated','intern.'||v_nume,'EXECUTE')
       OR pg_catalog.has_function_privilege('anon','intern.'||v_nume,'EXECUTE') THEN
      RAISE EXCEPTION 'Helper intern 003 modificat: %',v_nume;
    END IF;
  END LOOP;
  FOREACH v_nume IN ARRAY ARRAY[
    'actualizeaza_audit()','verifica_inscriere()','verifica_programare()',
    'protejeaza_vehicul()','protejeaza_instructor()',
    'protejeaza_cursant()','verifica_plata()','verifica_examen()'] LOOP
    IF pg_catalog.to_regprocedure('public.'||v_nume) IS NULL
       OR pg_catalog.has_function_privilege('authenticated',
          'public.'||v_nume,'EXECUTE')
       OR pg_catalog.has_function_privilege('anon',
          'public.'||v_nume,'EXECUTE') THEN
      RAISE EXCEPTION 'Functie-trigger 001 expusa sau lipsa: %',v_nume;
    END IF;
  END LOOP;
  IF (SELECT count(*) FROM pg_catalog.pg_trigger t
      JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
      JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=ANY(v_tabele)
        AND t.tgname='zz_audit' AND t.tgfoid='public.actualizeaza_audit()'::regprocedure
        AND t.tgenabled='O' AND t.tgtype=23 AND NOT t.tgisinternal)<>9 THEN
    RAISE EXCEPTION 'Trigger-ele de audit 001 nu corespund';
  END IF;
  IF EXISTS (SELECT 1 FROM (VALUES
      ('inscrieri','verifica_inscriere','verifica_inscriere()',23),
      ('programari','verifica_programare','verifica_programare()',23),
      ('cursanti','protejeaza_cursant','protejeaza_cursant()',19),
      ('instructori','protejeaza_instructor','protejeaza_instructor()',19),
      ('vehicule','protejeaza_vehicul','protejeaza_vehicul()',19),
      ('plati','verifica_plata','verifica_plata()',23),
      ('examene','verifica_examen','verifica_examen()',23)
    ) AS asteptat(tabela,trigger_nume,functie,tip)
    WHERE NOT EXISTS (SELECT 1 FROM pg_catalog.pg_trigger t
      JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
      JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=asteptat.tabela
        AND t.tgname=asteptat.trigger_nume
        AND t.tgfoid=pg_catalog.to_regprocedure('public.'||asteptat.functie)
        AND t.tgenabled='O' AND t.tgtype=asteptat.tip AND NOT t.tgisinternal)) THEN
    RAISE EXCEPTION 'Un trigger de business 001 lipseste';
  END IF;
  -- Unicitatile 001 sunt verificate pe coloana, nu dupa numele automat.
  IF EXISTS (SELECT 1 FROM (VALUES
      ('public.cursanti'::regclass,'cnp'),
      ('public.vehicule'::regclass,'numar_inmatriculare'),
      ('public.utilizatori'::regclass,'id_persoana'),
      ('public.cursanti'::regclass,'id_persoana'),
      ('public.instructori'::regclass,'id_persoana')
    ) AS cerut(tabela,coloana)
    WHERE NOT EXISTS (SELECT 1 FROM pg_catalog.pg_constraint u
      JOIN pg_catalog.pg_attribute a ON a.attrelid=u.conrelid
        AND a.attname=cerut.coloana AND a.attnum>0 AND NOT a.attisdropped
      JOIN pg_catalog.pg_index ix ON ix.indexrelid=u.conindid
      WHERE u.conrelid=cerut.tabela AND u.contype='u'
        AND u.convalidated AND u.conkey=ARRAY[a.attnum]
        AND ix.indrelid=cerut.tabela AND ix.indisunique AND ix.indisvalid
        AND ix.indnkeyatts=1 AND ix.indnatts=1
        AND ix.indexprs IS NULL AND ix.indpred IS NULL)) THEN
    RAISE EXCEPTION 'Lipseste o unicitate 001 pe coloana exacta';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_index x
      JOIN pg_catalog.pg_class i ON i.oid=x.indexrelid
      JOIN pg_catalog.pg_attribute a ON a.attrelid=x.indrelid
        AND a.attname='id_cursant' AND a.attnum>0 AND NOT a.attisdropped
      WHERE i.relnamespace='public'::regnamespace
        AND i.relname='uq_inscrieri_cursant_activ'
        AND x.indrelid='public.inscrieri'::regclass
        AND x.indisunique AND x.indisvalid AND x.indisready
        AND x.indnkeyatts=1 AND x.indnatts=1 AND x.indkey[0]=a.attnum
        AND x.indexprs IS NULL AND x.indpred IS NOT NULL
        AND pg_catalog.regexp_replace(
          pg_catalog.regexp_replace(
            pg_catalog.pg_get_expr(x.indpred,x.indrelid),
            '[[:space:]()]','','g'),
          '::(charactervarying|text)(\[\])?','','g')
          = 'stare=''activa''') THEN
    RAISE EXCEPTION 'Indexul pentru inscrierea activa unica nu corespunde';
  END IF;
  IF EXISTS (SELECT 1 FROM (VALUES
      ('ex_programari_instructor','id_instructor'),
      ('ex_programari_vehicul','id_vehicul')
    ) AS cerut(constrangere,coloana)
    WHERE NOT EXISTS (SELECT 1 FROM pg_catalog.pg_constraint c
      JOIN pg_catalog.pg_attribute a ON a.attrelid=c.conrelid
        AND a.attname=cerut.coloana AND a.attnum>0 AND NOT a.attisdropped
      JOIN pg_catalog.pg_index x ON x.indexrelid=c.conindid
      JOIN pg_catalog.pg_class i ON i.oid=x.indexrelid
      JOIN pg_catalog.pg_am am ON am.oid=i.relam
      JOIN pg_catalog.pg_operator egal ON egal.oid=c.conexclop[1]
      JOIN pg_catalog.pg_operator suprapunere ON suprapunere.oid=c.conexclop[2]
      WHERE c.conrelid='public.programari'::regclass
        AND c.conname=cerut.constrangere AND c.contype='x' AND c.convalidated
        AND x.indrelid=c.conrelid AND x.indisexclusion
        AND x.indisvalid AND x.indisready
        AND x.indnkeyatts=2 AND x.indnatts=2
        AND x.indkey[0]=a.attnum AND x.indkey[1]=0
        AND x.indexprs IS NOT NULL AND x.indpred IS NOT NULL
        AND am.amname='gist' AND pg_catalog.array_length(c.conexclop,1)=2
        AND egal.oprname='=' AND egal.oprnamespace='pg_catalog'::regnamespace
        AND egal.oprleft='uuid'::regtype AND egal.oprright='uuid'::regtype
        AND suprapunere.oprname='&&'
        AND suprapunere.oprnamespace='pg_catalog'::regnamespace
        AND pg_catalog.replace(pg_catalog.regexp_replace(
          pg_catalog.pg_get_expr(x.indexprs,x.indrelid),
          '[[:space:]]','','g'),'::text','')
          = 'tstzrange(inceput,sfarsit,''[)'')'
        AND pg_catalog.regexp_replace(
          pg_catalog.regexp_replace(
            pg_catalog.pg_get_expr(x.indpred,x.indrelid),
            '[[:space:]()]','','g'),
          '::(charactervarying|text)(\[\])?','','g')
          = 'stare=ANYARRAY[''programata'',''finalizata'',''absent'']')) THEN
    RAISE EXCEPTION 'Constrangerile EXCLUDE ale programarilor nu corespund';
  END IF;
  IF EXISTS (SELECT 1 FROM (VALUES
      ('public.persoane'::regclass,'id_persoana','uuid'::regtype,true),
      ('public.persoane'::regclass,'nume','character varying'::regtype,true),
      ('public.persoane'::regclass,'prenume','character varying'::regtype,true),
      ('public.persoane'::regclass,'telefon','character varying'::regtype,false),
      ('public.persoane'::regclass,'email','character varying'::regtype,false),
      ('public.persoane'::regclass,'data_nasterii','date'::regtype,false),
      ('public.persoane'::regclass,'adresa','text'::regtype,false),
      ('public.utilizatori'::regclass,'id_utilizator','uuid'::regtype,true),
      ('public.utilizatori'::regclass,'id_persoana','uuid'::regtype,true),
      ('public.utilizatori'::regclass,'rol','character varying'::regtype,true),
      ('public.utilizatori'::regclass,'activ','boolean'::regtype,true),
      ('public.cursanti'::regclass,'id_cursant','uuid'::regtype,true),
      ('public.cursanti'::regclass,'id_persoana','uuid'::regtype,true),
      ('public.cursanti'::regclass,'cnp','character varying'::regtype,true),
      ('public.cursanti'::regclass,'stare','character varying'::regtype,true),
      ('public.cursanti'::regclass,'observatii','text'::regtype,false),
      ('public.instructori'::regclass,'id_instructor','uuid'::regtype,true),
      ('public.instructori'::regclass,'id_persoana','uuid'::regtype,true),
      ('public.instructori'::regclass,'data_angajarii','date'::regtype,false),
      ('public.instructori'::regclass,'stare','character varying'::regtype,true),
      ('public.instructori'::regclass,'observatii','text'::regtype,false),
      ('public.vehicule'::regclass,'id_vehicul','uuid'::regtype,true),
      ('public.vehicule'::regclass,'numar_inmatriculare','character varying'::regtype,true),
      ('public.vehicule'::regclass,'marca','character varying'::regtype,true),
      ('public.vehicule'::regclass,'model','character varying'::regtype,true),
      ('public.vehicule'::regclass,'an_fabricatie','smallint'::regtype,false),
      ('public.vehicule'::regclass,'stare','character varying'::regtype,true),
      ('public.vehicule'::regclass,'observatii','text'::regtype,false),
      ('public.inscrieri'::regclass,'id_inscriere','uuid'::regtype,true),
      ('public.inscrieri'::regclass,'id_cursant','uuid'::regtype,true),
      ('public.inscrieri'::regclass,'id_instructor','uuid'::regtype,true),
      ('public.inscrieri'::regclass,'data_inscrierii','date'::regtype,true),
      ('public.inscrieri'::regclass,'tarif_curs','numeric'::regtype,true),
      ('public.inscrieri'::regclass,'stare','character varying'::regtype,true),
      ('public.inscrieri'::regclass,'data_finalizarii','date'::regtype,false),
      ('public.inscrieri'::regclass,'observatii','text'::regtype,false),
      ('public.programari'::regclass,'id_programare','uuid'::regtype,true),
      ('public.programari'::regclass,'id_inscriere','uuid'::regtype,true),
      ('public.programari'::regclass,'id_instructor','uuid'::regtype,true),
      ('public.programari'::regclass,'id_vehicul','uuid'::regtype,true),
      ('public.programari'::regclass,'inceput','timestamp with time zone'::regtype,true),
      ('public.programari'::regclass,'sfarsit','timestamp with time zone'::regtype,true),
      ('public.programari'::regclass,'stare','character varying'::regtype,true),
      ('public.programari'::regclass,'id_utilizator_creare','uuid'::regtype,true),
      ('public.plati'::regclass,'id_inscriere','uuid'::regtype,true)
    ) AS cerut(tabela,coloana,tip,obligatoriu)
    WHERE NOT EXISTS (SELECT 1 FROM pg_catalog.pg_attribute a
      WHERE a.attrelid=cerut.tabela AND a.attname=cerut.coloana
        AND a.atttypid=cerut.tip AND a.attnotnull=cerut.obligatoriu
        AND a.attnum>0 AND NOT a.attisdropped)) THEN
    RAISE EXCEPTION 'Coloanele folosite de 005 nu corespund 001';
  END IF;
  IF EXISTS (SELECT 1 FROM (VALUES
      ('public.persoane'::regclass,'ck_persoane_nume'),
      ('public.utilizatori'::regclass,'ck_utilizatori_rol'),
      ('public.cursanti'::regclass,'ck_cursanti_cnp'),
      ('public.cursanti'::regclass,'ck_cursanti_stare'),
      ('public.instructori'::regclass,'ck_instructori_stare'),
      ('public.vehicule'::regclass,'ck_vehicule_stare'),
      ('public.vehicule'::regclass,'ck_vehicule_numar'),
      ('public.vehicule'::regclass,'ck_vehicule_descriere'),
      ('public.vehicule'::regclass,'ck_vehicule_an'),
      ('public.inscrieri'::regclass,'ck_inscrieri_categorie'),
      ('public.inscrieri'::regclass,'ck_inscrieri_tarif'),
      ('public.inscrieri'::regclass,'ck_inscrieri_stare'),
      ('public.inscrieri'::regclass,'ck_inscrieri_finalizare'),
      ('public.inscrieri'::regclass,'ck_inscrieri_data'),
      ('public.programari'::regclass,'ck_programari_stare'),
      ('public.programari'::regclass,'ck_programari_durata')
    ) AS cerut(tabela,nume)
    WHERE NOT EXISTS (SELECT 1 FROM pg_catalog.pg_constraint c
      WHERE c.conrelid=cerut.tabela AND c.conname=cerut.nume
        AND c.contype='c' AND c.convalidated)) THEN
    RAISE EXCEPTION 'Constrangerile CHECK folosite de 005 lipsesc';
  END IF;
  FOR v_tabela IN SELECT c.oid,c.relname FROM pg_catalog.pg_class c
      JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=ANY(v_tabele) LOOP
    IF pg_catalog.has_table_privilege('authenticated',v_tabela.oid,
          'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
       OR pg_catalog.has_any_column_privilege('authenticated',v_tabela.oid,
          'INSERT, UPDATE, REFERENCES')
       OR pg_catalog.has_table_privilege('anon',v_tabela.oid,
          'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
       OR pg_catalog.has_any_column_privilege('anon',v_tabela.oid,
          'SELECT, INSERT, UPDATE, REFERENCES') THEN
      RAISE EXCEPTION 'Grant direct neasteptat pe %',v_tabela.relname;
    END IF;
    v_select := CASE v_tabela.relname
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
      ELSE ARRAY['id_examen','id_inscriere','tip_examen','numar_incercare',
        'data_examenului','stare','rezultat','punctaj'] END;
    FOREACH v_nume IN ARRAY v_select LOOP
      IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_attribute a
          WHERE a.attrelid=v_tabela.oid AND a.attname=v_nume
            AND a.attnum>0 AND NOT a.attisdropped)
         OR NOT pg_catalog.has_column_privilege(
           'authenticated',v_tabela.oid,v_nume,'SELECT') THEN
        RAISE EXCEPTION 'Coloana SELECT 003 lipsa: %.%',v_tabela.relname,v_nume;
      END IF;
    END LOOP;
    FOR v_coloana IN SELECT attname FROM pg_catalog.pg_attribute
        WHERE attrelid=v_tabela.oid AND attnum>0 AND NOT attisdropped LOOP
      IF pg_catalog.has_column_privilege('authenticated',v_tabela.oid,
          v_coloana.attname,'SELECT')
          IS DISTINCT FROM (v_coloana.attname=ANY(v_select)) THEN
        RAISE EXCEPTION 'Grant SELECT in plus: %.%',
          v_tabela.relname,v_coloana.attname;
      END IF;
    END LOOP;
  END LOOP;
  IF pg_catalog.has_column_privilege(
      'authenticated','public.cursanti','cnp','SELECT') THEN
    RAISE EXCEPTION 'CNP a devenit citibil direct';
  END IF;
  IF (SELECT count(*) FROM pg_catalog.pg_proc p
      JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname='public' AND p.proname=ANY(v_nume_005))<>17 THEN
    RAISE EXCEPTION 'Numarul wrapperilor 005 nu este 17';
  END IF;
  FOREACH v_nume IN ARRAY ARRAY[
    'creare_cursant(varchar,varchar,varchar,varchar,date,text,varchar,text)',
    'modifica_persoana(uuid,jsonb)',
    'schimba_stare_cursant(uuid,varchar)',
    'creare_instructor(varchar,varchar,varchar,varchar,date,text,date,text)',
    'modifica_instructor(uuid,jsonb)',
    'schimba_stare_instructor(uuid,varchar)',
    'creare_vehicul(varchar,varchar,varchar,smallint,text)',
    'modifica_vehicul(uuid,jsonb)',
    'schimba_stare_vehicul(uuid,varchar)',
    'creare_inscriere(uuid,uuid,numeric,text)',
    'modifica_inscriere(uuid,jsonb)',
    'finalizeaza_inscriere(uuid)',
    'anuleaza_inscriere(uuid)',
    'realoca_instructor(uuid,uuid)',
    'anuleaza_programare(uuid)',
    'marcheaza_programare(uuid,varchar)',
    'modifica_cursant(uuid,jsonb)'
  ] LOOP
    IF pg_catalog.to_regprocedure('operatii.'||v_nume) IS NULL
       OR pg_catalog.to_regprocedure('public.'||v_nume) IS NULL THEN
      RAISE EXCEPTION 'Pereche 005 lipsa: %',v_nume;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc p
        WHERE p.oid=pg_catalog.to_regprocedure('operatii.'||v_nume)
          AND p.proowner=current_user::regrole
          AND p.prorettype='uuid'::regtype AND p.prosecdef
          AND p.provolatile='v' AND p.proconfig @> ARRAY['search_path=""'])
       OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc p
        WHERE p.oid=pg_catalog.to_regprocedure('public.'||v_nume)
          AND p.proowner=current_user::regrole
          AND p.prorettype='uuid'::regtype AND NOT p.prosecdef
          AND p.provolatile='v' AND p.proconfig @> ARRAY['search_path=""'])
       OR pg_catalog.obj_description(
          pg_catalog.to_regprocedure('operatii.'||v_nume),'pg_proc')
          IS DISTINCT FROM
          'AUTOSTART VANCEA Etapa 3.4B migrarea 005: functie privata '||
          pg_catalog.split_part(v_nume,'(',1)
       OR pg_catalog.obj_description(
          pg_catalog.to_regprocedure('public.'||v_nume),'pg_proc')
          IS DISTINCT FROM
          'AUTOSTART VANCEA Etapa 3.4B migrarea 005: wrapper RPC '||
          pg_catalog.split_part(v_nume,'(',1)
       OR NOT pg_catalog.has_function_privilege('authenticated',
          pg_catalog.to_regprocedure('operatii.'||v_nume),'EXECUTE')
       OR NOT pg_catalog.has_function_privilege('authenticated',
          pg_catalog.to_regprocedure('public.'||v_nume),'EXECUTE')
       OR pg_catalog.has_function_privilege('anon',
          pg_catalog.to_regprocedure('operatii.'||v_nume),'EXECUTE')
       OR pg_catalog.has_function_privilege('anon',
          pg_catalog.to_regprocedure('public.'||v_nume),'EXECUTE') THEN
      RAISE EXCEPTION 'Securitatea sau marcajul perechii 005 nu corespunde: %',
        v_nume;
    END IF;
  END LOOP;
END;
$catalog$;
ROLLBACK;

-- 2. SCENARII FUNCTIONALE TRANZACTIONALE (pregatire mai jos).
-- Pregatiti MANUAL in Supabase Auth: admin.demo@example.com (profil activ
-- administrator existent), plus secretariat.demo@example.com,
-- instructor.a.demo@example.com, instructor.b.demo@example.com,
-- cursant.a.demo@example.com, inactiv.demo@example.com si
-- fara.profil.demo@example.com. Ultimele sase trebuie sa nu aiba profil.
-- Nu creati conturi direct in auth.users. Toate randurile de mai jos dispar
-- prin ROLLBACK. Rulati pe baza de dezvoltare ca proprietar al tabelelor.
BEGIN;
SET LOCAL search_path = '';
DO $fixture$
DECLARE
  a uuid; s uuid; ia uuid; ib uuid; ca uuid; x uuid; lipsa uuid;
  pa uuid; ps uuid; pia uuid; pib uuid; pca uuid; px uuid;
  c1 uuid; i1 uuid; i2 uuid; v1 uuid; v2 uuid; e1 uuid;
  t_past timestamptz := pg_catalog.clock_timestamp()-interval '30 days';
  t_future timestamptz := pg_catalog.clock_timestamp()+interval '30 days';
BEGIN
  SELECT id INTO a FROM auth.users WHERE email='admin.demo@example.com';
  SELECT id INTO s FROM auth.users WHERE email='secretariat.demo@example.com';
  SELECT id INTO ia FROM auth.users WHERE email='instructor.a.demo@example.com';
  SELECT id INTO ib FROM auth.users WHERE email='instructor.b.demo@example.com';
  SELECT id INTO ca FROM auth.users WHERE email='cursant.a.demo@example.com';
  SELECT id INTO x FROM auth.users WHERE email='inactiv.demo@example.com';
  SELECT id INTO lipsa FROM auth.users WHERE email='fara.profil.demo@example.com';
  IF a IS NULL OR s IS NULL OR ia IS NULL OR ib IS NULL OR ca IS NULL
     OR x IS NULL OR lipsa IS NULL
     OR NOT EXISTS (SELECT 1 FROM public.utilizatori
       WHERE id_utilizator=a AND rol='administrator' AND activ IS TRUE)
     OR EXISTS (SELECT 1 FROM public.utilizatori
       WHERE id_utilizator IN (s,ia,ib,ca,x,lipsa)) THEN
    RAISE EXCEPTION 'Pregatiti conturile Auth si profilul admin demo';
  END IF;
  SELECT id_persoana INTO pa FROM public.utilizatori WHERE id_utilizator=a;
  INSERT INTO public.persoane(nume,prenume) VALUES('Demo35','Secretariat')
    RETURNING id_persoana INTO ps;
  INSERT INTO public.persoane(nume,prenume) VALUES('Demo35','InstructorA')
    RETURNING id_persoana INTO pia;
  INSERT INTO public.persoane(nume,prenume) VALUES('Demo35','InstructorB')
    RETURNING id_persoana INTO pib;
  INSERT INTO public.persoane(nume,prenume) VALUES('Demo35','CursantA')
    RETURNING id_persoana INTO pca;
  INSERT INTO public.persoane(nume,prenume) VALUES('Demo35','Inactiv')
    RETURNING id_persoana INTO px;
  INSERT INTO public.utilizatori(id_utilizator,id_persoana,rol) VALUES
    (s,ps,'secretariat'),(ia,pia,'instructor'),(ib,pib,'instructor'),
    (ca,pca,'cursant');
  INSERT INTO public.utilizatori(id_utilizator,id_persoana,rol,activ)
    VALUES(x,px,'secretariat',false);
  INSERT INTO public.cursanti(id_persoana,cnp)
    VALUES(pca,'0000000000501') RETURNING id_cursant INTO c1;
  -- Persoana admin este si cursant: interdictia secretariatului are prioritate.
  IF NOT EXISTS (SELECT 1 FROM public.cursanti WHERE id_persoana=pa) THEN
    INSERT INTO public.cursanti(id_persoana,cnp)
      VALUES(pa,'0000000000505');
  END IF;
  INSERT INTO public.instructori(id_persoana)
    VALUES(pia) RETURNING id_instructor INTO i1;
  INSERT INTO public.instructori(id_persoana)
    VALUES(pib) RETURNING id_instructor INTO i2;
  INSERT INTO public.vehicule(numar_inmatriculare,marca,model)
    VALUES('DEMO35A','Demo','A') RETURNING id_vehicul INTO v1;
  INSERT INTO public.vehicule(numar_inmatriculare,marca,model)
    VALUES('DEMO35B','Demo','B') RETURNING id_vehicul INTO v2;
  INSERT INTO public.inscrieri(id_cursant,id_instructor,tarif_curs)
    VALUES(c1,i1,1000) RETURNING id_inscriere INTO e1;
  PERFORM pg_catalog.set_config('av35.a',a::text,true);
  PERFORM pg_catalog.set_config('av35.s',s::text,true);
  PERFORM pg_catalog.set_config('av35.ia',ia::text,true);
  PERFORM pg_catalog.set_config('av35.ib',ib::text,true);
  PERFORM pg_catalog.set_config('av35.ca',ca::text,true);
  PERFORM pg_catalog.set_config('av35.x',x::text,true);
  PERFORM pg_catalog.set_config('av35.lipsa',lipsa::text,true);
  PERFORM pg_catalog.set_config('av35.pa',pa::text,true);
  PERFORM pg_catalog.set_config('av35.c1',c1::text,true);
  PERFORM pg_catalog.set_config('av35.i1',i1::text,true);
  PERFORM pg_catalog.set_config('av35.i2',i2::text,true);
  PERFORM pg_catalog.set_config('av35.v1',v1::text,true);
  PERFORM pg_catalog.set_config('av35.v2',v2::text,true);
  PERFORM pg_catalog.set_config('av35.e1',e1::text,true);
  PERFORM pg_catalog.set_config('av35.past',t_past::text,true);
  PERFORM pg_catalog.set_config('av35.future',t_future::text,true);
END;
$fixture$;

-- Administrator: toate creatiile, cele cinci patch-uri, starile, 004,
-- realocarea, anularea si finalizarea. ID-urile sunt pastrate local.
SELECT pg_catalog.set_config('request.jwt.claim.sub',
  pg_catalog.current_setting('av35.a'),true);
SET LOCAL ROLE authenticated;
DO $admin_pozitiv$
DECLARE
  c2 uuid; cr uuid; i3 uuid; v3 uuid; e2 uuid; er uuid;
  p2 uuid; pid_future uuid; pid_past uuid; pid_ia1 uuid; pid_ia2 uuid;
  pid_ongoing uuid; pid_e1_future uuid; pid_rpast uuid; pid_rfuture uuid;
  t_past timestamptz := pg_catalog.current_setting('av35.past')::timestamptz;
  t_future timestamptz := pg_catalog.current_setting('av35.future')::timestamptz;
BEGIN
  c2 := public.creare_cursant('Demo35','CursantNou',NULL,NULL,NULL,NULL,
    '0000000000502',NULL);
  cr := public.creare_cursant('Demo35','Realocare',NULL,NULL,NULL,NULL,
    '0000000000503',NULL);
  SELECT id_persoana INTO p2 FROM public.cursanti WHERE id_cursant=c2;
  PERFORM public.modifica_persoana(p2,
    '{"nume":"Demo35Edit","telefon":"0712345678"}'::jsonb);
  PERFORM public.modifica_persoana(p2,'{"telefon":null}'::jsonb);
  PERFORM public.modifica_persoana(
    pg_catalog.current_setting('av35.pa')::uuid,
    '{"nume":"Demo35AdminEdit"}'::jsonb);
  PERFORM public.modifica_cursant(c2,'{"observatii":"nota"}'::jsonb);
  PERFORM public.modifica_cursant(c2,'{"observatii":null}'::jsonb);
  PERFORM public.schimba_stare_cursant(c2,'inactiv');
  PERFORM public.schimba_stare_cursant(c2,'activ');

  i3 := public.creare_instructor('Demo35','InstructorNou',NULL,NULL,NULL,
    NULL,NULL,NULL);
  PERFORM public.modifica_instructor(i3,
    '{"data_angajarii":"2025-01-15","observatii":"nota"}'::jsonb);
  PERFORM public.modifica_instructor(i3,'{"observatii":null}'::jsonb);
  PERFORM public.schimba_stare_instructor(i3,'inactiv');
  PERFORM public.schimba_stare_instructor(i3,'activ');

  v3 := public.creare_vehicul('DEMO35C','Demo','C',2020::smallint,NULL::text);
  PERFORM public.modifica_vehicul(v3,
    '{"numar_inmatriculare":"DEMO35D","an_fabricatie":2021}'::jsonb);
  PERFORM public.modifica_vehicul(v3,'{"an_fabricatie":null}'::jsonb);
  PERFORM public.schimba_stare_vehicul(v3,'service');
  PERFORM public.schimba_stare_vehicul(v3,'activ');

  e2 := public.creare_inscriere(c2,i3,1200,NULL);
  IF NOT EXISTS (SELECT 1 FROM public.inscrieri
      WHERE id_inscriere=e2 AND categorie='B'
        AND data_inscrierii=(pg_catalog.clock_timestamp()
          AT TIME ZONE 'Europe/Bucharest')::date
        AND stare='activa') THEN
    RAISE EXCEPTION 'Valorile initiale RPC ale inscrierii nu corespund';
  END IF;
  PERFORM public.modifica_inscriere(e2,
    '{"tarif_curs":1300,"observatii":"tarif corectat"}'::jsonb);
  PERFORM public.modifica_inscriere(e2,'{"observatii":null}'::jsonb);
  PERFORM public.realoca_instructor(e2,
    pg_catalog.current_setting('av35.i1')::uuid);
  pid_future := public.creare_programare(e2,v3,t_future);
  PERFORM public.anuleaza_programare(pid_future);
  pid_past := public.creare_programare(e2,v3,t_past);
  PERFORM public.marcheaza_programare(pid_past,'finalizata');
  PERFORM public.finalizeaza_inscriere(e2);

  -- 3.4B nu poate inchide e1 cat timp are sedinte programata, chiar trecute.
  pid_ia1 := public.creare_programare(
    pg_catalog.current_setting('av35.e1')::uuid,
    pg_catalog.current_setting('av35.v1')::uuid,t_past+interval '4 hours');
  pid_ia2 := public.creare_programare(
    pg_catalog.current_setting('av35.e1')::uuid,
    pg_catalog.current_setting('av35.v1')::uuid,t_past+interval '8 hours');
  pid_ongoing := public.creare_programare(
    pg_catalog.current_setting('av35.e1')::uuid,
    pg_catalog.current_setting('av35.v1')::uuid,
    pg_catalog.clock_timestamp()-interval '30 minutes');
  pid_e1_future := public.creare_programare(
    pg_catalog.current_setting('av35.e1')::uuid,
    pg_catalog.current_setting('av35.v1')::uuid,t_future+interval '3 hours');

  er := public.creare_inscriere(cr,
    pg_catalog.current_setting('av35.i1')::uuid,1000,NULL);
  pid_rpast := public.creare_programare(er,
    pg_catalog.current_setting('av35.v2')::uuid,t_past+interval '12 hours');
  pid_rfuture := public.creare_programare(er,
    pg_catalog.current_setting('av35.v2')::uuid,t_future+interval '8 hours');
  PERFORM pg_catalog.set_config('av35.c2',c2::text,true);
  PERFORM pg_catalog.set_config('av35.cr',cr::text,true);
  PERFORM pg_catalog.set_config('av35.p2',p2::text,true);
  PERFORM pg_catalog.set_config('av35.i3',i3::text,true);
  PERFORM pg_catalog.set_config('av35.v3',v3::text,true);
  PERFORM pg_catalog.set_config('av35.e2',e2::text,true);
  PERFORM pg_catalog.set_config('av35.er',er::text,true);
  PERFORM pg_catalog.set_config('av35.pid_future',pid_future::text,true);
  PERFORM pg_catalog.set_config('av35.pid_past',pid_past::text,true);
  PERFORM pg_catalog.set_config('av35.pid_ia1',pid_ia1::text,true);
  PERFORM pg_catalog.set_config('av35.pid_ia2',pid_ia2::text,true);
  PERFORM pg_catalog.set_config('av35.pid_ongoing',pid_ongoing::text,true);
  PERFORM pg_catalog.set_config('av35.pid_e1_future',pid_e1_future::text,true);
  PERFORM pg_catalog.set_config('av35.pid_rpast',pid_rpast::text,true);
  PERFORM pg_catalog.set_config('av35.pid_rfuture',pid_rfuture::text,true);
END;
$admin_pozitiv$;
RESET ROLE;

-- Administrator: stari/transitionari refuzate, cinci patch-uri strict
-- validate, CNP unic/atomic, inchidere cu ORICE sedinta programata.
SET LOCAL ROLE authenticated;
DO $admin_negativ$
DECLARE
  v_rand record;
  v_patch jsonb;
  v_inainte bigint;
  v_dupa bigint;
  v_er uuid := pg_catalog.current_setting('av35.er')::uuid;
  v_e1 uuid := pg_catalog.current_setting('av35.e1')::uuid;
BEGIN
  FOR v_rand IN SELECT * FROM (VALUES
      ('modifica_persoana',pg_catalog.current_setting('av35.p2')::uuid,
        '{"nume":123}'::jsonb),
      ('modifica_cursant',pg_catalog.current_setting('av35.c2')::uuid,
        '{"observatii":123}'::jsonb),
      ('modifica_instructor',pg_catalog.current_setting('av35.i3')::uuid,
        '{"observatii":123}'::jsonb),
      ('modifica_vehicul',pg_catalog.current_setting('av35.v3')::uuid,
        '{"model":123}'::jsonb),
      ('modifica_inscriere',v_e1,'{"tarif_curs":"1300"}'::jsonb)
    ) AS x(nume,identificator,tip_invalid) LOOP
    FOREACH v_patch IN ARRAY ARRAY[
      NULL::jsonb,'null'::jsonb,'[]'::jsonb,'"scalar"'::jsonb,
      '{}'::jsonb,'{"cheie_necunoscuta":true}'::jsonb] LOOP
      BEGIN
        EXECUTE pg_catalog.format('SELECT public.%I($1,$2)',v_rand.nume)
          USING v_rand.identificator,v_patch;
        RAISE EXCEPTION 'Patch invalid acceptat pentru %',v_rand.nume;
      EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
    END LOOP;
    BEGIN
      EXECUTE pg_catalog.format('SELECT public.%I($1,$2)',v_rand.nume)
        USING v_rand.identificator,v_rand.tip_invalid;
      RAISE EXCEPTION 'Tip JSON invalid acceptat pentru %',v_rand.nume;
    EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
  END LOOP;
  BEGIN
    PERFORM public.modifica_persoana(
      pg_catalog.current_setting('av35.p2')::uuid,'{"nume":null}'::jsonb);
    RAISE EXCEPTION 'NULL pe nume acceptat';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
  BEGIN
    PERFORM public.modifica_persoana(
      pg_catalog.current_setting('av35.p2')::uuid,
      '{"data_nasterii":"nu-este-data"}'::jsonb);
    RAISE EXCEPTION 'Cast data invalid acceptat';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
  BEGIN
    PERFORM public.modifica_instructor(
      pg_catalog.current_setting('av35.i3')::uuid,
      '{"data_angajarii":"nu-este-data"}'::jsonb);
    RAISE EXCEPTION 'Cast angajare invalid acceptat';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
  BEGIN
    PERFORM public.modifica_vehicul(
      pg_catalog.current_setting('av35.v3')::uuid,'{"marca":null}'::jsonb);
    RAISE EXCEPTION 'NULL pe marca acceptat';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
  BEGIN
    PERFORM public.modifica_vehicul(
      pg_catalog.current_setting('av35.v3')::uuid,
      '{"an_fabricatie":99999}'::jsonb);
    RAISE EXCEPTION 'Cast smallint invalid acceptat';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
  BEGIN
    PERFORM public.modifica_vehicul(
      pg_catalog.current_setting('av35.v3')::uuid,
      '{"an_fabricatie":2020.5}'::jsonb);
    RAISE EXCEPTION 'An fractionar acceptat';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
  BEGIN
    PERFORM public.modifica_cursant(
      pg_catalog.current_setting('av35.c2')::uuid,
      '{"cnp":"1111111111111"}'::jsonb);
    RAISE EXCEPTION 'Patch CNP acceptat';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
  BEGIN
    PERFORM public.modifica_inscriere(v_e1,'{"tarif_curs":null}'::jsonb);
    RAISE EXCEPTION 'NULL pe tarif acceptat';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
  BEGIN
    PERFORM public.modifica_inscriere(v_e1,
      '{"id_instructor":"00000000-0000-0000-0000-000000000001"}'::jsonb);
    RAISE EXCEPTION 'Realocare prin patch acceptata';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
  BEGIN
    PERFORM public.modifica_inscriere(v_e1,'{"tarif_curs":-1}'::jsonb);
    RAISE EXCEPTION 'Tarif negativ acceptat';
  EXCEPTION WHEN SQLSTATE '23514' THEN NULL; END;

  SELECT count(id_persoana) INTO v_inainte FROM public.persoane;
  BEGIN
    PERFORM public.creare_cursant('Demo35','Duplicat',NULL,NULL,NULL,NULL,
      '0000000000502',NULL);
    RAISE EXCEPTION 'CNP duplicat acceptat';
  EXCEPTION WHEN unique_violation THEN NULL; END;
  SELECT count(id_persoana) INTO v_dupa FROM public.persoane;
  IF v_inainte<>v_dupa THEN
    RAISE EXCEPTION 'Persoana orfana dupa CNP duplicat';
  END IF;
  SELECT count(id_vehicul) INTO v_inainte FROM public.vehicule;
  BEGIN
    PERFORM public.creare_vehicul('DEMO35D','Duplicat','Vehicul',2020::smallint,NULL::text);
    RAISE EXCEPTION 'Numar de inmatriculare duplicat acceptat';
  EXCEPTION WHEN unique_violation THEN NULL; END;
  SELECT count(id_vehicul) INTO v_dupa FROM public.vehicule;
  IF v_inainte<>v_dupa OR NOT EXISTS (
      SELECT 1 FROM public.vehicule
      WHERE id_vehicul=pg_catalog.current_setting('av35.v3')::uuid
        AND numar_inmatriculare='DEMO35D' AND marca='Demo') THEN
    RAISE EXCEPTION 'Efect secundar dupa numar de inmatriculare duplicat';
  END IF;
  BEGIN
    PERFORM public.creare_cursant('Demo35','CNPInvalid',NULL,NULL,NULL,NULL,
      'ABCDEFGHIJKLM',NULL);
    RAISE EXCEPTION 'CNP cu litere acceptat';
  EXCEPTION WHEN SQLSTATE '23514' THEN NULL; END;
  BEGIN
    PERFORM public.creare_inscriere(
      pg_catalog.current_setting('av35.c1')::uuid,
      pg_catalog.current_setting('av35.i2')::uuid,1000,NULL);
    RAISE EXCEPTION 'Doua inscrieri active acceptate';
  EXCEPTION WHEN unique_violation THEN NULL; END;
  BEGIN
    PERFORM public.creare_inscriere(pg_catalog.gen_random_uuid(),
      pg_catalog.current_setting('av35.i2')::uuid,1000,NULL);
    RAISE EXCEPTION 'Cursant inexistent acceptat';
  EXCEPTION WHEN SQLSTATE 'PZ002' THEN NULL; END;
  BEGIN
    PERFORM public.modifica_inscriere(
      pg_catalog.current_setting('av35.e2')::uuid,
      '{"observatii":"inchisa"}'::jsonb);
    RAISE EXCEPTION 'Inscriere finalizata modificata';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  BEGIN
    PERFORM public.schimba_stare_cursant(
      pg_catalog.current_setting('av35.c1')::uuid,'inactiv');
    RAISE EXCEPTION 'Cursant cu inscriere activa dezactivat';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  BEGIN
    PERFORM public.schimba_stare_instructor(
      pg_catalog.current_setting('av35.i1')::uuid,'inactiv');
    RAISE EXCEPTION 'Instructor cu inscriere activa dezactivat';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  BEGIN
    PERFORM public.schimba_stare_vehicul(
      pg_catalog.current_setting('av35.v1')::uuid,'service');
    RAISE EXCEPTION 'Vehicul cu sedinta in desfasurare dezactivat';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  BEGIN
    PERFORM public.finalizeaza_inscriere(v_e1);
    RAISE EXCEPTION 'Inscriere cu sedinte programata finalizata';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  BEGIN
    PERFORM public.anuleaza_inscriere(v_e1);
    RAISE EXCEPTION 'Inscriere cu sedinte programata anulata';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  BEGIN
    PERFORM public.realoca_instructor(v_er,
      pg_catalog.current_setting('av35.i2')::uuid);
    RAISE EXCEPTION 'Realocare cu sedinta viitoare acceptata';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  BEGIN
    PERFORM public.anuleaza_programare(
      pg_catalog.current_setting('av35.pid_ia1')::uuid);
    RAISE EXCEPTION 'Anulare retroactiva acceptata';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  BEGIN
    PERFORM public.anuleaza_programare(
      pg_catalog.current_setting('av35.pid_ongoing')::uuid);
    RAISE EXCEPTION 'Anulare sedinta in curs acceptata';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  BEGIN
    PERFORM public.marcheaza_programare(
      pg_catalog.current_setting('av35.pid_e1_future')::uuid,'finalizata');
    RAISE EXCEPTION 'Marcare viitoare acceptata';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  BEGIN
    PERFORM public.marcheaza_programare(
      pg_catalog.current_setting('av35.pid_ongoing')::uuid,'absent');
    RAISE EXCEPTION 'Marcare inainte de sfarsit acceptata';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  BEGIN
    PERFORM public.marcheaza_programare(
      pg_catalog.current_setting('av35.pid_past')::uuid,'absent');
    RAISE EXCEPTION 'Reactivarea starii finale acceptata';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  BEGIN
    PERFORM public.anuleaza_programare(
      pg_catalog.current_setting('av35.pid_future')::uuid);
    RAISE EXCEPTION 'Anulare repetata acceptata';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;

  -- Programarea trecuta nu blocheaza realocarea; istoria ramane intacta.
  PERFORM public.anuleaza_programare(
    pg_catalog.current_setting('av35.pid_rfuture')::uuid);
  PERFORM public.realoca_instructor(v_er,
    pg_catalog.current_setting('av35.i2')::uuid);
END;
$admin_negativ$;
RESET ROLE;

-- Orice plata blocheaza PATCH cu cheia tarif_curs, inclusiv identica.
-- Triggerul 001 al platii blocheaza aceeasi inscriere.
DO $plata_fixture$
DECLARE v_plata uuid;
BEGIN
  INSERT INTO public.plati(id_inscriere,id_utilizator_inregistrare,tip,suma)
    VALUES(pg_catalog.current_setting('av35.e1')::uuid,
      pg_catalog.current_setting('av35.a')::uuid,'plata',100)
    RETURNING id_plata INTO v_plata;
  PERFORM pg_catalog.set_config('av35.plata',v_plata::text,true);
END;
$plata_fixture$;
SET LOCAL ROLE authenticated;
DO $tarif_blocat$
BEGIN
  BEGIN
    PERFORM public.modifica_inscriere(
      pg_catalog.current_setting('av35.e1')::uuid,
      '{"tarif_curs":1000}'::jsonb);
    RAISE EXCEPTION 'Tariful identic acceptat dupa plata in asteptare';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  PERFORM public.modifica_inscriere(
    pg_catalog.current_setting('av35.e1')::uuid,
    '{"observatii":"numai observatii"}'::jsonb);
END;
$tarif_blocat$;
RESET ROLE;
UPDATE public.plati SET stare='anulata'
  WHERE id_plata=pg_catalog.current_setting('av35.plata')::uuid;
SET LOCAL ROLE authenticated;
DO $tarif_plata_anulata$
BEGIN
  BEGIN
    PERFORM public.modifica_inscriere(
      pg_catalog.current_setting('av35.e1')::uuid,
      '{"tarif_curs":900}'::jsonb);
    RAISE EXCEPTION 'Tariful schimbat dupa plata anulata';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
END;
$tarif_plata_anulata$;
RESET ROLE;

-- Secretariat: toate cele 16 operatii permise, cu marcare exclusa.
SELECT pg_catalog.set_config('request.jwt.claim.sub',
  pg_catalog.current_setting('av35.s'),true);
SET LOCAL ROLE authenticated;
DO $secretariat_etapa1$
DECLARE
  cs uuid; isec uuid; vs uuid; es uuid; ps uuid;
  pid_f uuid; pid_p uuid;
  t_past timestamptz := pg_catalog.current_setting('av35.past')::timestamptz;
  t_future timestamptz := pg_catalog.current_setting('av35.future')::timestamptz;
BEGIN
  cs := public.creare_cursant('Demo35','SecretariatC',NULL,NULL,NULL,NULL,
    '0000000000504',NULL);
  SELECT id_persoana INTO ps FROM public.cursanti WHERE id_cursant=cs;
  PERFORM public.modifica_persoana(ps,'{"prenume":"Editat"}'::jsonb);
  PERFORM public.modifica_cursant(cs,'{"observatii":"secretariat"}'::jsonb);
  PERFORM public.schimba_stare_cursant(cs,'inactiv');
  PERFORM public.schimba_stare_cursant(cs,'activ');
  isec := public.creare_instructor('Demo35','SecretariatI',NULL,NULL,NULL,
    NULL,NULL,NULL);
  PERFORM public.modifica_instructor(isec,
    '{"observatii":"secretariat"}'::jsonb);
  PERFORM public.schimba_stare_instructor(isec,'inactiv');
  PERFORM public.schimba_stare_instructor(isec,'activ');
  vs := public.creare_vehicul('DEMO35E','Demo','E',2019::smallint,NULL::text);
  PERFORM public.modifica_vehicul(vs,'{"model":"Editat"}'::jsonb);
  PERFORM public.schimba_stare_vehicul(vs,'indisponibil');
  PERFORM public.schimba_stare_vehicul(vs,'activ');
  es := public.creare_inscriere(cs,isec,1400,NULL);
  PERFORM public.modifica_inscriere(es,
    '{"tarif_curs":1450,"observatii":"secretariat"}'::jsonb);
  PERFORM public.realoca_instructor(es,
    pg_catalog.current_setting('av35.i2')::uuid);
  pid_f := public.creare_programare(es,vs,t_future+interval '12 hours');
  PERFORM public.anuleaza_programare(pid_f);
  pid_p := public.creare_programare(es,vs,t_past+interval '20 hours');
  PERFORM pg_catalog.set_config('av35.cs',cs::text,true);
  PERFORM pg_catalog.set_config('av35.isec',isec::text,true);
  PERFORM pg_catalog.set_config('av35.vs',vs::text,true);
  PERFORM pg_catalog.set_config('av35.es',es::text,true);
  PERFORM pg_catalog.set_config('av35.pid_spast',pid_p::text,true);
  BEGIN
    PERFORM public.modifica_persoana(
      pg_catalog.current_setting('av35.pa')::uuid,
      '{"nume":"Interzis"}'::jsonb);
    RAISE EXCEPTION 'Secretariatul a modificat persoana profilului admin';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL; END;
  BEGIN
    PERFORM public.marcheaza_programare(pid_p,'finalizata');
    RAISE EXCEPTION 'Secretariatul a marcat programare';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL; END;
  BEGIN
    PERFORM operatii.marcheaza_programare(pid_p,'finalizata');
    RAISE EXCEPTION 'Secretariatul a marcat direct prin functia privata';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL; END;
END;
$secretariat_etapa1$;
RESET ROLE;

-- Instructorul B: nu poate marca randurile instructorului A, dar poate
-- marca sedinta istorica proprie a inscrierii secretariatului.
SELECT pg_catalog.set_config('request.jwt.claim.sub',
  pg_catalog.current_setting('av35.ib'),true);
SET LOCAL ROLE authenticated;
DO $instructor_b$
BEGIN
  BEGIN
    PERFORM public.marcheaza_programare(
      pg_catalog.current_setting('av35.pid_ia1')::uuid,'finalizata');
    RAISE EXCEPTION 'Instructor B a marcat sedinta instructorului A';
  EXCEPTION WHEN SQLSTATE 'PZ002' THEN NULL; END;
  BEGIN
    PERFORM operatii.marcheaza_programare(
      pg_catalog.current_setting('av35.pid_ia1')::uuid,'finalizata');
    RAISE EXCEPTION 'Instructor B a marcat direct sedinta instructorului A';
  EXCEPTION WHEN SQLSTATE 'PZ002' THEN NULL; END;
  PERFORM public.marcheaza_programare(
    pg_catalog.current_setting('av35.pid_spast')::uuid,'finalizata');
END;
$instructor_b$;
RESET ROLE;

-- Instructorul A marcheaza propriile sedinte trecute, inclusiv randul
-- istoric al inscrierii realocate la instructorul B.
SELECT pg_catalog.set_config('request.jwt.claim.sub',
  pg_catalog.current_setting('av35.ia'),true);
SET LOCAL ROLE authenticated;
DO $instructor_a$
BEGIN
  PERFORM public.marcheaza_programare(
    pg_catalog.current_setting('av35.pid_ia1')::uuid,'finalizata');
  PERFORM public.marcheaza_programare(
    pg_catalog.current_setting('av35.pid_ia2')::uuid,'absent');
  PERFORM public.marcheaza_programare(
    pg_catalog.current_setting('av35.pid_rpast')::uuid,'finalizata');
  BEGIN
    PERFORM public.marcheaza_programare(
      pg_catalog.current_setting('av35.pid_e1_future')::uuid,'absent');
    RAISE EXCEPTION 'Instructorul a marcat o sedinta viitoare';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
END;
$instructor_a$;
RESET ROLE;

-- Secretariatul poate acum finaliza inscrierea sa; a doua inscriere a
-- aceluiasi cursant se poate anula fara sedinte programata.
SELECT pg_catalog.set_config('request.jwt.claim.sub',
  pg_catalog.current_setting('av35.s'),true);
SET LOCAL ROLE authenticated;
DO $secretariat_etapa2$
DECLARE v_e2 uuid;
BEGIN
  PERFORM public.finalizeaza_inscriere(
    pg_catalog.current_setting('av35.es')::uuid);
  v_e2 := public.creare_inscriere(
    pg_catalog.current_setting('av35.cs')::uuid,
    pg_catalog.current_setting('av35.isec')::uuid,1000,NULL);
  PERFORM public.anuleaza_inscriere(v_e2);
  PERFORM pg_catalog.set_config('av35.es2',v_e2::text,true);
END;
$secretariat_etapa2$;
RESET ROLE;

-- Izolare temporala: o sedinta TRECUTA dar nerezolvata blocheaza ambele
-- inchideri; o sedinta IN DESFASURARE blocheaza si realocarea.
SELECT pg_catalog.set_config('request.jwt.claim.sub',
  pg_catalog.current_setting('av35.a'),true);
SET LOCAL ROLE authenticated;
DO $temporal$
DECLARE
  c_past uuid; c_curs uuid; c_future uuid;
  e_past uuid; e_curs uuid; e_future uuid;
  p_past uuid;
  t_past timestamptz := pg_catalog.current_setting('av35.past')::timestamptz;
  t_future timestamptz := pg_catalog.current_setting('av35.future')::timestamptz;
BEGIN
  c_past := public.creare_cursant('Demo35','Trecut',NULL,NULL,NULL,NULL,
    '0000000000506',NULL);
  c_curs := public.creare_cursant('Demo35','InCurs',NULL,NULL,NULL,NULL,
    '0000000000507',NULL);
  c_future := public.creare_cursant('Demo35','Viitor',NULL,NULL,NULL,NULL,
    '0000000000508',NULL);
  e_past := public.creare_inscriere(c_past,
    pg_catalog.current_setting('av35.i3')::uuid,1000,NULL);
  e_curs := public.creare_inscriere(c_curs,
    pg_catalog.current_setting('av35.i3')::uuid,1000,NULL);
  e_future := public.creare_inscriere(c_future,
    pg_catalog.current_setting('av35.i3')::uuid,1000,NULL);
  p_past := public.creare_programare(e_past,
    pg_catalog.current_setting('av35.v3')::uuid,t_past+interval '24 hours');
  PERFORM public.creare_programare(e_curs,
    pg_catalog.current_setting('av35.v3')::uuid,
    pg_catalog.clock_timestamp()-interval '20 minutes');
  PERFORM public.creare_programare(e_future,
    pg_catalog.current_setting('av35.v3')::uuid,
    t_future+interval '20 hours');
  -- Fiecare inscriere are exact o singura programare nerezolvata.
  IF (SELECT count(*) FROM public.programari
      WHERE id_inscriere=e_past AND stare='programata'
        AND sfarsit<pg_catalog.clock_timestamp())<>1
     OR (SELECT count(*) FROM public.programari
      WHERE id_inscriere=e_curs AND stare='programata'
        AND inceput<=pg_catalog.clock_timestamp()
        AND sfarsit>pg_catalog.clock_timestamp())<>1
     OR (SELECT count(*) FROM public.programari
      WHERE id_inscriere=e_future AND stare='programata'
        AND inceput>pg_catalog.clock_timestamp())<>1 THEN
    RAISE EXCEPTION 'Fixturele temporale nu sunt izolate';
  END IF;
  BEGIN
    PERFORM public.finalizeaza_inscriere(e_past);
    RAISE EXCEPTION 'Trecuta: finalizare acceptata';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  BEGIN
    PERFORM public.anuleaza_inscriere(e_past);
    RAISE EXCEPTION 'Trecuta: anulare acceptata';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  BEGIN
    PERFORM public.finalizeaza_inscriere(e_curs);
    RAISE EXCEPTION 'In curs: finalizare acceptata';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  BEGIN
    PERFORM public.anuleaza_inscriere(e_curs);
    RAISE EXCEPTION 'In curs: anulare acceptata';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  BEGIN
    PERFORM public.finalizeaza_inscriere(e_future);
    RAISE EXCEPTION 'Viitoare: finalizare acceptata';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  BEGIN
    PERFORM public.anuleaza_inscriere(e_future);
    RAISE EXCEPTION 'Viitoare: anulare acceptata';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  BEGIN
    PERFORM public.realoca_instructor(e_curs,
      pg_catalog.current_setting('av35.i2')::uuid);
    RAISE EXCEPTION 'Sedinta in curs nu a blocat realocarea';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  BEGIN
    PERFORM public.schimba_stare_vehicul(
      pg_catalog.current_setting('av35.v3')::uuid,'service');
    RAISE EXCEPTION 'Sedinta in curs nu a blocat vehiculul';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL; END;
  PERFORM public.marcheaza_programare(p_past,'absent');
  PERFORM public.anuleaza_inscriere(e_past);
  PERFORM pg_catalog.set_config('av35.e_curs',e_curs::text,true);
END;
$temporal$;
RESET ROLE;

-- Apelul DIRECT al fiecarei functii private respinge instructorul
-- (cu exceptia marcarii), cursantul, profilul inactiv, lipsa profilului
-- si cererea fara identitate. Argumentele NULL sunt tipate explicit.
SELECT pg_catalog.set_config('request.jwt.claim.sub',
  pg_catalog.current_setting('av35.ia'),true);
SET LOCAL ROLE authenticated;
DO $private_refuzat$
DECLARE
  v_caz record;
  v_functie record;
BEGIN
  FOR v_caz IN SELECT * FROM (VALUES
      ('instructor',pg_catalog.current_setting('av35.ia')),
      ('cursant',pg_catalog.current_setting('av35.ca')),
      ('inactiv',pg_catalog.current_setting('av35.x')),
      ('fara_profil',pg_catalog.current_setting('av35.lipsa')),
      ('fara_identitate','')
    ) AS c(caz,identitate) LOOP
    PERFORM pg_catalog.set_config('request.jwt.claim.sub',v_caz.identitate,true);
    FOR v_functie IN SELECT * FROM (VALUES
      ('creare_cursant','NULL::varchar,NULL::varchar,NULL::varchar,NULL::varchar,NULL::date,NULL::text,NULL::varchar,NULL::text'),
      ('modifica_persoana','NULL::uuid,NULL::jsonb'),
      ('schimba_stare_cursant','NULL::uuid,NULL::varchar'),
      ('creare_instructor','NULL::varchar,NULL::varchar,NULL::varchar,NULL::varchar,NULL::date,NULL::text,NULL::date,NULL::text'),
      ('modifica_instructor','NULL::uuid,NULL::jsonb'),
      ('schimba_stare_instructor','NULL::uuid,NULL::varchar'),
      ('creare_vehicul','NULL::varchar,NULL::varchar,NULL::varchar,NULL::smallint,NULL::text'),
      ('modifica_vehicul','NULL::uuid,NULL::jsonb'),
      ('schimba_stare_vehicul','NULL::uuid,NULL::varchar'),
      ('creare_inscriere','NULL::uuid,NULL::uuid,NULL::numeric,NULL::text'),
      ('modifica_inscriere','NULL::uuid,NULL::jsonb'),
      ('finalizeaza_inscriere','NULL::uuid'),
      ('anuleaza_inscriere','NULL::uuid'),
      ('realoca_instructor','NULL::uuid,NULL::uuid'),
      ('anuleaza_programare','NULL::uuid'),
      ('marcheaza_programare','NULL::uuid,NULL::varchar'),
      ('modifica_cursant','NULL::uuid,NULL::jsonb')
    ) AS f(nume,argumente) LOOP
      IF v_caz.caz='instructor'
         AND v_functie.nume='marcheaza_programare' THEN
        CONTINUE;
      END IF;
      BEGIN
        EXECUTE pg_catalog.format('SELECT operatii.%I(%s)',
          v_functie.nume,v_functie.argumente);
        RAISE EXCEPTION 'Acces privat permis: %, %',
          v_caz.caz,v_functie.nume;
      EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL; END;
    END LOOP;
  END LOOP;
END;
$private_refuzat$;
RESET ROLE;

-- Un wrapper reprezentativ aplica aceeasi autorizare pentru profil invalid.
SET LOCAL ROLE authenticated;
DO $wrapper_profil_refuzat$
DECLARE v_caz record;
BEGIN
  FOR v_caz IN SELECT * FROM (VALUES
      ('inactiv',pg_catalog.current_setting('av35.x')),
      ('fara_profil',pg_catalog.current_setting('av35.lipsa')),
      ('fara_identitate','')
    ) AS c(caz,identitate) LOOP
    PERFORM pg_catalog.set_config('request.jwt.claim.sub',v_caz.identitate,true);
    BEGIN
      PERFORM public.modifica_cursant(
        pg_catalog.current_setting('av35.c1')::uuid,
        '{"observatii":"refuzat"}'::jsonb);
      RAISE EXCEPTION 'Wrapperul a acceptat profilul %',v_caz.caz;
    EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL; END;
  END LOOP;
END;
$wrapper_profil_refuzat$;
RESET ROLE;

-- Wrapperii sunt la randul lor protejati de autorizarea interna.
SELECT pg_catalog.set_config('request.jwt.claim.sub',
  pg_catalog.current_setting('av35.ca'),true);
SET LOCAL ROLE authenticated;
DO $wrapper_refuzat$
BEGIN
  BEGIN
    PERFORM public.modifica_cursant(
      pg_catalog.current_setting('av35.c1')::uuid,
      '{"observatii":"interzis"}'::jsonb);
    RAISE EXCEPTION 'Cursantul a modificat date administrative';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL; END;
  BEGIN
    PERFORM public.marcheaza_programare(
      pg_catalog.current_setting('av35.pid_ia1')::uuid,'finalizata');
    RAISE EXCEPTION 'Cursantul a marcat sedinta';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL; END;
END;
$wrapper_refuzat$;
RESET ROLE;

SET LOCAL ROLE anon;
DO $anon_refuzat$
BEGIN
  BEGIN
    PERFORM public.modifica_cursant(
      pg_catalog.current_setting('av35.c1')::uuid,'{"observatii":"x"}'::jsonb);
    RAISE EXCEPTION 'anon a apelat wrapperul';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM operatii.modifica_cursant(
      pg_catalog.current_setting('av35.c1')::uuid,'{"observatii":"x"}'::jsonb);
    RAISE EXCEPTION 'anon a apelat functia privata';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END;
$anon_refuzat$;
RESET ROLE;

-- Nici macar administratorul autentificat nu are DML direct sau SELECT CNP.
SELECT pg_catalog.set_config('request.jwt.claim.sub',
  pg_catalog.current_setting('av35.a'),true);
SET LOCAL ROLE authenticated;
DO $fara_dml_direct$
DECLARE
  v_tabela text;
  v_pk text;
BEGIN
  FOR v_tabela,v_pk IN SELECT * FROM (VALUES
      ('persoane','id_persoana'),('utilizatori','id_utilizator'),
      ('cursanti','id_cursant'),('instructori','id_instructor'),
      ('vehicule','id_vehicul'),('inscrieri','id_inscriere'),
      ('programari','id_programare'),('plati','id_plata'),
      ('examene','id_examen')
    ) AS t(nume,pk) LOOP
    BEGIN
      EXECUTE pg_catalog.format(
        'INSERT INTO public.%I(%I) SELECT NULL::uuid WHERE FALSE',
        v_tabela,v_pk);
      RAISE EXCEPTION 'INSERT direct permis pe %',v_tabela;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    BEGIN
      EXECUTE pg_catalog.format(
        'UPDATE public.%I SET %I=%I WHERE FALSE',v_tabela,v_pk,v_pk);
      RAISE EXCEPTION 'UPDATE direct permis pe %',v_tabela;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    BEGIN
      EXECUTE pg_catalog.format('DELETE FROM public.%I WHERE FALSE',v_tabela);
      RAISE EXCEPTION 'DELETE direct permis pe %',v_tabela;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    BEGIN
      EXECUTE pg_catalog.format('TRUNCATE public.%I',v_tabela);
      RAISE EXCEPTION 'TRUNCATE direct permis pe %',v_tabela;
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  END LOOP;
  BEGIN
    EXECUTE 'SELECT cnp FROM public.cursanti LIMIT 1';
    RAISE EXCEPTION 'CNP citibil direct';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END;
$fara_dml_direct$;
RESET ROLE;

-- Asersiuni ca proprietar: pot verifica si coloanele ascunse prin 003.
-- Nu citesc valoarea CNP.
DO $rezultate$
DECLARE
  v_p public.persoane%ROWTYPE;
  v_stare_cursant varchar(10);
  v_observatii_cursant text;
  v_i public.instructori%ROWTYPE;
  v_v public.vehicule%ROWTYPE;
  v_e public.inscrieri%ROWTYPE;
  v_r public.programari%ROWTYPE;
BEGIN
  SELECT * INTO v_p FROM public.persoane
    WHERE id_persoana=pg_catalog.current_setting('av35.p2')::uuid;
  IF v_p.nume<>'Demo35Edit' OR v_p.telefon IS NOT NULL THEN
    RAISE EXCEPTION 'Patch persoana nu a pastrat diferenta absent/null';
  END IF;
  SELECT stare,observatii INTO v_stare_cursant,v_observatii_cursant
    FROM public.cursanti
    WHERE id_cursant=pg_catalog.current_setting('av35.c2')::uuid;
  IF v_stare_cursant<>'activ' OR v_observatii_cursant IS NOT NULL THEN
    RAISE EXCEPTION 'Patch/stare cursant incorecte';
  END IF;
  SELECT * INTO v_i FROM public.instructori
    WHERE id_instructor=pg_catalog.current_setting('av35.i3')::uuid;
  IF v_i.stare<>'activ' OR v_i.data_angajarii<>DATE '2025-01-15'
     OR v_i.observatii IS NOT NULL THEN
    RAISE EXCEPTION 'Patch/stare instructor incorecte';
  END IF;
  SELECT * INTO v_v FROM public.vehicule
    WHERE id_vehicul=pg_catalog.current_setting('av35.v3')::uuid;
  IF v_v.stare<>'activ' OR v_v.numar_inmatriculare<>'DEMO35D'
     OR v_v.an_fabricatie IS NOT NULL THEN
    RAISE EXCEPTION 'Patch/stare vehicul incorecte';
  END IF;
  SELECT * INTO v_e FROM public.inscrieri
    WHERE id_inscriere=pg_catalog.current_setting('av35.e2')::uuid;
  IF v_e.stare<>'finalizata' OR v_e.tarif_curs<>1300
     OR v_e.categorie<>'B'
     OR v_e.data_inscrierii IS DISTINCT FROM
        (pg_catalog.clock_timestamp() AT TIME ZONE 'Europe/Bucharest')::date
     OR v_e.id_instructor<>pg_catalog.current_setting('av35.i1')::uuid
     OR v_e.observatii IS NOT NULL
     OR v_e.data_finalizarii IS DISTINCT FROM
        (pg_catalog.clock_timestamp() AT TIME ZONE 'Europe/Bucharest')::date THEN
    RAISE EXCEPTION 'Inscrierea admin finalizata/realocata incorect';
  END IF;
  SELECT * INTO v_e FROM public.inscrieri
    WHERE id_inscriere=pg_catalog.current_setting('av35.er')::uuid;
  IF v_e.id_instructor<>pg_catalog.current_setting('av35.i2')::uuid
     OR v_e.stare<>'activa' THEN
    RAISE EXCEPTION 'Realocarea instructorului nu s-a pastrat';
  END IF;
  SELECT * INTO v_r FROM public.programari
    WHERE id_programare=pg_catalog.current_setting('av35.pid_rpast')::uuid;
  IF v_r.id_instructor<>pg_catalog.current_setting('av35.i1')::uuid
     OR v_r.stare<>'finalizata' THEN
    RAISE EXCEPTION 'Programarea istorica a fost rescrisa sau nemarcata';
  END IF;
  SELECT * INTO v_r FROM public.programari
    WHERE id_programare=pg_catalog.current_setting('av35.pid_future')::uuid;
  IF v_r.stare<>'anulata' THEN
    RAISE EXCEPTION 'Programarea viitoare nu a fost anulata';
  END IF;
  SELECT * INTO v_r FROM public.programari
    WHERE id_programare=pg_catalog.current_setting('av35.pid_ia2')::uuid;
  IF v_r.stare<>'absent' THEN
    RAISE EXCEPTION 'Marcarea absent nu a fost pastrata';
  END IF;
  SELECT * INTO v_e FROM public.inscrieri
    WHERE id_inscriere=pg_catalog.current_setting('av35.es')::uuid;
  IF v_e.stare<>'finalizata' OR v_e.tarif_curs<>1450 THEN
    RAISE EXCEPTION 'Secretariatul nu a finalizat inscrierea';
  END IF;
  SELECT * INTO v_e FROM public.inscrieri
    WHERE id_inscriere=pg_catalog.current_setting('av35.es2')::uuid;
  IF v_e.stare<>'anulata' OR v_e.data_finalizarii IS NOT NULL THEN
    RAISE EXCEPTION 'Secretariatul nu a anulat inscrierea';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.plati
      WHERE id_plata=pg_catalog.current_setting('av35.plata')::uuid
        AND stare='anulata') THEN
    RAISE EXCEPTION 'Plata anulata lipseste din scenariul de tarif';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.inscrieri
      WHERE id_inscriere=pg_catalog.current_setting('av35.e1')::uuid
        AND tarif_curs=1000 AND observatii='numai observatii') THEN
    RAISE EXCEPTION 'Tariful a fost schimbat dupa existenta platii';
  END IF;
END;
$rezultate$;
ROLLBACK;

-- 3. CONCURENTA: scenarii MANUALE in doua sesiuni, pe fixture demo
-- persistent creat intr-o baza de dezvoltare izolata si deja COMMIT-uit.
-- Fixture-ul tranzactional de mai sus dispare la ROLLBACK si NU este bun aici.
-- Pregatiti conturi Auth demo existente si profiluri active; nu inserati
-- direct in auth.users si nu folositi date reale. Pentru fiecare varianta
-- COMMIT/ROLLBACK pregatiti un fixture proaspat cu starile initiale descrise.
-- In ambele sesiuni set_config(...,true) se executa DUPA BEGIN.
-- B asteapta in apelul RPC pana cand A decide COMMIT sau ROLLBACK.
-- Dupa o eroare in B, executati ROLLBACK B; dupa succes, tot ROLLBACK B.
-- COMMIT A persista efectul: refaceti separat baza demo din snapshot/clone
-- dupa probe; rollback-ul structural 005 NU sterge date si nu este curatare.
--
-- P. Profil apelant: A poate bloca profilul cu FOR UPDATE, iar B cheama
-- public.modifica_cursant cu JWT-ul acelui apelant. B asteapta la FOR SHARE.
-- Dupa ROLLBACK A, B continua; repetati pe fixture proaspat cu schimbarea
-- activ=false facuta de proprietar in A si COMMIT: B trebuie sa dea PZ001.
-- Sesiunea A (proprietar, varianta fara schimbare):
-- BEGIN;
-- SELECT id_utilizator FROM public.utilizatori
--   WHERE id_utilizator='<ID_ADMIN_DEMO>'::uuid FOR UPDATE;
-- Sesiunea B:
-- BEGIN;
-- SELECT pg_catalog.set_config('request.jwt.claim.sub','<ID_ADMIN_DEMO>',true);
-- SET LOCAL ROLE authenticated;
-- SELECT public.modifica_cursant('<ID_CURSANT_DEMO>'::uuid,
--   '{"observatii":"concurenta"}'::jsonb);
-- B asteapta. A: ROLLBACK; B reuseste, apoi ROLLBACK B.
-- Repetati pe fixture proaspat: A executa ca proprietar
-- UPDATE public.utilizatori SET activ=false
--   WHERE id_utilizator='<ID_ADMIN_DEMO>'::uuid;
-- A tine tranzactia deschisa; B repeta apelul RPC. A: COMMIT;
-- B: PZ001, apoi ROLLBACK B.
--
-- A. creare_inscriere vs schimba_stare_cursant.
-- Fixture: cursant activ FARA inscriere activa; instructor activ.
-- Sesiunea A:
-- BEGIN;
-- SELECT pg_catalog.set_config('request.jwt.claim.sub','<ID_ADMIN_DEMO>',true);
-- SET LOCAL ROLE authenticated;
-- SELECT public.schimba_stare_cursant('<ID_CURSANT_LIBER_DEMO>'::uuid,'inactiv');
-- Lasati A deschisa, fara COMMIT inca.
-- Sesiunea B:
-- BEGIN;
-- SELECT pg_catalog.set_config('request.jwt.claim.sub','<ID_ADMIN_DEMO>',true);
-- SET LOCAL ROLE authenticated;
-- SELECT public.creare_inscriere('<ID_CURSANT_LIBER_DEMO>'::uuid,
--   '<ID_INSTRUCTOR_ACTIV_DEMO>'::uuid,1000,NULL);
-- B asteapta lock-ul cursantului. A: COMMIT; B: PZ003, apoi ROLLBACK.
-- Repetati pe fixture proaspat: A ROLLBACK; B poate crea inscriere,
-- apoi B ROLLBACK.
--
-- B. creare_inscriere vs schimba_stare_instructor.
-- Fixture: cursant activ FARA inscriere activa; instructor activ fara
-- inscrieri active ori programari viitoare.
-- Sesiunea A:
-- BEGIN;
-- SELECT pg_catalog.set_config('request.jwt.claim.sub','<ID_ADMIN_DEMO>',true);
-- SET LOCAL ROLE authenticated;
-- SELECT public.schimba_stare_instructor('<ID_INSTRUCTOR_LIBER_DEMO>'::uuid,
--   'inactiv');
-- Lasati A deschisa.
-- Sesiunea B:
-- BEGIN;
-- SELECT pg_catalog.set_config('request.jwt.claim.sub','<ID_ADMIN_DEMO>',true);
-- SET LOCAL ROLE authenticated;
-- SELECT public.creare_inscriere('<ID_CURSANT_LIBER_DEMO>'::uuid,
--   '<ID_INSTRUCTOR_LIBER_DEMO>'::uuid,1000,NULL);
-- B asteapta lock-ul instructorului. A: COMMIT; B: PZ003, apoi ROLLBACK.
-- Cu fixture proaspat, A ROLLBACK; B poate continua, apoi ROLLBACK B.
--
-- C. creare_programare 004 vs schimba_stare_vehicul.
-- Fixture: inscriere activa, vehicul activ fara sedinte programata viitoare;
-- interval viitor liber pentru cursant, instructor si vehicul.
-- Sesiunea A:
-- BEGIN;
-- SELECT pg_catalog.set_config('request.jwt.claim.sub','<ID_ADMIN_DEMO>',true);
-- SET LOCAL ROLE authenticated;
-- SELECT public.schimba_stare_vehicul('<ID_VEHICUL_LIBER_DEMO>'::uuid,'service');
-- Lasati A deschisa.
-- Sesiunea B:
-- BEGIN;
-- SELECT pg_catalog.set_config('request.jwt.claim.sub','<ID_ADMIN_DEMO>',true);
-- SET LOCAL ROLE authenticated;
-- SELECT public.creare_programare('<ID_INSCRIERE_ACTIVA_DEMO>'::uuid,
--   '<ID_VEHICUL_LIBER_DEMO>'::uuid,'<INCEPUT_LIBER_VIITOR>'::timestamptz);
-- B asteapta lock-ul vehiculului. A: COMMIT; B: 23514 din triggerul 001,
-- apoi ROLLBACK B. Pe fixture proaspat, A ROLLBACK; B poate crea
-- programarea, apoi ROLLBACK B.
--
-- D1. creare_programare 004 vs finalizeaza_inscriere.
-- Fixture: inscriere activa fara NICIO programare programata; interval liber.
-- Sesiunea A:
-- BEGIN;
-- SELECT pg_catalog.set_config('request.jwt.claim.sub','<ID_ADMIN_DEMO>',true);
-- SET LOCAL ROLE authenticated;
-- SELECT public.finalizeaza_inscriere('<ID_INSCRIERE_FARA_SEDINTE_DEMO>'::uuid);
-- Lasati A deschisa.
-- Sesiunea B:
-- BEGIN;
-- SELECT pg_catalog.set_config('request.jwt.claim.sub','<ID_ADMIN_DEMO>',true);
-- SET LOCAL ROLE authenticated;
-- SELECT public.creare_programare('<ID_INSCRIERE_FARA_SEDINTE_DEMO>'::uuid,
--   '<ID_VEHICUL_ACTIV_DEMO>'::uuid,'<INCEPUT_LIBER_VIITOR>'::timestamptz);
-- B asteapta lock-ul inscrierii. A: COMMIT; B: PZ003, inscrierea nu mai
-- este activa; apoi ROLLBACK B. Cu fixture proaspat, A ROLLBACK;
-- B poate crea programarea, apoi ROLLBACK B.
--
-- D2. creare_programare 004 vs anuleaza_inscriere.
-- Fixture separat: inscriere activa fara NICIO programare programata.
-- Sesiunea A:
-- BEGIN;
-- SELECT pg_catalog.set_config('request.jwt.claim.sub','<ID_ADMIN_DEMO>',true);
-- SET LOCAL ROLE authenticated;
-- SELECT public.anuleaza_inscriere('<ID_INSCRIERE_FARA_SEDINTE_DEMO>'::uuid);
-- Lasati A deschisa.
-- Sesiunea B:
-- BEGIN;
-- SELECT pg_catalog.set_config('request.jwt.claim.sub','<ID_ADMIN_DEMO>',true);
-- SET LOCAL ROLE authenticated;
-- SELECT public.creare_programare('<ID_INSCRIERE_FARA_SEDINTE_DEMO>'::uuid,
--   '<ID_VEHICUL_ACTIV_DEMO>'::uuid,'<INCEPUT_LIBER_VIITOR>'::timestamptz);
-- B asteapta lock-ul inscrierii. A: COMMIT; B: PZ003, inscrierea nu mai
-- este activa; apoi ROLLBACK B. Cu fixture proaspat, A ROLLBACK;
-- B poate crea programarea, apoi ROLLBACK B.
--
-- E. creare_programare 004 vs realoca_instructor.
-- Fixture: inscriere activa, cursant/instructor nou activi, fara sedinte
-- programata in curs sau viitoare. O sedinta istorica a instructorului
-- vechi poate fi pastrata pentru verificarea istoricului.
-- Sesiunea A:
-- BEGIN;
-- SELECT pg_catalog.set_config('request.jwt.claim.sub','<ID_ADMIN_DEMO>',true);
-- SET LOCAL ROLE authenticated;
-- SELECT public.realoca_instructor('<ID_INSCRIERE_ACTIVA_DEMO>'::uuid,
--   '<ID_INSTRUCTOR_NOU_DEMO>'::uuid);
-- Lasati A deschisa.
-- Sesiunea B:
-- BEGIN;
-- SELECT pg_catalog.set_config('request.jwt.claim.sub','<ID_ADMIN_DEMO>',true);
-- SET LOCAL ROLE authenticated;
-- WITH creat AS (
--   SELECT public.creare_programare('<ID_INSCRIERE_ACTIVA_DEMO>'::uuid,
--     '<ID_VEHICUL_ACTIV_DEMO>'::uuid,
--     '<INCEPUT_LIBER_VIITOR>'::timestamptz) AS id_programare
-- )
-- SELECT p.id_programare,p.id_instructor FROM public.programari p
--   JOIN creat c ON c.id_programare=p.id_programare;
-- B asteapta lock-ul inscrierii. A: COMMIT; B vede ID_INSTRUCTOR_NOU_DEMO
-- pe programarea noua. Programarea istorica pastreaza ID_INSTRUCTOR_VECHI.
-- Verificati istoricul prin SELECT id_instructor FROM public.programari
--   WHERE id_programare='<ID_PROGRAMARE_ISTORICA_DEMO>'::uuid;
-- B: ROLLBACK. Cu fixture proaspat, A ROLLBACK; B foloseste vechiul
-- instructor si apoi ROLLBACK.
--
-- F. modifica_inscriere(tarif) vs inserare plata.
-- Fixture: inscriere activa fara nicio plata. Numai sesiunea A, ca
-- proprietar al tabelelor, face DML direct de test; rolul authenticated nu.
-- Sesiunea A (proprietar):
-- BEGIN;
-- INSERT INTO public.plati(id_inscriere,id_utilizator_inregistrare,tip,suma)
--   VALUES('<ID_INSCRIERE_FARA_PLATI_DEMO>'::uuid,
--     '<ID_ADMIN_DEMO>'::uuid,'plata',100);
-- Lasati A deschisa: triggerul 001 tine lock pe inscriere.
-- Sesiunea B:
-- BEGIN;
-- SELECT pg_catalog.set_config('request.jwt.claim.sub','<ID_ADMIN_DEMO>',true);
-- SET LOCAL ROLE authenticated;
-- SELECT public.modifica_inscriere('<ID_INSCRIERE_FARA_PLATI_DEMO>'::uuid,
--   '{"tarif_curs":1100}'::jsonb);
-- B asteapta lock-ul inscrierii. A: COMMIT; B: PZ003, apoi ROLLBACK.
-- Cu fixture proaspat, A ROLLBACK; B poate schimba tariful, apoi ROLLBACK.
--
-- G1. Doua anulari pe ACEEASI programare viitoare programata.
-- Anularea este valida numai inainte de inceput.
-- Sesiunea A:
-- BEGIN;
-- SELECT pg_catalog.set_config('request.jwt.claim.sub','<ID_ADMIN_DEMO>',true);
-- SET LOCAL ROLE authenticated;
-- SELECT public.anuleaza_programare('<ID_PROGRAMARE_VIITOARE_DEMO>'::uuid);
-- Lasati A deschisa.
-- Sesiunea B:
-- BEGIN;
-- SELECT pg_catalog.set_config('request.jwt.claim.sub','<ID_ADMIN_DEMO>',true);
-- SET LOCAL ROLE authenticated;
-- SELECT public.anuleaza_programare('<ID_PROGRAMARE_VIITOARE_DEMO>'::uuid);
-- B asteapta randul programarii. A: COMMIT; B: PZ003, apoi ROLLBACK.
-- Pe fixture proaspat, A ROLLBACK; B poate anula, apoi ROLLBACK.
--
-- G2. Doua marcari pe ACEEASI programare trecuta programata.
-- Marcarea este valida numai dupa sfarsit. Nu combinati aici anulare
-- cu marcare: cele doua ferestre temporale nu se suprapun.
-- Sesiunea A:
-- BEGIN;
-- SELECT pg_catalog.set_config('request.jwt.claim.sub','<ID_ADMIN_DEMO>',true);
-- SET LOCAL ROLE authenticated;
-- SELECT public.marcheaza_programare('<ID_PROGRAMARE_TRECUTA_DEMO>'::uuid,
--   'finalizata');
-- Lasati A deschisa.
-- Sesiunea B:
-- BEGIN;
-- SELECT pg_catalog.set_config('request.jwt.claim.sub','<ID_ADMIN_DEMO>',true);
-- SET LOCAL ROLE authenticated;
-- SELECT public.marcheaza_programare('<ID_PROGRAMARE_TRECUTA_DEMO>'::uuid,
--   'absent');
-- B asteapta randul programarii. A: COMMIT; B: PZ003, apoi ROLLBACK.
-- Pe fixture proaspat, A ROLLBACK; B poate marca, apoi ROLLBACK.
-- Doua ROLLBACK-uri nu demonstreaza rezultatul de dupa COMMIT A.
