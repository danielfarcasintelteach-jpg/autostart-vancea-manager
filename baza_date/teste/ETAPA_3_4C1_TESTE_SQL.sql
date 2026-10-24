-- AUTOSTART VANCEA Manager
-- Etapa 3.4C1 - teste pentru migrarea 006.
--
-- Se ruleaza NUMAI dupa aplicarea cu succes a:
--   006_infrastructura_audit_idempotenta.sql
--
-- Testele functionale ruleaza intr-o tranzactie si se incheie cu ROLLBACK.
-- Nu trebuie sa ramana cursanti, instructori, inscrieri, plati sau audit de test.
-- Rollback-ul structural 006 NU se executa pentru aceste teste.


-- =========================================================
-- 1. TEST CATALOG / SECURITATE
-- =========================================================

DO $catalog$
DECLARE
  v_tabele text[] := ARRAY[
    'persoane',
    'utilizatori',
    'cursanti',
    'instructori',
    'vehicule',
    'inscrieri',
    'programari',
    'plati',
    'examene',
    'jurnal_audit'
  ];

  v_operatii_existente text[] := ARRAY[
    'creare_programare',
    'creare_cursant',
    'modifica_persoana',
    'schimba_stare_cursant',
    'creare_instructor',
    'modifica_instructor',
    'schimba_stare_instructor',
    'creare_vehicul',
    'modifica_vehicul',
    'schimba_stare_vehicul',
    'creare_inscriere',
    'modifica_inscriere',
    'finalizeaza_inscriere',
    'anuleaza_inscriere',
    'realoca_instructor',
    'anuleaza_programare',
    'marcheaza_programare',
    'modifica_cursant'
  ];

  v_operatii_3_4c text[] := ARRAY[
    'inregistreaza_plata',
    'confirma_plata',
    'anuleaza_plata_in_asteptare',
    'inregistreaza_rambursare',
    'inregistreaza_examen',
    'inregistreaza_rezultat',
    'anuleaza_examen',
    'creare_profil',
    'schimba_rol_profil',
    'schimba_activ_profil',
    'corecteaza_cnp',
    'consulta_cnp'
  ];
