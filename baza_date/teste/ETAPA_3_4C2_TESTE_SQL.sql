-- AUTOSTART VANCEA Manager
-- Etapa 3.4C2 - teste pentru migrarea 007.
-- Sectiunea 1 se ruleaza separat dupa aplicarea 007.
-- Sectiunea 2 este functionala si se termina cu ROLLBACK.
-- Rollback-ul structural 007 NU se ruleaza pentru testare.

-- =========================================================
-- 1. TEST CATALOG / SECURITATE
-- =========================================================
DO $catalog$
DECLARE
  v_sig text;
  v_priv oid;
  v_pub oid;
  v_tabele text[] := ARRAY[
    'persoane','utilizatori','cursanti','instructori','vehicule',
    'inscrieri','programari','plati','examene','jurnal_audit'
  ];
  v_operatii_existente text[] := ARRAY[
    'creare_programare',
    'creare_cursant','modifica_persoana','schimba_stare_cursant',
    'creare_instructor','modifica_instructor','schimba_stare_instructor',
    'creare_vehicul','modifica_vehicul','schimba_stare_vehicul',
    'creare_inscriere','modifica_inscriere','finalizeaza_inscriere',
    'anuleaza_inscriere','realoca_instructor','anuleaza_programare',
    'marcheaza_programare','modifica_cursant'
  ];
  v_operatii_007 text[] := ARRAY[
    'inregistreaza_plata','confirma_plata','anuleaza_plata_in_asteptare',
    'inregistreaza_rambursare','inregistreaza_examen',
    'inregistreaza_rezultat','anuleaza_examen'
  ];
