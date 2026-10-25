-- AUTOSTART VANCEA Manager
-- Etapa 5D1 - teste functionale citire administrativa instructori
-- NUMAI pentru mediul Supabase de dezvoltare.
-- Testul este READ ONLY si se termina cu ROLLBACK.

BEGIN READ ONLY;

RESET ROLE;
SET LOCAL ROLE postgres;

-- =========================================================
-- 1. IDENTITATI DEMO
-- =========================================================

SELECT pg_catalog.set_config(
  't5d.admin',
  (
    SELECT id::text
    FROM auth.users
    WHERE email = 'admin.demo@example.com'
  ),
  true
);

SELECT pg_catalog.set_config(
  't5d.secretariat',
  (
    SELECT id::text
    FROM auth.users
    WHERE email = 'secretariat.demo@example.com'
  ),
  true
);

SELECT pg_catalog.set_config(
  't5d.instructor',
  (
    SELECT id::text
    FROM auth.users
    WHERE email = 'instructor.a.demo@example.com'
  ),
  true
);

SELECT pg_catalog.set_config(
  't5d.cursant',
  (
    SELECT id::text
    FROM auth.users
    WHERE email = 'cursant.a.demo@example.com'
  ),
  true
);

SELECT pg_catalog.set_config(
  't5d.instructor_a',
  (
    SELECT i.id_instructor::text
    FROM public.instructori i
    JOIN public.persoane p
      ON p.id_persoana = i.id_persoana
    WHERE p.nume = 'Demo35C'
      AND p.prenume = 'InstructorA'
  ),
  true
);

DO $preflight$
BEGIN
  IF pg_catalog.current_setting('t5d.admin', true) IS NULL
     OR pg_catalog.current_setting('t5d.secretariat', true) IS NULL
     OR pg_catalog.current_setting('t5d.instructor', true) IS NULL
     OR pg_catalog.current_setting('t5d.cursant', true) IS NULL
     OR pg_catalog.current_setting('t5d.instructor_a', true) IS NULL THEN
    RAISE EXCEPTION
      '5D1 FAIL: lipseste una dintre identitatile demo';
  END IF;
END;
$preflight$;


-- =========================================================
-- 2. ADMINISTRATOR
-- =========================================================

SELECT pg_catalog.set_config(
  'request.jwt.claim.sub',
  pg_catalog.current_setting('t5d.admin'),
  true
);

SET LOCAL ROLE authenticated;

DO $admin$
DECLARE
  v_nr bigint;
  v_total bigint;
  v_detalii bigint;
  v_data_angajarii date;
  v_observatii text;
BEGIN
  IF intern.rol_curent() <> 'administrator' THEN
    RAISE EXCEPTION
      '5D1 FAIL: actorul admin nu are rol administrator';
  END IF;

  SELECT
    count(*),
    COALESCE(max(total_inregistrari), 0)
  INTO
    v_nr,
    v_total
  FROM public.lista_instructori_administrativ(
    'Demo35C',
    NULL,
    25,
    0
  );

  IF v_nr <> 2 OR v_total <> 2 THEN
    RAISE EXCEPTION
      '5D1 FAIL admin: cautare Demo35C -> randuri %, total %',
      v_nr,
      v_total;
  END IF;

  SELECT
    count(*),
    COALESCE(max(total_inregistrari), 0)
  INTO
    v_nr,
    v_total
  FROM public.lista_instructori_administrativ(
    'Demo35C',
    'activ',
    1,
    0
  );

  IF v_nr <> 1 OR v_total <> 2 THEN
    RAISE EXCEPTION
      '5D1 FAIL admin: paginare -> randuri %, total %',
      v_nr,
      v_total;
  END IF;

  SELECT
    count(*),
    max(data_angajarii),
    max(observatii)
  INTO
    v_detalii,
    v_data_angajarii,
    v_observatii
  FROM public.detalii_instructor_administrativ(
    pg_catalog.current_setting('t5d.instructor_a')::uuid
  );

  IF v_detalii <> 1
     OR v_data_angajarii IS DISTINCT FROM '2026-01-10'::date
     OR v_observatii IS DISTINCT FROM 'fixture_3_5c'::text THEN
    RAISE EXCEPTION
      '5D1 FAIL admin: detaliile instructorului A nu corespund';
  END IF;

  BEGIN
    EXECUTE 'SELECT telefon FROM public.persoane LIMIT 1';

    RAISE EXCEPTION
      '5D1 FAIL admin: telefon citibil direct';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;

  BEGIN
    EXECUTE 'SELECT data_angajarii FROM public.instructori LIMIT 1';

    RAISE EXCEPTION
      '5D1 FAIL admin: data_angajarii citibila direct';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;

  BEGIN
    EXECUTE 'SELECT observatii FROM public.instructori LIMIT 1';

    RAISE EXCEPTION
      '5D1 FAIL admin: observatii citibile direct';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;

  BEGIN
    PERFORM *
    FROM public.lista_instructori_administrativ(
      NULL,
      'necunoscuta',
      25,
      0
    );

    RAISE EXCEPTION
      '5D1 FAIL admin: stare invalida acceptata';
  EXCEPTION
    WHEN SQLSTATE '22023' THEN
      NULL;
  END;
