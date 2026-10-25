-- AUTOSTART VANCEA Manager
-- Etapa 5A - teste functionale citire administrativa cursanti
-- NUMAI pentru mediul Supabase de dezvoltare.
-- Testul este READ ONLY si se termina cu ROLLBACK.

BEGIN READ ONLY;

RESET ROLE;
SET LOCAL ROLE postgres;

-- =========================================================
-- 1. IDENTITATI DEMO
-- =========================================================

SELECT pg_catalog.set_config(
  't5.admin',
  (
    SELECT id::text
    FROM auth.users
    WHERE email = 'admin.demo@example.com'
  ),
  true
);

SELECT pg_catalog.set_config(
  't5.secretariat',
  (
    SELECT id::text
    FROM auth.users
    WHERE email = 'secretariat.demo@example.com'
  ),
  true
);

SELECT pg_catalog.set_config(
  't5.instructor',
  (
    SELECT id::text
    FROM auth.users
    WHERE email = 'instructor.a.demo@example.com'
  ),
  true
);

SELECT pg_catalog.set_config(
  't5.cursant',
  (
    SELECT id::text
    FROM auth.users
    WHERE email = 'cursant.a.demo@example.com'
  ),
  true
);

SELECT pg_catalog.set_config(
  't5.cursant_a',
  (
    SELECT c.id_cursant::text
    FROM public.cursanti c
    JOIN public.persoane p
      ON p.id_persoana = c.id_persoana
    WHERE p.nume = 'Demo35C'
      AND p.prenume = 'CursantA'
  ),
  true
);

DO $preflight$
BEGIN
  IF pg_catalog.current_setting('t5.admin', true) IS NULL
     OR pg_catalog.current_setting('t5.secretariat', true) IS NULL
     OR pg_catalog.current_setting('t5.instructor', true) IS NULL
     OR pg_catalog.current_setting('t5.cursant', true) IS NULL
     OR pg_catalog.current_setting('t5.cursant_a', true) IS NULL THEN
    RAISE EXCEPTION
      '5A FAIL: lipseste una dintre identitatile demo';
  END IF;
END;
$preflight$;


-- =========================================================
-- 2. ADMINISTRATOR
-- =========================================================

SELECT pg_catalog.set_config(
  'request.jwt.claim.sub',
  pg_catalog.current_setting('t5.admin'),
  true
);

SET LOCAL ROLE authenticated;

DO $admin$
DECLARE
  v_nr bigint;
  v_total bigint;
  v_detalii bigint;