BEGIN
  IF (
    SELECT count(*) FROM pg_catalog.pg_proc
    WHERE pronamespace='operatii'::regnamespace
  ) <> 25 THEN
    RAISE EXCEPTION 'TEST 3.4C2: operatii nu contine exact 25 functii';
  END IF;

  IF (
    SELECT count(*)
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='operatii'
      AND p.proname=ANY(v_operatii_existente||v_operatii_007)
  ) <> 25
  OR (
    SELECT count(*)
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public'
      AND p.proname=ANY(v_operatii_existente||v_operatii_007)
  ) <> 25 THEN
    RAISE EXCEPTION 'TEST 3.4C2: operatiile private/wrapper-ele 004-007 nu sunt exact 25';
  END IF;

  FOREACH v_sig IN ARRAY ARRAY[
    'inregistreaza_plata(uuid,numeric,varchar,text,uuid)',
    'confirma_plata(uuid)',
    'anuleaza_plata_in_asteptare(uuid,varchar)',
    'inregistreaza_rambursare(uuid,numeric,varchar,uuid)',
    'inregistreaza_examen(uuid,varchar,timestamp with time zone)',
    'inregistreaza_rezultat(uuid,varchar,integer)',
    'anuleaza_examen(uuid,varchar)'
  ] LOOP
    v_priv := pg_catalog.to_regprocedure('operatii.'||v_sig);
    v_pub := pg_catalog.to_regprocedure('public.'||v_sig);
    IF v_priv IS NULL OR v_pub IS NULL THEN
      RAISE EXCEPTION 'TEST 3.4C2: functie lipsa: %',v_sig;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_proc p
        WHERE p.oid=v_priv
          AND p.proowner=current_user::regrole
          AND p.prorettype='uuid'::regtype
          AND p.prosecdef
          AND p.provolatile='v'
          AND p.proconfig @> ARRAY['search_path=""']
      )
      OR NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_proc p
        WHERE p.oid=v_pub
          AND p.proowner=current_user::regrole
          AND p.prorettype='uuid'::regtype
          AND NOT p.prosecdef
          AND p.provolatile='v'
          AND p.proconfig @> ARRAY['search_path=""']
      ) THEN
      RAISE EXCEPTION 'TEST 3.4C2: securitatea functiei nu corespunde: %',v_sig;
    END IF;
    IF NOT pg_catalog.has_function_privilege('authenticated',v_priv,'EXECUTE')
       OR NOT pg_catalog.has_function_privilege('authenticated',v_pub,'EXECUTE')
       OR pg_catalog.has_function_privilege('anon',v_priv,'EXECUTE')
       OR pg_catalog.has_function_privilege('anon',v_pub,'EXECUTE') THEN
      RAISE EXCEPTION 'TEST 3.4C2: granturile functiei nu corespund: %',v_sig;
    END IF;
  END LOOP;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname IN ('public','operatii')
      AND p.proname=ANY(ARRAY[
        'creare_profil','schimba_rol_profil','schimba_activ_profil',
        'corecteaza_cnp','consulta_cnp'
      ])
  ) THEN
    RAISE EXCEPTION 'TEST 3.4C2: exista prematur o operatie 3.4C3';
  END IF;

  IF (
    SELECT count(*)
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public'
      AND c.relname=ANY(v_tabele)
      AND c.relkind='r'
      AND c.relrowsecurity
      AND NOT c.relforcerowsecurity
      AND c.relowner=current_user::regrole
  ) <> 10 THEN
    RAISE EXCEPTION 'TEST 3.4C2: cele 10 tabele/RLS/proprietarul nu corespund';
  END IF;

  IF (
    SELECT count(*)
    FROM pg_catalog.pg_policy p
    JOIN pg_catalog.pg_class c ON c.oid=p.polrelid
    JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname=ANY(v_tabele)
  ) <> 10
  OR EXISTS (
    SELECT 1 FROM pg_catalog.pg_policy
    WHERE polrelid='public.jurnal_audit'::regclass
  ) THEN
    RAISE EXCEPTION 'TEST 3.4C2: politicile RLS nu corespund';
  END IF;

  IF pg_catalog.has_table_privilege('authenticated','public.plati','INSERT')
     OR pg_catalog.has_table_privilege('authenticated','public.plati','UPDATE')
     OR pg_catalog.has_table_privilege('authenticated','public.plati','DELETE')
     OR pg_catalog.has_table_privilege('authenticated','public.examene','INSERT')
     OR pg_catalog.has_table_privilege('authenticated','public.examene','UPDATE')
     OR pg_catalog.has_table_privilege('authenticated','public.examene','DELETE')
     OR pg_catalog.has_table_privilege('authenticated','public.jurnal_audit','SELECT')
     OR pg_catalog.has_table_privilege('authenticated','public.jurnal_audit','INSERT')
     OR pg_catalog.has_table_privilege('authenticated','public.jurnal_audit','UPDATE')
     OR pg_catalog.has_table_privilege('authenticated','public.jurnal_audit','DELETE')
     OR pg_catalog.has_table_privilege('authenticated','public.jurnal_audit','TRUNCATE') THEN
    RAISE EXCEPTION 'TEST 3.4C2: authenticated are DML direct nepermis';
  END IF;

  IF pg_catalog.has_column_privilege(
       'authenticated','public.plati','cheie_idempotenta','SELECT')
     OR pg_catalog.has_column_privilege(
       'authenticated','public.cursanti','cnp','SELECT') THEN
    RAISE EXCEPTION 'TEST 3.4C2: o coloana sensibila este citibila direct';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_index i
    JOIN pg_catalog.pg_attribute a
      ON a.attrelid=i.indrelid
     AND a.attname='cheie_idempotenta'
     AND a.attnum=i.indkey[0]
    WHERE i.indexrelid='public.uq_plati_cheie_idempotenta'::regclass
      AND i.indrelid='public.plati'::regclass
      AND i.indisunique
      AND i.indisvalid
      AND i.indisready
      AND i.indnkeyatts=1
      AND i.indpred IS NOT NULL
      AND pg_catalog.pg_get_expr(i.indpred,i.indrelid)
          = '(cheie_idempotenta IS NOT NULL)'
  ) THEN
    RAISE EXCEPTION 'TEST 3.4C2: indexul de idempotenta 006 nu corespunde';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_trigger t
    WHERE t.tgrelid='public.jurnal_audit'::regclass
      AND t.tgname='protejeaza_jurnal_audit'
      AND t.tgenabled='O' AND NOT t.tgisinternal
  )
  OR NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_trigger t
    WHERE t.tgrelid='public.jurnal_audit'::regclass
      AND t.tgname='protejeaza_jurnal_audit_truncate'
      AND t.tgenabled='O' AND NOT t.tgisinternal
  )
  OR NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_trigger t
    WHERE t.tgrelid='public.plati'::regclass
      AND t.tgname='protejeaza_cheie_idempotenta_plata'
      AND t.tgenabled='O' AND NOT t.tgisinternal
  ) THEN
    RAISE EXCEPTION 'TEST 3.4C2: protectiile 006 nu corespund';
  END IF;
