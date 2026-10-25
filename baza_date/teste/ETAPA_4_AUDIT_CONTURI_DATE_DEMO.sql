-- AUTOSTART VANCEA Manager
-- Etapa 4 - audit conturi si date demonstrative
-- MEDIU: numai Supabase de dezvoltare.
-- NUMAI CITIRE. Nu modifica Auth si nu modifica datele aplicatiei.

BEGIN READ ONLY;
SET LOCAL ROLE postgres;

DO $etapa_4$
DECLARE
  v_demo_total integer;
  v_demo_oficiale integer;
  v_demo_tehnice_fara_profil integer;
BEGIN

  -- Exact 8 conturi Auth fictive
  SELECT count(*)
  INTO v_demo_total
  FROM auth.users
  WHERE email IN (
    'admin.demo@example.com',
    'secretariat.demo@example.com',
    'instructor.a.demo@example.com',
    'instructor.b.demo@example.com',
    'cursant.a.demo@example.com',
    'cursant.b.demo@example.com',
    'inactiv.demo@example.com',
    'fara.profil.demo@example.com'
  );

  IF v_demo_total <> 8 THEN
    RAISE EXCEPTION
      'ETAPA 4 FAIL: conturi Auth demo %, asteptate 8',
      v_demo_total;
  END IF;

  -- Cele patru conturi oficiale trebuie sa fie confirmate
  IF EXISTS (
    SELECT 1
    FROM auth.users
    WHERE email IN (
      'admin.demo@example.com',
      'secretariat.demo@example.com',
      'instructor.a.demo@example.com',
      'cursant.a.demo@example.com'
    )
      AND email_confirmed_at IS NULL
  ) THEN
    RAISE EXCEPTION
      'ETAPA 4 FAIL: exista cont oficial demo neconfirmat';
  END IF;

  -- Exact cele patru conturi oficiale trebuie sa aiba profil
  SELECT count(*)
  INTO v_demo_oficiale
  FROM auth.users a
  JOIN public.utilizatori u
    ON u.id_utilizator = a.id
  WHERE a.email IN (
    'admin.demo@example.com',
    'secretariat.demo@example.com',
    'instructor.a.demo@example.com',
    'cursant.a.demo@example.com'
  );

  IF v_demo_oficiale <> 4 THEN
    RAISE EXCEPTION
      'ETAPA 4 FAIL: profiluri oficiale %, asteptate 4',
      v_demo_oficiale;
  END IF;

  -- Administrator
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
      'ETAPA 4 FAIL: admin.demo nu este administrator activ';
  END IF;

  -- Secretariat
  IF NOT EXISTS (
    SELECT 1
    FROM auth.users a
    JOIN public.utilizatori u
      ON u.id_utilizator = a.id
    WHERE a.email = 'secretariat.demo@example.com'
      AND u.rol = 'secretariat'
      AND u.activ IS TRUE
  ) THEN
    RAISE EXCEPTION
      'ETAPA 4 FAIL: secretariat.demo nu este secretariat activ';
  END IF;

  -- Instructor A
  IF NOT EXISTS (
    SELECT 1
    FROM auth.users a
    JOIN public.utilizatori u
      ON u.id_utilizator = a.id
    JOIN public.instructori i
      ON i.id_persoana = u.id_persoana
    WHERE a.email = 'instructor.a.demo@example.com'
      AND u.rol = 'instructor'
      AND u.activ IS TRUE
  ) THEN
    RAISE EXCEPTION
      'ETAPA 4 FAIL: instructor.a nu este legat corect';
  END IF;

  -- Cursant A
  IF NOT EXISTS (
    SELECT 1
    FROM auth.users a
    JOIN public.utilizatori u
      ON u.id_utilizator = a.id
    JOIN public.cursanti c
      ON c.id_persoana = u.id_persoana
    WHERE a.email = 'cursant.a.demo@example.com'
      AND u.rol = 'cursant'
      AND u.activ IS TRUE
  ) THEN
    RAISE EXCEPTION
      'ETAPA 4 FAIL: cursant.a nu este legat corect';
  END IF;

  -- Cele patru identitati tehnice trebuie sa ramana fara profil
  SELECT count(*)
  INTO v_demo_tehnice_fara_profil
  FROM auth.users a
  LEFT JOIN public.utilizatori u
    ON u.id_utilizator = a.id
  WHERE a.email IN (
    'instructor.b.demo@example.com',
    'cursant.b.demo@example.com',
    'inactiv.demo@example.com',
    'fara.profil.demo@example.com'
  )
    AND u.id_utilizator IS NULL;

  IF v_demo_tehnice_fara_profil <> 4 THEN
    RAISE EXCEPTION
      'ETAPA 4 FAIL: identitati tehnice fara profil %, asteptate 4',
      v_demo_tehnice_fara_profil;
  END IF;

  -- Setul persistent Demo35C
  IF (
    SELECT count(*)
    FROM public.persoane
    WHERE nume = 'Demo35C'
  ) <> 5 THEN
    RAISE EXCEPTION
      'ETAPA 4 FAIL: persoane Demo35C != 5';
  END IF;

  IF (
    SELECT count(*)
    FROM public.instructori i
    JOIN public.persoane p
      ON p.id_persoana = i.id_persoana
    WHERE p.nume = 'Demo35C'
  ) <> 2 THEN
    RAISE EXCEPTION
      'ETAPA 4 FAIL: instructori Demo35C != 2';
  END IF;

  IF (
    SELECT count(*)
    FROM public.cursanti c
    JOIN public.persoane p
      ON p.id_persoana = c.id_persoana
    WHERE p.nume = 'Demo35C'
  ) <> 2 THEN
    RAISE EXCEPTION
      'ETAPA 4 FAIL: cursanti Demo35C != 2';
  END IF;

  IF (
    SELECT count(*)
    FROM public.vehicule
    WHERE numar_inmatriculare IN ('MM35CTA','MM35CTB')
  ) <> 2 THEN
    RAISE EXCEPTION
      'ETAPA 4 FAIL: vehicule demo != 2';
  END IF;

  IF (
    SELECT count(*)
    FROM public.inscrieri i
    JOIN public.cursanti c
      ON c.id_cursant = i.id_cursant
    JOIN public.persoane p
      ON p.id_persoana = c.id_persoana
    WHERE p.nume = 'Demo35C'
  ) <> 2 THEN
    RAISE EXCEPTION
      'ETAPA 4 FAIL: inscrieri demo != 2';
  END IF;

  IF (
    SELECT count(*)
    FROM public.programari pr
    JOIN public.inscrieri i
      ON i.id_inscriere = pr.id_inscriere
    JOIN public.cursanti c
      ON c.id_cursant = i.id_cursant
    JOIN public.persoane p
      ON p.id_persoana = c.id_persoana
    WHERE p.nume = 'Demo35C'
  ) <> 2 THEN
    RAISE EXCEPTION
      'ETAPA 4 FAIL: programari demo != 2';
  END IF;

  IF (
    SELECT count(*)
    FROM public.plati pl
    JOIN public.inscrieri i
      ON i.id_inscriere = pl.id_inscriere
    JOIN public.cursanti c
      ON c.id_cursant = i.id_cursant
    JOIN public.persoane p
      ON p.id_persoana = c.id_persoana
    WHERE p.nume = 'Demo35C'
  ) <> 2 THEN
    RAISE EXCEPTION
      'ETAPA 4 FAIL: plati demo != 2';
  END IF;

  IF (
    SELECT count(*)
    FROM public.examene e
    JOIN public.inscrieri i
      ON i.id_inscriere = e.id_inscriere
    JOIN public.cursanti c
      ON c.id_cursant = i.id_cursant
    JOIN public.persoane p
      ON p.id_persoana = c.id_persoana
    WHERE p.nume = 'Demo35C'
  ) <> 2 THEN
    RAISE EXCEPTION
      'ETAPA 4 FAIL: examene demo != 2';
  END IF;

  RAISE NOTICE 'ETAPA_4_AUDIT_OK';