BEGIN
  -- Cele 10 tabele trebuie sa existe, cu RLS activ.
  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = ANY(v_tabele)
      AND c.relkind = 'r'
      AND c.relrowsecurity
      AND NOT c.relforcerowsecurity
      AND c.relowner = current_user::regrole
  ) <> 10 THEN
    RAISE EXCEPTION
      'TEST 3.4C1: cele 10 tabele/RLS/proprietarul nu corespund';
  END IF;

  IF pg_catalog.to_regclass('public.jurnal_audit') IS NULL THEN
    RAISE EXCEPTION
      'TEST 3.4C1: jurnal_audit lipseste';
  END IF;

  -- Tabelul de audit are exact cele 9 coloane proiectate.
  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_attribute a
    WHERE a.attrelid = 'public.jurnal_audit'::regclass
      AND a.attnum > 0
      AND NOT a.attisdropped
      AND a.attname = ANY(ARRAY[
        'id_eveniment',
        'id_actor',
        'operatie',
        'entitate',
        'id_tinta',
        'motiv',
        'valoare_veche',
        'valoare_noua',
        'data_eveniment'
      ])
  ) <> 9
  OR (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_attribute a
    WHERE a.attrelid = 'public.jurnal_audit'::regclass
      AND a.attnum > 0
      AND NOT a.attisdropped
  ) <> 9 THEN
    RAISE EXCEPTION
      'TEST 3.4C1: structura jurnal_audit nu corespunde';
  END IF;

  -- Coloana de idempotenta: UUID, nullable.
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_attribute a
    WHERE a.attrelid = 'public.plati'::regclass
      AND a.attname = 'cheie_idempotenta'
      AND a.atttypid = 'uuid'::regtype
      AND NOT a.attnotnull
      AND a.attnum > 0
      AND NOT a.attisdropped
  ) THEN
    RAISE EXCEPTION
      'TEST 3.4C1: cheie_idempotenta nu corespunde';
  END IF;

  -- Index unic partial, exact pe cheia de idempotenta.
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_index i
    JOIN pg_catalog.pg_attribute a
      ON a.attrelid = i.indrelid
     AND a.attname = 'cheie_idempotenta'
     AND a.attnum = i.indkey[0]
    WHERE i.indexrelid =
          'public.uq_plati_cheie_idempotenta'::regclass
      AND i.indrelid = 'public.plati'::regclass
      AND i.indisunique
      AND i.indisvalid
      AND i.indisready
      AND i.indnkeyatts = 1
      AND i.indpred IS NOT NULL
      AND pg_catalog.pg_get_expr(
            i.indpred,
            i.indrelid
          ) = '(cheie_idempotenta IS NOT NULL)'
  ) THEN
    RAISE EXCEPTION
      'TEST 3.4C1: indexul unic partial nu corespunde';
  END IF;

  -- Functiile auxiliare exista, sunt INVOKER si au search_path gol.
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc p
    WHERE p.oid =
          'public.protejeaza_jurnal_audit()'::regprocedure
      AND p.proowner = current_user::regrole
      AND NOT p.prosecdef
      AND p.proconfig @> ARRAY['search_path=""']
  )
  OR NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc p
    WHERE p.oid =
          'public.protejeaza_cheie_idempotenta_plata()'::regprocedure
      AND p.proowner = current_user::regrole
      AND NOT p.prosecdef
      AND p.proconfig @> ARRAY['search_path=""']
  ) THEN
    RAISE EXCEPTION
      'TEST 3.4C1: functiile auxiliare 006 nu corespund';
  END IF;

  -- Cele trei trigger-e 006 trebuie sa existe si sa fie active.
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_trigger t
    WHERE t.tgrelid = 'public.jurnal_audit'::regclass
      AND t.tgname = 'protejeaza_jurnal_audit'
      AND NOT t.tgisinternal
      AND t.tgenabled = 'O'
  )
  OR NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_trigger t
    WHERE t.tgrelid = 'public.jurnal_audit'::regclass
      AND t.tgname = 'protejeaza_jurnal_audit_truncate'
      AND NOT t.tgisinternal
      AND t.tgenabled = 'O'
  )
  OR NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_trigger t
    WHERE t.tgrelid = 'public.plati'::regclass
      AND t.tgname = 'protejeaza_cheie_idempotenta_plata'
      AND NOT t.tgisinternal
      AND t.tgenabled = 'O'
  ) THEN
    RAISE EXCEPTION
      'TEST 3.4C1: trigger-ele 006 nu corespund';
  END IF;

  -- Jurnalul nu are politici API.
  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_policy p
    WHERE p.polrelid = 'public.jurnal_audit'::regclass
  ) THEN
    RAISE EXCEPTION
      'TEST 3.4C1: jurnal_audit are politica RLS neasteptata';
  END IF;

  -- Politicile vechi raman exact 10.
  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_policy p
    JOIN pg_catalog.pg_class c
      ON c.oid = p.polrelid
    JOIN pg_catalog.pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = ANY(v_tabele)
  ) <> 10 THEN
    RAISE EXCEPTION
      'TEST 3.4C1: politicile 002-003 au fost modificate';
  END IF;

  -- authenticated si anon nu pot accesa direct jurnalul.
  IF pg_catalog.has_table_privilege(
       'authenticated',
       'public.jurnal_audit',
       'SELECT'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated',
       'public.jurnal_audit',
       'INSERT'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated',
       'public.jurnal_audit',
       'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated',
       'public.jurnal_audit',
       'DELETE'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated',
       'public.jurnal_audit',
       'TRUNCATE'
     )
     OR pg_catalog.has_table_privilege(
       'anon',
       'public.jurnal_audit',
       'SELECT'
     )
     OR pg_catalog.has_table_privilege(
       'anon',
       'public.jurnal_audit',
       'INSERT'
     )
     OR pg_catalog.has_table_privilege(
       'anon',
       'public.jurnal_audit',
       'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'anon',
       'public.jurnal_audit',
       'DELETE'
     )
     OR pg_catalog.has_table_privilege(
       'anon',
       'public.jurnal_audit',
       'TRUNCATE'
     ) THEN
    RAISE EXCEPTION
      'TEST 3.4C1: jurnal_audit are privilegii API directe';
  END IF;

  -- Functiile trigger nu sunt apelabile direct din API.
  IF pg_catalog.has_function_privilege(
       'authenticated',
       'public.protejeaza_jurnal_audit()',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'authenticated',
       'public.protejeaza_cheie_idempotenta_plata()',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'anon',
       'public.protejeaza_jurnal_audit()',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'anon',
       'public.protejeaza_cheie_idempotenta_plata()',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'TEST 3.4C1: functiile trigger sunt apelabile direct';
  END IF;

  -- Cheia noua nu devine citibila direct.
  IF pg_catalog.has_column_privilege(
       'authenticated',
       'public.plati',
       'cheie_idempotenta',
       'SELECT'
     ) THEN
    RAISE EXCEPTION
      'TEST 3.4C1: cheia de idempotenta este citibila direct';
  END IF;

  -- CNP ramane protejat.
  IF pg_catalog.has_column_privilege(
       'authenticated',
       'public.cursanti',
       'cnp',
       'SELECT'
     ) THEN
    RAISE EXCEPTION
      'TEST 3.4C1: CNP a devenit citibil direct';
  END IF;

  -- Nici DML direct pe plati nu apare.
  IF pg_catalog.has_table_privilege(
       'authenticated',
       'public.plati',
       'INSERT'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated',
       'public.plati',
       'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated',
       'public.plati',
       'DELETE'
     ) THEN
    RAISE EXCEPTION
      'TEST 3.4C1: authenticated are DML direct pe plati';
  END IF;

  -- 004-005 raman intacte: 18 private + 18 wrapperi.
  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'operatii'
      AND p.proname = ANY(v_operatii_existente)
  ) <> 18
  OR (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc p
    WHERE p.pronamespace = 'operatii'::regnamespace
  ) <> 18 THEN
    RAISE EXCEPTION
      'TEST 3.4C1: operatiile private 004-005 au fost afectate';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = ANY(v_operatii_existente)
  ) <> 18 THEN
    RAISE EXCEPTION
      'TEST 3.4C1: wrapperii 004-005 au fost afectati';
  END IF;

  -- Cele 12 operatii 3.4C nu sunt activate prematur.
  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname IN ('public', 'operatii')
      AND p.proname = ANY(v_operatii_3_4c)
  ) THEN
    RAISE EXCEPTION
      'TEST 3.4C1: exista prematur o operatie 3.4C';
  END IF;