END;
$catalog$;

SELECT 'ETAPA_3_4C2_CATALOG_OK' AS rezultat;

-- =========================================================
-- 2. TESTE FUNCTIONALE - TOTUL SE ANULEAZA PRIN ROLLBACK
-- =========================================================
BEGIN;

DO $preconditii$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM auth.users a
    JOIN public.utilizatori u ON u.id_utilizator=a.id
    WHERE a.email='admin.demo@example.com'
      AND u.rol='administrator'
      AND u.activ IS TRUE
  ) THEN
    RAISE EXCEPTION 'TEST 3.4C2: admin.demo@example.com nu este administrator activ';
  END IF;
END;
$preconditii$;

SELECT pg_catalog.set_config(
  'request.jwt.claim.sub',
  (SELECT id::text FROM auth.users WHERE email='admin.demo@example.com'),
  true
);

SET LOCAL ROLE authenticated;

SELECT pg_catalog.set_config(
  't34c2.cursant',
  public.creare_cursant(
    'TEST34C2'::varchar,'Cursant'::varchar,
    NULL::varchar,NULL::varchar,NULL::date,NULL::text,
    '2990101999902'::varchar,'fixture 3.4C2'::text
  )::text,
  true
);

SELECT pg_catalog.set_config(
  't34c2.instructor',
  public.creare_instructor(
    'TEST34C2'::varchar,'Instructor'::varchar,
    NULL::varchar,NULL::varchar,NULL::date,NULL::text,
    DATE '2026-01-01','fixture 3.4C2'::text
  )::text,
  true
);

SELECT pg_catalog.set_config(
  't34c2.inscriere',
  public.creare_inscriere(
    pg_catalog.current_setting('t34c2.cursant')::uuid,
    pg_catalog.current_setting('t34c2.instructor')::uuid,
    1200.00::numeric,
    'fixture 3.4C2'::text
  )::text,
  true
);

-- Plata noua + idempotenta exacta.
SELECT pg_catalog.set_config(
  't34c2.plata1',
  public.inregistreaza_plata(
    pg_catalog.current_setting('t34c2.inscriere')::uuid,
    500.00::numeric,
    'card'::varchar,
    'TEST34C2-P1'::text,
    '11111111-34c2-4c21-8c21-111111111111'::uuid
  )::text,
  true
);

DO $plata_idempotenta$
DECLARE
  v_id uuid;
BEGIN
  v_id := public.inregistreaza_plata(
    pg_catalog.current_setting('t34c2.inscriere')::uuid,
    500.00::numeric,'card'::varchar,'TEST34C2-P1'::text,
    '11111111-34c2-4c21-8c21-111111111111'::uuid
  );
  IF v_id IS DISTINCT FROM pg_catalog.current_setting('t34c2.plata1')::uuid THEN
    RAISE EXCEPTION 'TEST 3.4C2: retransmiterea platii a creat alt UUID';
  END IF;
END;
$plata_idempotenta$;

DO $plata_zecimale$
BEGIN
  BEGIN
    PERFORM public.inregistreaza_plata(
      pg_catalog.current_setting('t34c2.inscriere')::uuid,
      10.001::numeric,'card'::varchar,'TEST34C2-INVALID'::text,
      '22222222-34c2-4c22-8c22-222222222222'::uuid
    );
    RAISE EXCEPTION 'TEST 3.4C2: suma cu peste 2 zecimale a fost acceptata';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL;
  END;