END;
$etapa_4$;

SELECT
  'ETAPA_4_AUDIT_OK' AS rezultat,

  (
    SELECT count(*)
    FROM auth.users
    WHERE email IN (
      'admin.demo@example.com',
      'secretariat.demo@example.com',
      'instructor.a.demo@example.com',
      'instructor.b.demo@example.com',
      'cursant.a.demo@example.com',
      'cursant.b.demo@example.com',
      'inactiv.demo@example.com',
      'fara.profil.demo@example.com'
    )
  ) AS conturi_auth_demo,

  (
    SELECT count(*)
    FROM auth.users a
    JOIN public.utilizatori u
      ON u.id_utilizator = a.id
    WHERE a.email IN (
      'admin.demo@example.com',
      'secretariat.demo@example.com',
      'instructor.a.demo@example.com',
      'cursant.a.demo@example.com'
    )
  ) AS profiluri_oficiale,

  (
    SELECT count(*)
    FROM public.instructori i
    JOIN public.persoane p
      ON p.id_persoana = i.id_persoana
    WHERE p.nume = 'Demo35C'
  ) AS instructori_demo,

  (
    SELECT count(*)
    FROM public.cursanti c
    JOIN public.persoane p
      ON p.id_persoana = c.id_persoana
    WHERE p.nume = 'Demo35C'
  ) AS cursanti_demo,

  (
    SELECT count(*)
    FROM public.vehicule
    WHERE numar_inmatriculare IN ('MM35CTA','MM35CTB')
  ) AS vehicule_demo;

ROLLBACK;