END;
$catalog$;

SELECT 'ETAPA_3_4C1_CATALOG_OK' AS rezultat;


-- =========================================================
-- 2. TESTE FUNCTIONALE - TOTUL SE ANULEAZA PRIN ROLLBACK
-- =========================================================

BEGIN;

-- Contul administrator demonstrativ trebuie sa existe si sa aiba
-- profil administrator activ.
DO $preconditii$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM auth.users a
    JOIN public.utilizatori u
      ON u.id_utilizator = a.id
    WHERE a.email = 'admin.demo@example.com'
      AND u.rol = 'administrator'
      AND u.activ IS TRUE
  ) THEN
    RAISE EXCEPTION
      'TEST 3.4C1: admin.demo@example.com nu este administrator activ';
  END IF;
END;
$preconditii$;


-- ---------------------------------------------------------
-- Fixture temporar prin RPC-urile validate in 005.
-- ---------------------------------------------------------

SELECT pg_catalog.set_config(
  'request.jwt.claim.sub',
  (
    SELECT id::text
    FROM auth.users
    WHERE email = 'admin.demo@example.com'
  ),
  true
);

SET LOCAL ROLE authenticated;

SELECT pg_catalog.set_config(
  't34c1.cursant',
  public.creare_cursant(
    'TEST34C1'::varchar,
    'Cursant'::varchar,
    NULL::varchar,
    NULL::varchar,
    NULL::date,
    NULL::text,
    '2990101999901'::varchar,
    'fixture 3.4C1'::text
  )::text,
  true
);

SELECT pg_catalog.set_config(
  't34c1.instructor',
  public.creare_instructor(
    'TEST34C1'::varchar,
    'Instructor'::varchar,
    NULL::varchar,
    NULL::varchar,
    NULL::date,
    NULL::text,
    DATE '2026-01-01',
    'fixture 3.4C1'::text
  )::text,
  true
);