END;
$plata_zecimale$;

DO $plata_cheie_conflict$
BEGIN
  BEGIN
    PERFORM public.inregistreaza_plata(
      pg_catalog.current_setting('t34c2.inscriere')::uuid,
      501.00::numeric,'card'::varchar,'TEST34C2-P1'::text,
      '11111111-34c2-4c21-8c21-111111111111'::uuid
    );
    RAISE EXCEPTION 'TEST 3.4C2: cheia de idempotenta a acceptat alta cerere';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL;
  END;
END;
$plata_cheie_conflict$;

-- Confirmarea este si ea retransmisibila in siguranta.
SELECT public.confirma_plata(
  pg_catalog.current_setting('t34c2.plata1')::uuid
);
SELECT public.confirma_plata(
  pg_catalog.current_setting('t34c2.plata1')::uuid
);

DO $plata_confirmata$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.plati
    WHERE id_plata=pg_catalog.current_setting('t34c2.plata1')::uuid
      AND tip='plata' AND suma=500.00 AND stare='confirmata'
  ) THEN
    RAISE EXCEPTION 'TEST 3.4C2: plata nu este confirmata corect';
  END IF;
END;
$plata_confirmata$;

-- Plata separata pentru anulare.
SELECT pg_catalog.set_config(
  't34c2.plata2',
  public.inregistreaza_plata(
    pg_catalog.current_setting('t34c2.inscriere')::uuid,
    75.00::numeric,'numerar'::varchar,'TEST34C2-P2'::text,
    '33333333-34c2-4c23-8c23-333333333333'::uuid
  )::text,
  true
);
SELECT public.anuleaza_plata_in_asteptare(
  pg_catalog.current_setting('t34c2.plata2')::uuid,
  'test_anulare_plata'::varchar
);
SELECT public.anuleaza_plata_in_asteptare(
  pg_catalog.current_setting('t34c2.plata2')::uuid,
  'test_anulare_plata'::varchar
);

DO $anulare_plata_conflict$
BEGIN
  BEGIN
    PERFORM public.anuleaza_plata_in_asteptare(
      pg_catalog.current_setting('t34c2.plata2')::uuid,
      'alt_motiv'::varchar
    );
    RAISE EXCEPTION 'TEST 3.4C2: anularea repetata cu alt motiv a fost acceptata';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL;
  END;
END;
$anulare_plata_conflict$;

-- Rambursare: numai administrator, cu idempotenta si plafon.
SELECT pg_catalog.set_config(
  't34c2.rambursare1',
  public.inregistreaza_rambursare(
    pg_catalog.current_setting('t34c2.plata1')::uuid,
    100.00::numeric,
    'test_rambursare'::varchar,
    '44444444-34c2-4c24-8c24-444444444444'::uuid
  )::text,
  true
);

DO $rambursare_idempotenta$
DECLARE
  v_id uuid;
BEGIN
  v_id := public.inregistreaza_rambursare(
    pg_catalog.current_setting('t34c2.plata1')::uuid,
    100.00::numeric,'test_rambursare'::varchar,
    '44444444-34c2-4c24-8c24-444444444444'::uuid
  );
  IF v_id IS DISTINCT FROM pg_catalog.current_setting('t34c2.rambursare1')::uuid THEN
    RAISE EXCEPTION 'TEST 3.4C2: rambursarea idempotenta a schimbat UUID-ul';
  END IF;
END;
$rambursare_idempotenta$;

DO $rambursare_cheie_conflict$
BEGIN
  BEGIN
    PERFORM public.inregistreaza_rambursare(
      pg_catalog.current_setting('t34c2.plata1')::uuid,
      100.00::numeric,'alt_motiv'::varchar,
      '44444444-34c2-4c24-8c24-444444444444'::uuid
    );
    RAISE EXCEPTION 'TEST 3.4C2: cheia rambursarii a acceptat alta cerere';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL;
  END;
END;
$rambursare_cheie_conflict$;