BEGIN
  IF intern.rol_curent() <> 'administrator' THEN
    RAISE EXCEPTION
      '5A FAIL: actorul admin nu are rol administrator';
  END IF;

  SELECT
    count(*),
    COALESCE(max(total_inregistrari), 0)
  INTO
    v_nr,
    v_total
  FROM public.lista_cursanti_administrativ(
    'Demo35C',
    NULL,
    25,
    0
  );

  IF v_nr <> 2 OR v_total <> 2 THEN
    RAISE EXCEPTION
      '5A FAIL admin: cautare Demo35C -> randuri %, total %',
      v_nr,
      v_total;
  END IF;

  SELECT
    count(*),
    COALESCE(max(total_inregistrari), 0)
  INTO
    v_nr,
    v_total
  FROM public.lista_cursanti_administrativ(
    'Demo35C',
    'activ',
    1,
    0
  );

  IF v_nr <> 1 OR v_total <> 2 THEN
    RAISE EXCEPTION
      '5A FAIL admin: paginare -> randuri %, total %',
      v_nr,
      v_total;
  END IF;

  SELECT count(*)
  INTO v_detalii
  FROM public.detalii_cursant_administrativ(
    pg_catalog.current_setting('t5.cursant_a')::uuid
  );

  IF v_detalii <> 1 THEN
    RAISE EXCEPTION
      '5A FAIL admin: detalii cursant A -> % randuri',
      v_detalii;
  END IF;

  BEGIN
    EXECUTE 'SELECT cnp FROM public.cursanti LIMIT 1';

    RAISE EXCEPTION
      '5A FAIL admin: CNP citibil direct';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;

  BEGIN
    PERFORM *
    FROM public.lista_cursanti_administrativ(
      NULL,
      'necunoscuta',
      25,
      0
    );

    RAISE EXCEPTION
      '5A FAIL admin: stare invalida acceptata';
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
  pg_catalog.current_setting('t5.secretariat'),
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
      '5A FAIL: actorul secretariat nu are rol secretariat';
  END IF;

  SELECT
    count(*),
    COALESCE(max(total_inregistrari), 0)
  INTO
    v_nr,
    v_total
  FROM public.lista_cursanti_administrativ(
    'Demo35C',
    NULL,
    25,
    0
  );

  IF v_nr <> 2 OR v_total <> 2 THEN
    RAISE EXCEPTION
      '5A FAIL secretariat: randuri %, total %',
      v_nr,
      v_total;
  END IF;

  SELECT count(*)
  INTO v_detalii
  FROM public.detalii_cursant_administrativ(
    pg_catalog.current_setting('t5.cursant_a')::uuid
  );

  IF v_detalii <> 1 THEN
    RAISE EXCEPTION
      '5A FAIL secretariat: detalii cursant A -> % randuri',
      v_detalii;
  END IF;

  BEGIN
    EXECUTE 'SELECT cnp FROM public.cursanti LIMIT 1';

    RAISE EXCEPTION
      '5A FAIL secretariat: CNP citibil direct';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
  END;
END;
$secretariat$;


-- =========================================================
-- 4. INSTRUCTOR - REFUZ OBLIGATORIU
-- =========================================================

RESET ROLE;
SET LOCAL ROLE postgres;

SELECT pg_catalog.set_config(
  'request.jwt.claim.sub',
  pg_catalog.current_setting('t5.instructor'),
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
      '5A FAIL: actorul instructor nu are rol instructor';
  END IF;

  BEGIN
    PERFORM *
    FROM public.lista_cursanti_administrativ(
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
    FROM public.detalii_cursant_administrativ(
      pg_catalog.current_setting('t5.cursant_a')::uuid
    );
  EXCEPTION
    WHEN SQLSTATE 'PZ001' THEN
      v_refuz_detalii := true;
  END;

  IF NOT v_refuz_lista OR NOT v_refuz_detalii THEN
    RAISE EXCEPTION
      '5A FAIL: instructorul nu a fost refuzat complet';
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
  pg_catalog.current_setting('t5.cursant'),
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
      '5A FAIL: actorul cursant nu are rol cursant';
  END IF;

  BEGIN
    PERFORM *
    FROM public.lista_cursanti_administrativ(
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
    FROM public.detalii_cursant_administrativ(
      pg_catalog.current_setting('t5.cursant_a')::uuid
    );
  EXCEPTION
    WHEN SQLSTATE 'PZ001' THEN
      v_refuz_detalii := true;
  END;

  IF NOT v_refuz_lista OR NOT v_refuz_detalii THEN
    RAISE EXCEPTION
      '5A FAIL: cursantul nu a fost refuzat complet';
  END IF;
END;
$cursant$;


-- =========================================================
-- 6. REZULTAT
-- =========================================================

RESET ROLE;
SET LOCAL ROLE postgres;

SELECT
  'ETAPA_5A_FUNCTIONAL_OK' AS rezultat,
  2 AS cursanti_demo_gasiti,
  'ADMIN_OK' AS administrator,
  'SECRETARIAT_OK' AS secretariat,
  'INSTRUCTOR_REFUZAT' AS instructor,
  'CURSANT_REFUZAT' AS cursant,
  'CNP_DIRECT_BLOCAT' AS protectie_cnp;

ROLLBACK;