SELECT pg_catalog.set_config(
  't34c1.inscriere',
  public.creare_inscriere(
    pg_catalog.current_setting('t34c1.cursant')::uuid,
    pg_catalog.current_setting('t34c1.instructor')::uuid,
    1200.00::numeric,
    'fixture 3.4C1'::text
  )::text,
  true
);

RESET ROLE;


-- ---------------------------------------------------------
-- Plata cu o cheie de idempotenta.
-- ---------------------------------------------------------

WITH plata_noua AS (
  INSERT INTO public.plati(
    id_inscriere,
    id_utilizator_inregistrare,
    tip,
    suma,
    stare,
    metoda_plata,
    referinta,
    cheie_idempotenta
  )
  VALUES(
    pg_catalog.current_setting('t34c1.inscriere')::uuid,
    (
      SELECT id
      FROM auth.users
      WHERE email = 'admin.demo@example.com'
    ),
    'plata',
    100.00,
    'in_asteptare',
    'test',
    'TEST34C1',
    'aaaaaaaa-34c1-4c1a-8c1a-aaaaaaaaaaaa'::uuid
  )
  RETURNING id_plata
)
SELECT pg_catalog.set_config(
  't34c1.plata',
  (SELECT id_plata::text FROM plata_noua),
  true
);


-- Aceeasi cheie nu poate crea al doilea rand.
DO $unicitate$
BEGIN
  BEGIN
    INSERT INTO public.plati(
      id_inscriere,
      id_utilizator_inregistrare,
      tip,
      suma,
      stare,
      metoda_plata,
      referinta,
      cheie_idempotenta
    )
    VALUES(
      pg_catalog.current_setting('t34c1.inscriere')::uuid,
      (
        SELECT id
        FROM auth.users
        WHERE email = 'admin.demo@example.com'
      ),
      'plata',
      50.00,
      'in_asteptare',
      'test',
      'TEST34C1-DUPLICAT',
      'aaaaaaaa-34c1-4c1a-8c1a-aaaaaaaaaaaa'::uuid
    );

    RAISE EXCEPTION
      'TEST 3.4C1: cheia duplicata a fost acceptata';
  EXCEPTION
    WHEN unique_violation THEN
      NULL;
  END;
END;
$unicitate$;


-- Cheia existenta este imuabila.
DO $imutabilitate$
BEGIN
  BEGIN
    UPDATE public.plati
    SET cheie_idempotenta =
      'bbbbbbbb-34c1-4c1b-8c1b-bbbbbbbbbbbb'::uuid
    WHERE id_plata =
      pg_catalog.current_setting('t34c1.plata')::uuid;

    RAISE EXCEPTION
      'TEST 3.4C1: cheia de idempotenta a putut fi schimbata';
  EXCEPTION
    WHEN check_violation THEN
      NULL;
  END;
END;
$imutabilitate$;


-- ---------------------------------------------------------
-- Jurnal audit: INSERT permis proprietarului.
-- ---------------------------------------------------------

WITH eveniment AS (
  INSERT INTO public.jurnal_audit(
    id_actor,
    operatie,
    entitate,
    id_tinta,
    motiv,
    valoare_veche,
    valoare_noua
  )
  VALUES(
    (
      SELECT id
      FROM auth.users
      WHERE email = 'admin.demo@example.com'
    ),
    'test_34c1',
    'plata',
    pg_catalog.current_setting('t34c1.plata')::uuid,
    'test_controlat',
    NULL,
    'in_asteptare'
  )
  RETURNING id_eveniment
)
SELECT pg_catalog.set_config(
  't34c1.audit',
  (SELECT id_eveniment::text FROM eveniment),
  true
);


-- UPDATE pe jurnal trebuie blocat.
DO $audit_update$
BEGIN
  BEGIN
    UPDATE public.jurnal_audit
    SET valoare_noua = 'alta_valoare'
    WHERE id_eveniment =
      pg_catalog.current_setting('t34c1.audit')::uuid;

    RAISE EXCEPTION
      'TEST 3.4C1: UPDATE pe jurnal_audit a fost acceptat';
  EXCEPTION
    WHEN check_violation THEN
      NULL;
  END;