DO $rambursare_plafon$
BEGIN
  BEGIN
    PERFORM public.inregistreaza_rambursare(
      pg_catalog.current_setting('t34c2.plata1')::uuid,
      450.00::numeric,'test_plafon'::varchar,
      '55555555-34c2-4c25-8c25-555555555555'::uuid
    );
    RAISE EXCEPTION 'TEST 3.4C2: plafonul rambursarii a fost depasit';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END;
$rambursare_plafon$;

-- Matrice roluri: secretariat poate inregistra plata, dar nu poate rambursa.
RESET ROLE;
UPDATE public.utilizatori
SET rol='secretariat'
WHERE id_utilizator=(SELECT id FROM auth.users WHERE email='admin.demo@example.com');
SET LOCAL ROLE authenticated;

SELECT public.inregistreaza_plata(
  pg_catalog.current_setting('t34c2.inscriere')::uuid,
  10.00::numeric,'card'::varchar,'TEST34C2-SEC'::text,
  '66666666-34c2-4c26-8c26-666666666666'::uuid
);

DO $secretariat_fara_rambursare$
BEGIN
  BEGIN
    PERFORM public.inregistreaza_rambursare(
      pg_catalog.current_setting('t34c2.plata1')::uuid,
      10.00::numeric,'test_secretariat'::varchar,
      '77777777-34c2-4c27-8c27-777777777777'::uuid
    );
    RAISE EXCEPTION 'TEST 3.4C2: secretariatul a putut rambursa';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL;
  END;
END;
$secretariat_fara_rambursare$;

RESET ROLE;
UPDATE public.utilizatori
SET rol='cursant'
WHERE id_utilizator=(SELECT id FROM auth.users WHERE email='admin.demo@example.com');
SET LOCAL ROLE authenticated;

DO $cursant_fara_scriere$
BEGIN
  BEGIN
    PERFORM public.inregistreaza_plata(
      pg_catalog.current_setting('t34c2.inscriere')::uuid,
      10.00::numeric,'card'::varchar,'TEST34C2-CURSANT'::text,
      '88888888-34c2-4c28-8c28-888888888888'::uuid
    );
    RAISE EXCEPTION 'TEST 3.4C2: rolul cursant a putut inregistra plata';
  EXCEPTION WHEN SQLSTATE 'PZ001' THEN NULL;
  END;
END;
$cursant_fara_scriere$;

RESET ROLE;
UPDATE public.utilizatori
SET rol='administrator'
WHERE id_utilizator=(SELECT id FROM auth.users WHERE email='admin.demo@example.com');
SET LOCAL ROLE authenticated;

-- Finalizam cursul: examenele trebuie sa ramana utilizabile dupa finalizarea cursului.
SELECT public.finalizeaza_inscriere(
  pg_catalog.current_setting('t34c2.inscriere')::uuid
);

SELECT pg_catalog.set_config(
  't34c2.data_examen_future',
  (pg_catalog.clock_timestamp()+INTERVAL '10 days')::text,
  true
);

SELECT pg_catalog.set_config(
  't34c2.examen_future',
  public.inregistreaza_examen(
    pg_catalog.current_setting('t34c2.inscriere')::uuid,
    'teoretic'::varchar,
    pg_catalog.current_setting('t34c2.data_examen_future')::timestamptz
  )::text,
  true
);

DO $examen_idempotent$
DECLARE
  v_id uuid;
BEGIN
  v_id := public.inregistreaza_examen(
    pg_catalog.current_setting('t34c2.inscriere')::uuid,
    'teoretic'::varchar,
    pg_catalog.current_setting('t34c2.data_examen_future')::timestamptz
  );
  IF v_id IS DISTINCT FROM pg_catalog.current_setting('t34c2.examen_future')::uuid THEN
    RAISE EXCEPTION 'TEST 3.4C2: retransmiterea programarii examenului a schimbat UUID-ul';
  END IF;
END;
$examen_idempotent$;

DO $examen_dublu_programat$
BEGIN
  BEGIN
    PERFORM public.inregistreaza_examen(
      pg_catalog.current_setting('t34c2.inscriere')::uuid,
      'teoretic'::varchar,
      pg_catalog.current_setting('t34c2.data_examen_future')::timestamptz + INTERVAL '1 day'
    );
    RAISE EXCEPTION 'TEST 3.4C2: al doilea examen programat de acelasi tip a fost acceptat';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL;
  END;
