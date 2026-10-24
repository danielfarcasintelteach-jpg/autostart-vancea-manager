-- Etapa 3.4B: rollback STRUCTURAL 005, NEEXECUTAT.
-- Pastreaza schema operatii, functiile 004 si toate datele.
-- Daca exista 3.4C, executati rollback-ul 3.4C inainte de 005.
-- Executati rollback-ul 005 inainte de rollback-ul 004.
-- Aplicati numai dupa verificarea manuala a dependintelor.
BEGIN;
SET LOCAL search_path = '';

DO $preflight_rollback$
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
$preflight_rollback$;

-- Intai wrapperii publici, apoi functiile private; numai obiectele 005.
REVOKE EXECUTE ON FUNCTION public.creare_cursant(varchar,varchar,varchar,varchar,date,text,varchar,text) FROM authenticated, anon, PUBLIC;
DROP FUNCTION public.creare_cursant(varchar,varchar,varchar,varchar,date,text,varchar,text) RESTRICT;
REVOKE EXECUTE ON FUNCTION public.modifica_persoana(uuid,jsonb) FROM authenticated, anon, PUBLIC;
DROP FUNCTION public.modifica_persoana(uuid,jsonb) RESTRICT;
REVOKE EXECUTE ON FUNCTION public.schimba_stare_cursant(uuid,varchar) FROM authenticated, anon, PUBLIC;
DROP FUNCTION public.schimba_stare_cursant(uuid,varchar) RESTRICT;
REVOKE EXECUTE ON FUNCTION public.creare_instructor(varchar,varchar,varchar,varchar,date,text,date,text) FROM authenticated, anon, PUBLIC;
DROP FUNCTION public.creare_instructor(varchar,varchar,varchar,varchar,date,text,date,text) RESTRICT;
REVOKE EXECUTE ON FUNCTION public.modifica_instructor(uuid,jsonb) FROM authenticated, anon, PUBLIC;
DROP FUNCTION public.modifica_instructor(uuid,jsonb) RESTRICT;
REVOKE EXECUTE ON FUNCTION public.schimba_stare_instructor(uuid,varchar) FROM authenticated, anon, PUBLIC;
DROP FUNCTION public.schimba_stare_instructor(uuid,varchar) RESTRICT;
REVOKE EXECUTE ON FUNCTION public.creare_vehicul(varchar,varchar,varchar,smallint,text) FROM authenticated, anon, PUBLIC;
DROP FUNCTION public.creare_vehicul(varchar,varchar,varchar,smallint,text) RESTRICT;
REVOKE EXECUTE ON FUNCTION public.modifica_vehicul(uuid,jsonb) FROM authenticated, anon, PUBLIC;
DROP FUNCTION public.modifica_vehicul(uuid,jsonb) RESTRICT;
REVOKE EXECUTE ON FUNCTION public.schimba_stare_vehicul(uuid,varchar) FROM authenticated, anon, PUBLIC;
DROP FUNCTION public.schimba_stare_vehicul(uuid,varchar) RESTRICT;
REVOKE EXECUTE ON FUNCTION public.creare_inscriere(uuid,uuid,numeric,text) FROM authenticated, anon, PUBLIC;
DROP FUNCTION public.creare_inscriere(uuid,uuid,numeric,text) RESTRICT;
REVOKE EXECUTE ON FUNCTION public.modifica_inscriere(uuid,jsonb) FROM authenticated, anon, PUBLIC;
DROP FUNCTION public.modifica_inscriere(uuid,jsonb) RESTRICT;
REVOKE EXECUTE ON FUNCTION public.finalizeaza_inscriere(uuid) FROM authenticated, anon, PUBLIC;
DROP FUNCTION public.finalizeaza_inscriere(uuid) RESTRICT;
REVOKE EXECUTE ON FUNCTION public.anuleaza_inscriere(uuid) FROM authenticated, anon, PUBLIC;
DROP FUNCTION public.anuleaza_inscriere(uuid) RESTRICT;
REVOKE EXECUTE ON FUNCTION public.realoca_instructor(uuid,uuid) FROM authenticated, anon, PUBLIC;
DROP FUNCTION public.realoca_instructor(uuid,uuid) RESTRICT;
REVOKE EXECUTE ON FUNCTION public.anuleaza_programare(uuid) FROM authenticated, anon, PUBLIC;
DROP FUNCTION public.anuleaza_programare(uuid) RESTRICT;
REVOKE EXECUTE ON FUNCTION public.marcheaza_programare(uuid,varchar) FROM authenticated, anon, PUBLIC;
DROP FUNCTION public.marcheaza_programare(uuid,varchar) RESTRICT;
REVOKE EXECUTE ON FUNCTION public.modifica_cursant(uuid,jsonb) FROM authenticated, anon, PUBLIC;
DROP FUNCTION public.modifica_cursant(uuid,jsonb) RESTRICT;
REVOKE EXECUTE ON FUNCTION operatii.creare_cursant(varchar,varchar,varchar,varchar,date,text,varchar,text) FROM authenticated, anon, PUBLIC;
DROP FUNCTION operatii.creare_cursant(varchar,varchar,varchar,varchar,date,text,varchar,text) RESTRICT;
REVOKE EXECUTE ON FUNCTION operatii.modifica_persoana(uuid,jsonb) FROM authenticated, anon, PUBLIC;
DROP FUNCTION operatii.modifica_persoana(uuid,jsonb) RESTRICT;
REVOKE EXECUTE ON FUNCTION operatii.schimba_stare_cursant(uuid,varchar) FROM authenticated, anon, PUBLIC;
DROP FUNCTION operatii.schimba_stare_cursant(uuid,varchar) RESTRICT;
REVOKE EXECUTE ON FUNCTION operatii.creare_instructor(varchar,varchar,varchar,varchar,date,text,date,text) FROM authenticated, anon, PUBLIC;
DROP FUNCTION operatii.creare_instructor(varchar,varchar,varchar,varchar,date,text,date,text) RESTRICT;
REVOKE EXECUTE ON FUNCTION operatii.modifica_instructor(uuid,jsonb) FROM authenticated, anon, PUBLIC;
DROP FUNCTION operatii.modifica_instructor(uuid,jsonb) RESTRICT;
REVOKE EXECUTE ON FUNCTION operatii.schimba_stare_instructor(uuid,varchar) FROM authenticated, anon, PUBLIC;
DROP FUNCTION operatii.schimba_stare_instructor(uuid,varchar) RESTRICT;
REVOKE EXECUTE ON FUNCTION operatii.creare_vehicul(varchar,varchar,varchar,smallint,text) FROM authenticated, anon, PUBLIC;
DROP FUNCTION operatii.creare_vehicul(varchar,varchar,varchar,smallint,text) RESTRICT;
REVOKE EXECUTE ON FUNCTION operatii.modifica_vehicul(uuid,jsonb) FROM authenticated, anon, PUBLIC;
DROP FUNCTION operatii.modifica_vehicul(uuid,jsonb) RESTRICT;
REVOKE EXECUTE ON FUNCTION operatii.schimba_stare_vehicul(uuid,varchar) FROM authenticated, anon, PUBLIC;
DROP FUNCTION operatii.schimba_stare_vehicul(uuid,varchar) RESTRICT;
REVOKE EXECUTE ON FUNCTION operatii.creare_inscriere(uuid,uuid,numeric,text) FROM authenticated, anon, PUBLIC;
DROP FUNCTION operatii.creare_inscriere(uuid,uuid,numeric,text) RESTRICT;
REVOKE EXECUTE ON FUNCTION operatii.modifica_inscriere(uuid,jsonb) FROM authenticated, anon, PUBLIC;
DROP FUNCTION operatii.modifica_inscriere(uuid,jsonb) RESTRICT;
REVOKE EXECUTE ON FUNCTION operatii.finalizeaza_inscriere(uuid) FROM authenticated, anon, PUBLIC;
DROP FUNCTION operatii.finalizeaza_inscriere(uuid) RESTRICT;
REVOKE EXECUTE ON FUNCTION operatii.anuleaza_inscriere(uuid) FROM authenticated, anon, PUBLIC;
DROP FUNCTION operatii.anuleaza_inscriere(uuid) RESTRICT;
REVOKE EXECUTE ON FUNCTION operatii.realoca_instructor(uuid,uuid) FROM authenticated, anon, PUBLIC;
DROP FUNCTION operatii.realoca_instructor(uuid,uuid) RESTRICT;
REVOKE EXECUTE ON FUNCTION operatii.anuleaza_programare(uuid) FROM authenticated, anon, PUBLIC;
DROP FUNCTION operatii.anuleaza_programare(uuid) RESTRICT;
REVOKE EXECUTE ON FUNCTION operatii.marcheaza_programare(uuid,varchar) FROM authenticated, anon, PUBLIC;
DROP FUNCTION operatii.marcheaza_programare(uuid,varchar) RESTRICT;
REVOKE EXECUTE ON FUNCTION operatii.modifica_cursant(uuid,jsonb) FROM authenticated, anon, PUBLIC;
DROP FUNCTION operatii.modifica_cursant(uuid,jsonb) RESTRICT;
-- Dupa DROP, trebuie sa ramana exact starea 001-004.
DO $postflight_rollback$
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
         WHERE pronamespace='operatii'::regnamespace)<>1
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
      WHERE n.nspname IN ('public','operatii')
        AND p.proname=ANY(v_nume_005)) THEN
    RAISE EXCEPTION 'Exista deja o operatie 005 sau o supraincarcare';
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
END;
$postflight_rollback$;

COMMIT;