END;
$audit_update$;


-- DELETE pe jurnal trebuie blocat.
DO $audit_delete$
BEGIN
  BEGIN
    DELETE FROM public.jurnal_audit
    WHERE id_eveniment =
      pg_catalog.current_setting('t34c1.audit')::uuid;

    RAISE EXCEPTION
      'TEST 3.4C1: DELETE pe jurnal_audit a fost acceptat';
  EXCEPTION
    WHEN check_violation THEN
      NULL;
  END;
END;
$audit_delete$;


-- TRUNCATE pe jurnal trebuie blocat.
DO $audit_truncate$
BEGIN
  BEGIN
    EXECUTE 'TRUNCATE TABLE public.jurnal_audit';

    RAISE EXCEPTION
      'TEST 3.4C1: TRUNCATE pe jurnal_audit a fost acceptat';
  EXCEPTION
    WHEN check_violation THEN
      NULL;
  END;
END;
$audit_truncate$;


-- Evenimentul trebuie sa existe in continuare.
DO $audit_pastrat$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.jurnal_audit
    WHERE id_eveniment =
      pg_catalog.current_setting('t34c1.audit')::uuid
      AND operatie = 'test_34c1'
      AND entitate = 'plata'
      AND motiv = 'test_controlat'
      AND valoare_veche IS NULL
      AND valoare_noua = 'in_asteptare'
  ) THEN
    RAISE EXCEPTION
      'TEST 3.4C1: evenimentul de audit nu a ramas intact';
  END IF;
END;
$audit_pastrat$;


-- Motivul trebuie sa ramana un cod operational, nu text liber.
DO $motiv_invalid$
BEGIN
  BEGIN
    INSERT INTO public.jurnal_audit(
      id_actor,
      operatie,
      entitate,
      id_tinta,
      motiv
    )
    VALUES(
      (
        SELECT id
        FROM auth.users
        WHERE email = 'admin.demo@example.com'
      ),
      'test_34c1',
      'plata',
      pg_catalog.current_setting('t34c1.plata')::uuid,
      'motiv cu spatii'
    );

    RAISE EXCEPTION
      'TEST 3.4C1: un motiv liber invalid a fost acceptat';
  EXCEPTION
    WHEN check_violation THEN
      NULL;
  END;
END;
$motiv_invalid$;


-- ---------------------------------------------------------
-- Verificari efective ca authenticated nu poate ocoli RPC.
-- ---------------------------------------------------------

SET LOCAL ROLE authenticated;


DO $fara_select_jurnal$
BEGIN
  BEGIN
    PERFORM id_eveniment
    FROM public.jurnal_audit
    LIMIT 1;

    RAISE EXCEPTION
      'TEST 3.4C1: authenticated poate citi jurnal_audit';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;
END;
$fara_select_jurnal$;


DO $fara_insert_jurnal$
BEGIN
  BEGIN
    INSERT INTO public.jurnal_audit(
      id_actor,
      operatie,
      entitate,
      id_tinta,
      motiv
    )
    VALUES(
      auth.uid(),
      'test_34c1',
      'plata',
      pg_catalog.current_setting('t34c1.plata')::uuid,
      'test_nepermis'
    );

    RAISE EXCEPTION
      'TEST 3.4C1: authenticated poate insera direct in jurnal';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;
END;
$fara_insert_jurnal$;


DO $fara_cheie_directa$
BEGIN
  BEGIN
    PERFORM cheie_idempotenta
    FROM public.plati
    LIMIT 1;

    RAISE EXCEPTION
      'TEST 3.4C1: cheia de idempotenta este citibila direct';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;
END;
$fara_cheie_directa$;


DO $fara_cnp_direct$
BEGIN
  BEGIN
    PERFORM cnp
    FROM public.cursanti
    LIMIT 1;

    RAISE EXCEPTION
      'TEST 3.4C1: CNP este citibil direct';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;
END;
$fara_cnp_direct$;


RESET ROLE;


-- Tot fixture-ul si toate evenimentele/platile de test dispar.
ROLLBACK;

SELECT 'ETAPA_3_4C1_FUNCTIONAL_OK' AS rezultat;