END;
$examen_dublu_programat$;

SELECT public.anuleaza_examen(
  pg_catalog.current_setting('t34c2.examen_future')::uuid,
  'test_anulare_examen'::varchar
);
SELECT public.anuleaza_examen(
  pg_catalog.current_setting('t34c2.examen_future')::uuid,
  'test_anulare_examen'::varchar
);

DO $anulare_examen_conflict$
BEGIN
  BEGIN
    PERFORM public.anuleaza_examen(
      pg_catalog.current_setting('t34c2.examen_future')::uuid,
      'alt_motiv'::varchar
    );
    RAISE EXCEPTION 'TEST 3.4C2: anularea examenului cu alt motiv a fost acceptata';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL;
  END;
END;
$anulare_examen_conflict$;

-- Seed controlat de examen trecut: triggerul 001 stabileste numarul incercarii.
RESET ROLE;
WITH e AS (
  INSERT INTO public.examene(id_inscriere,tip_examen,data_examenului,stare)
  VALUES(
    pg_catalog.current_setting('t34c2.inscriere')::uuid,
    'teoretic',
    pg_catalog.clock_timestamp()-INTERVAL '1 day',
    'programat'
  )
  RETURNING id_examen
)
SELECT pg_catalog.set_config(
  't34c2.examen_rezultat',
  (SELECT id_examen::text FROM e),
  true
);
SET LOCAL ROLE authenticated;

SELECT public.inregistreaza_rezultat(
  pg_catalog.current_setting('t34c2.examen_rezultat')::uuid,
  'admis'::varchar,
  26
);
SELECT public.inregistreaza_rezultat(
  pg_catalog.current_setting('t34c2.examen_rezultat')::uuid,
  'admis'::varchar,
  26
);

DO $rezultat_conflict$
BEGIN
  BEGIN
    PERFORM public.inregistreaza_rezultat(
      pg_catalog.current_setting('t34c2.examen_rezultat')::uuid,
      'respins'::varchar,
      20
    );
    RAISE EXCEPTION 'TEST 3.4C2: rezultatul final a putut fi rescris';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL;
  END;
END;
$rezultat_conflict$;

-- Neprezentarea este o stare finala separata si idempotenta.
RESET ROLE;
WITH e AS (
  INSERT INTO public.examene(id_inscriere,tip_examen,data_examenului,stare)
  VALUES(
    pg_catalog.current_setting('t34c2.inscriere')::uuid,
    'practic',
    pg_catalog.clock_timestamp()-INTERVAL '1 day',
    'programat'
  )
  RETURNING id_examen
)
SELECT pg_catalog.set_config(
  't34c2.examen_neprezentat',
  (SELECT id_examen::text FROM e),
  true
);
SET LOCAL ROLE authenticated;

DO $practic_punctaj_invalid$
BEGIN
  BEGIN
    PERFORM public.inregistreaza_rezultat(
      pg_catalog.current_setting('t34c2.examen_neprezentat')::uuid,
      'admis'::varchar,
      10
    );
    RAISE EXCEPTION 'TEST 3.4C2: examenul practic a acceptat punctaj numeric';
  EXCEPTION WHEN SQLSTATE 'PZ003' THEN NULL;
  END;
END;
$practic_punctaj_invalid$;

SELECT public.inregistreaza_rezultat(
  pg_catalog.current_setting('t34c2.examen_neprezentat')::uuid,
  'neprezentat'::varchar,
  NULL::integer
);
SELECT public.inregistreaza_rezultat(
  pg_catalog.current_setting('t34c2.examen_neprezentat')::uuid,
  'neprezentat'::varchar,
  NULL::integer
);

DO $practic_fara_punctaj$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.examene
    WHERE id_examen=pg_catalog.current_setting('t34c2.examen_neprezentat')::uuid
      AND stare='neprezentat' AND rezultat IS NULL AND punctaj IS NULL
  ) THEN
    RAISE EXCEPTION 'TEST 3.4C2: neprezentarea nu a fost salvata corect';
  END IF;