END;
$admin$;


-- =========================================================
-- 3. SECRETARIAT
-- =========================================================

RESET ROLE;
SET LOCAL ROLE postgres;

SELECT pg_catalog.set_config(
  'request.jwt.claim.sub',
  pg_catalog.current_setting('t5d.secretariat'),
  true
);

SET LOCAL ROLE authenticated;

DO $secretariat$
DECLARE
  v_nr bigint;
  v_total bigint;
  v_detalii bigint;
BEGIN
  IF intern.rol_curent() <> 'secretariat' THEN
    RAISE EXCEPTION
      '5D1 FAIL: actorul secretariat nu are rol secretariat';
  END IF;

  SELECT
    count(*),
    COALESCE(max(total_inregistrari), 0)
  INTO
    v_nr,
    v_total
  FROM public.lista_instructori_administrativ(
    'Demo35C',
    NULL,
    25,
    0
  );

  IF v_nr <> 2 OR v_total <> 2 THEN
    RAISE EXCEPTION
      '5D1 FAIL secretariat: randuri %, total %',
      v_nr,
      v_total;
  END IF;

  SELECT count(*)
  INTO v_detalii
  FROM public.detalii_instructor_administrativ(
    pg_catalog.current_setting('t5d.instructor_a')::uuid
  );

  IF v_detalii <> 1 THEN
    RAISE EXCEPTION
      '5D1 FAIL secretariat: detalii instructor A -> % randuri',
      v_detalii;
  END IF;
END;
$secretariat$;


-- =========================================================
-- 4. INSTRUCTOR - REFUZ OBLIGATORIU
-- =========================================================

RESET ROLE;
SET LOCAL ROLE postgres;

SELECT pg_catalog.set_config(
  'request.jwt.claim.sub',
  pg_catalog.current_setting('t5d.instructor'),
  true
);

SET LOCAL ROLE authenticated;

DO $instructor$
DECLARE
  v_refuz_lista boolean := false;
  v_refuz_detalii boolean := false;
BEGIN
  IF intern.rol_curent() <> 'instructor' THEN
    RAISE EXCEPTION
      '5D1 FAIL: actorul instructor nu are rol instructor';
  END IF;

  BEGIN
    PERFORM *
    FROM public.lista_instructori_administrativ(
      NULL,
      NULL,
      25,
      0
    );
  EXCEPTION
    WHEN SQLSTATE 'PZ001' THEN
      v_refuz_lista := true;
  END;

  BEGIN
    PERFORM *
    FROM public.detalii_instructor_administrativ(
      pg_catalog.current_setting('t5d.instructor_a')::uuid
    );
  EXCEPTION
    WHEN SQLSTATE 'PZ001' THEN
      v_refuz_detalii := true;
  END;

  IF NOT v_refuz_lista OR NOT v_refuz_detalii THEN
    RAISE EXCEPTION
      '5D1 FAIL: instructorul nu a fost refuzat complet';
  END IF;
END;
$instructor$;


-- =========================================================
-- 5. CURSANT - REFUZ OBLIGATORIU
-- =========================================================

RESET ROLE;
SET LOCAL ROLE postgres;

SELECT pg_catalog.set_config(
  'request.jwt.claim.sub',
  pg_catalog.current_setting('t5d.cursant'),
  true
);

SET LOCAL ROLE authenticated;

DO $cursant$
DECLARE
  v_refuz_lista boolean := false;
  v_refuz_detalii boolean := false;
BEGIN
  IF intern.rol_curent() <> 'cursant' THEN
    RAISE EXCEPTION
      '5D1 FAIL: actorul cursant nu are rol cursant';
  END IF;

  BEGIN
    PERFORM *
    FROM public.lista_instructori_administrativ(
      NULL,
      NULL,
      25,
      0
    );
  EXCEPTION
    WHEN SQLSTATE 'PZ001' THEN
      v_refuz_lista := true;
  END;

  BEGIN
    PERFORM *
    FROM public.detalii_instructor_administrativ(
      pg_catalog.current_setting('t5d.instructor_a')::uuid
    );
  EXCEPTION
    WHEN SQLSTATE 'PZ001' THEN
      v_refuz_detalii := true;
  END;

  IF NOT v_refuz_lista OR NOT v_refuz_detalii THEN
    RAISE EXCEPTION
      '5D1 FAIL: cursantul nu a fost refuzat complet';
  END IF;
END;
$cursant$;


-- =========================================================
-- 6. REZULTAT
-- =========================================================

RESET ROLE;
SET LOCAL ROLE postgres;

SELECT
  'ETAPA_5D1_FUNCTIONAL_OK' AS rezultat,
  2 AS instructori_demo_gasiti,
  'ADMIN_OK' AS administrator,
  'SECRETARIAT_OK' AS secretariat,
  'INSTRUCTOR_REFUZAT' AS instructor,
  'CURSANT_REFUZAT' AS cursant,
  'DATE_DIRECTE_EXTINSE_BLOCATE' AS protectie_date;

ROLLBACK;