END;
$practic_fara_punctaj$;

RESET ROLE;

DO $audit_final$
DECLARE
  v_actor uuid := (SELECT id FROM auth.users WHERE email='admin.demo@example.com');
BEGIN
  IF (SELECT count(*) FROM public.jurnal_audit
      WHERE id_actor=v_actor AND operatie='confirma_plata'
        AND id_tinta=pg_catalog.current_setting('t34c2.plata1')::uuid) <> 1 THEN
    RAISE EXCEPTION 'TEST 3.4C2: audit confirma_plata incorect';
  END IF;
  IF (SELECT count(*) FROM public.jurnal_audit
      WHERE id_actor=v_actor AND operatie='anuleaza_plata_in_asteptare'
        AND id_tinta=pg_catalog.current_setting('t34c2.plata2')::uuid
        AND motiv='test_anulare_plata') <> 1 THEN
    RAISE EXCEPTION 'TEST 3.4C2: audit anulare plata incorect';
  END IF;
  IF (SELECT count(*) FROM public.jurnal_audit
      WHERE id_actor=v_actor AND operatie='inregistreaza_rambursare'
        AND id_tinta=pg_catalog.current_setting('t34c2.rambursare1')::uuid
        AND motiv='test_rambursare') <> 1 THEN
    RAISE EXCEPTION 'TEST 3.4C2: audit rambursare incorect';
  END IF;
  IF (SELECT count(*) FROM public.jurnal_audit
      WHERE id_actor=v_actor AND operatie='inregistreaza_examen'
        AND id_tinta=pg_catalog.current_setting('t34c2.examen_future')::uuid
        AND motiv='programare_examen') <> 1 THEN
    RAISE EXCEPTION 'TEST 3.4C2: audit programare examen incorect';
  END IF;
  IF (SELECT count(*) FROM public.jurnal_audit
      WHERE id_actor=v_actor AND operatie='anuleaza_examen'
        AND id_tinta=pg_catalog.current_setting('t34c2.examen_future')::uuid
        AND motiv='test_anulare_examen') <> 1 THEN
    RAISE EXCEPTION 'TEST 3.4C2: audit anulare examen incorect';
  END IF;
  IF (SELECT count(*) FROM public.jurnal_audit
      WHERE id_actor=v_actor AND operatie='inregistreaza_rezultat'
        AND id_tinta=pg_catalog.current_setting('t34c2.examen_rezultat')::uuid
        AND motiv='rezultat_examen') <> 1 THEN
    RAISE EXCEPTION 'TEST 3.4C2: audit rezultat examen incorect';
  END IF;
  IF (SELECT count(*) FROM public.jurnal_audit
      WHERE id_actor=v_actor AND operatie='inregistreaza_rezultat'
        AND id_tinta=pg_catalog.current_setting('t34c2.examen_neprezentat')::uuid
        AND motiv='neprezentare_examen') <> 1 THEN
    RAISE EXCEPTION 'TEST 3.4C2: audit neprezentare incorect';
  END IF;
END;
$audit_final$;

ROLLBACK;

SELECT 'ETAPA_3_4C2_FUNCTIONAL_OK' AS rezultat;

-- =========================================================
-- 3. CONCURENTA - SE RULEAZA MANUAL IN DOUA TAB-URI SQL
-- =========================================================
-- Nu se executa ca parte a testului functional de mai sus.
-- Cazurile obligatorii dupa catalog + functional:
--   A. doua apeluri simultane inregistreaza_plata cu aceeasi cheie -> acelasi UUID;
--   B. doua confirma_plata simultane -> o singura tranzitie/audit, ambele apeluri sigure;
--   C. doua inregistreaza_rambursare cu aceeasi cheie -> o singura rambursare/audit;
--   D. doua inregistreaza_examen pentru acelasi tip/inscriere -> cel mult un programat;
-- Scripturile Session A / Session B se pregatesc separat, cu fixture dedicat si cleanup.
