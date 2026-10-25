-- AUTOSTART VANCEA Manager
-- Etapa 3.5C2 - fixture persistent pentru testarea interfetei pe roluri.
-- MEDIU: numai Supabase de dezvoltare.
-- Scop: creeaza profiluri pentru secretariat/instructor/cursant si doua linii
-- de date A/B, astfel incat RLS sa poata fi verificat real in aplicatie.
-- Ruleaza o singura data. La orice eroare tranzactia este anulata integral.

RESET ROLE;

BEGIN;
SET LOCAL search_path = '';

DO $preflight$
DECLARE
  v_admin uuid;
  v_secretariat uuid;
  v_instructor uuid;
  v_cursant uuid;
BEGIN
  SELECT a.id INTO v_admin
  FROM auth.users a
  JOIN public.utilizatori u ON u.id_utilizator = a.id
  WHERE a.email = 'admin.demo@example.com'
    AND u.rol = 'administrator'
    AND u.activ IS TRUE;

  SELECT a.id INTO v_secretariat
  FROM auth.users a
  WHERE a.email = 'secretariat.demo@example.com';

  SELECT a.id INTO v_instructor
  FROM auth.users a
  WHERE a.email = 'instructor.a.demo@example.com';

  SELECT a.id INTO v_cursant
  FROM auth.users a
  WHERE a.email = 'cursant.a.demo@example.com';

  IF v_admin IS NULL THEN
    RAISE EXCEPTION '3.5C: administratorul demo activ nu a fost gasit';
  END IF;

  IF v_secretariat IS NULL OR v_instructor IS NULL OR v_cursant IS NULL THEN
    RAISE EXCEPTION '3.5C: lipseste unul dintre cele trei conturi Auth demo';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.utilizatori
    WHERE id_utilizator IN (v_secretariat, v_instructor, v_cursant)
  ) THEN
    RAISE EXCEPTION '3.5C: cel putin un cont demo are deja profil';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.persoane
    WHERE nume = 'Demo35C'
  ) THEN
    RAISE EXCEPTION '3.5C: exista deja persoane fixture Demo35C';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.cursanti
    WHERE cnp IN ('0000000035001', '0000000035002')
  ) THEN
    RAISE EXCEPTION '3.5C: CNP fixture deja folosit';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.vehicule
    WHERE numar_inmatriculare IN ('MM35CTA', 'MM35CTB')
  ) THEN
    RAISE EXCEPTION '3.5C: vehicul fixture deja existent';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.plati
    WHERE cheie_idempotenta IN (
      '35000000-0000-0000-0000-000000000001'::uuid,
      '35000000-0000-0000-0000-000000000002'::uuid
    )
  ) THEN
    RAISE EXCEPTION '3.5C: cheie de idempotenta fixture deja folosita';
  END IF;
END;
$preflight$;

SELECT pg_catalog.set_config(
  't35c.admin',
  (
    SELECT a.id::text
    FROM auth.users a
    JOIN public.utilizatori u ON u.id_utilizator = a.id
    WHERE a.email = 'admin.demo@example.com'
      AND u.rol = 'administrator'
      AND u.activ IS TRUE
  ),
  true
);

SELECT pg_catalog.set_config(
  't35c.auth_secretariat',
  (SELECT id::text FROM auth.users WHERE email = 'secretariat.demo@example.com'),
  true
);

SELECT pg_catalog.set_config(
  't35c.auth_instructor',
  (SELECT id::text FROM auth.users WHERE email = 'instructor.a.demo@example.com'),
  true
);

SELECT pg_catalog.set_config(
  't35c.auth_cursant',
  (SELECT id::text FROM auth.users WHERE email = 'cursant.a.demo@example.com'),
  true
);

-- Secretariatul are nevoie doar de o persoana generica.
WITH persoana_secretariat AS (
  INSERT INTO public.persoane(nume, prenume, email)
  VALUES ('Demo35C', 'Secretariat', NULL)
  RETURNING id_persoana
)
SELECT pg_catalog.set_config(
  't35c.p_secretariat',
  (SELECT id_persoana::text FROM persoana_secretariat),
  true
);

-- Toate operatiile functionale sunt executate ca administrator autentificat.
SELECT pg_catalog.set_config(
  'request.jwt.claim.sub',
  pg_catalog.current_setting('t35c.admin'),
  true
);

SET LOCAL ROLE authenticated;

SELECT pg_catalog.set_config(
  't35c.instructor_a',
  public.creare_instructor(
    'Demo35C'::varchar,
    'InstructorA'::varchar,
    NULL::varchar,
    NULL::varchar,
    NULL::date,
    NULL::text,
    '2026-01-10'::date,
    'fixture_3_5c'::text
  )::text,
  true
);

SELECT pg_catalog.set_config(
  't35c.instructor_b',
  public.creare_instructor(
    'Demo35C'::varchar,
    'InstructorB'::varchar,
    NULL::varchar,
    NULL::varchar,
    NULL::date,
    NULL::text,
    '2026-01-11'::date,
    'fixture_3_5c_strain'::text
  )::text,
  true
);

SELECT pg_catalog.set_config(
  't35c.cursant_a',
  public.creare_cursant(
    'Demo35C'::varchar,
    'CursantA'::varchar,
    NULL::varchar,
    NULL::varchar,
    NULL::date,
    NULL::text,
    '0000000035001'::varchar,
    'fixture_3_5c'::text
  )::text,
  true
);

SELECT pg_catalog.set_config(
  't35c.cursant_b',
  public.creare_cursant(
    'Demo35C'::varchar,
    'CursantB'::varchar,
    NULL::varchar,
    NULL::varchar,
    NULL::date,
    NULL::text,
    '0000000035002'::varchar,
    'fixture_3_5c_strain'::text
  )::text,
  true
);

SELECT pg_catalog.set_config(
  't35c.vehicul_a',
  public.creare_vehicul(
    'MM35CTA'::varchar,
    'Dacia'::varchar,
    'Logan A'::varchar,
    2022::smallint,
    'fixture_3_5c'::text
  )::text,
  true
);

SELECT pg_catalog.set_config(
  't35c.vehicul_b',
  public.creare_vehicul(
    'MM35CTB'::varchar,
    'Dacia'::varchar,
    'Logan B'::varchar,
    2023::smallint,
    'fixture_3_5c_strain'::text
  )::text,
  true
);

SELECT pg_catalog.set_config(
  't35c.inscriere_a',
  public.creare_inscriere(
    pg_catalog.current_setting('t35c.cursant_a')::uuid,
    pg_catalog.current_setting('t35c.instructor_a')::uuid,
    3000::numeric,
    'fixture_3_5c'::text
  )::text,
  true
);

SELECT pg_catalog.set_config(
  't35c.inscriere_b',
  public.creare_inscriere(
    pg_catalog.current_setting('t35c.cursant_b')::uuid,
    pg_catalog.current_setting('t35c.instructor_b')::uuid,
    3200::numeric,
    'fixture_3_5c_strain'::text
  )::text,
  true
);

SELECT pg_catalog.set_config(
  't35c.programare_a',
  public.creare_programare(
    pg_catalog.current_setting('t35c.inscriere_a')::uuid,
    pg_catalog.current_setting('t35c.vehicul_a')::uuid,
    '2026-11-10 10:00:00+02'::timestamptz
  )::text,
  true
);

SELECT pg_catalog.set_config(
  't35c.programare_b',
  public.creare_programare(
    pg_catalog.current_setting('t35c.inscriere_b')::uuid,
    pg_catalog.current_setting('t35c.vehicul_b')::uuid,
    '2026-11-10 12:00:00+02'::timestamptz
  )::text,
  true
);

SELECT pg_catalog.set_config(
  't35c.plata_a',
  public.inregistreaza_plata(
    pg_catalog.current_setting('t35c.inscriere_a')::uuid,
    500::numeric,
    'numerar'::varchar,
    'fixture_3_5c_a'::text,
    '35000000-0000-0000-0000-000000000001'::uuid
  )::text,
  true
);

SELECT public.confirma_plata(
  pg_catalog.current_setting('t35c.plata_a')::uuid
);

SELECT pg_catalog.set_config(
  't35c.plata_b',
  public.inregistreaza_plata(
    pg_catalog.current_setting('t35c.inscriere_b')::uuid,
    600::numeric,
    'numerar'::varchar,
    'fixture_3_5c_b'::text,
    '35000000-0000-0000-0000-000000000002'::uuid
  )::text,
  true
);

SELECT public.confirma_plata(
  pg_catalog.current_setting('t35c.plata_b')::uuid
);

SELECT pg_catalog.set_config(
  't35c.examen_a',
  public.inregistreaza_examen(
    pg_catalog.current_setting('t35c.inscriere_a')::uuid,
    'teoretic'::varchar,
    '2026-11-20 09:00:00+02'::timestamptz
  )::text,
  true
);

SELECT pg_catalog.set_config(
  't35c.examen_b',
  public.inregistreaza_examen(
    pg_catalog.current_setting('t35c.inscriere_b')::uuid,
    'teoretic'::varchar,
    '2026-11-20 11:00:00+02'::timestamptz
  )::text,
  true
);

-- Legam cele trei conturi Auth demo de persoanele/entitatile fixture.
SELECT public.creare_profil(
  pg_catalog.current_setting('t35c.auth_secretariat')::uuid,
  pg_catalog.current_setting('t35c.p_secretariat')::uuid,
  'secretariat'::varchar,
  'fixture_3_5c_secretariat'::varchar
);

SELECT public.creare_profil(
  pg_catalog.current_setting('t35c.auth_instructor')::uuid,
  (
    SELECT id_persoana
    FROM public.instructori
    WHERE id_instructor = pg_catalog.current_setting('t35c.instructor_a')::uuid
  ),
  'instructor'::varchar,
  'fixture_3_5c_instructor'::varchar
);

SELECT public.creare_profil(
  pg_catalog.current_setting('t35c.auth_cursant')::uuid,
  (
    SELECT id_persoana
    FROM public.cursanti
    WHERE id_cursant = pg_catalog.current_setting('t35c.cursant_a')::uuid
  ),
  'cursant'::varchar,
  'fixture_3_5c_cursant'::varchar
);

RESET ROLE;

DO $verificare$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.utilizatori u
    JOIN auth.users a ON a.id = u.id_utilizator
    WHERE a.email = 'secretariat.demo@example.com'
      AND u.rol = 'secretariat'
      AND u.activ IS TRUE
  ) THEN
    RAISE EXCEPTION '3.5C: profilul secretariat nu a fost creat corect';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.utilizatori u
    JOIN auth.users a ON a.id = u.id_utilizator
    WHERE a.email = 'instructor.a.demo@example.com'
      AND u.rol = 'instructor'
      AND u.activ IS TRUE
  ) THEN
    RAISE EXCEPTION '3.5C: profilul instructor nu a fost creat corect';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.utilizatori u
    JOIN auth.users a ON a.id = u.id_utilizator
    WHERE a.email = 'cursant.a.demo@example.com'
      AND u.rol = 'cursant'
      AND u.activ IS TRUE
  ) THEN
    RAISE EXCEPTION '3.5C: profilul cursant nu a fost creat corect';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM public.cursanti
    WHERE cnp IN ('0000000035001', '0000000035002')
  ) <> 2 THEN
    RAISE EXCEPTION '3.5C: cei doi cursanti fixture nu exista';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM public.vehicule
    WHERE numar_inmatriculare IN ('MM35CTA', 'MM35CTB')
  ) <> 2 THEN
    RAISE EXCEPTION '3.5C: cele doua vehicule fixture nu exista';
  END IF;
END;
$verificare$;

COMMIT;

SELECT
  a.email,
  u.rol,
  u.activ
FROM auth.users a
JOIN public.utilizatori u ON u.id_utilizator = a.id
WHERE a.email IN (
  'secretariat.demo@example.com',
  'instructor.a.demo@example.com',
  'cursant.a.demo@example.com'
)
ORDER BY a.email;

SELECT
  (SELECT count(*) FROM public.cursanti WHERE cnp IN ('0000000035001','0000000035002')) AS cursanti_fixture,
  (SELECT count(*) FROM public.instructori i
     JOIN public.persoane p ON p.id_persoana = i.id_persoana
     WHERE p.nume = 'Demo35C') AS instructori_fixture,
  (SELECT count(*) FROM public.vehicule
     WHERE numar_inmatriculare IN ('MM35CTA','MM35CTB')) AS vehicule_fixture,
  (SELECT count(*) FROM public.inscrieri i
     JOIN public.cursanti c ON c.id_cursant = i.id_cursant
     WHERE c.cnp IN ('0000000035001','0000000035002')) AS inscrieri_fixture,
  (SELECT count(*) FROM public.programari p
     JOIN public.inscrieri i ON i.id_inscriere = p.id_inscriere
     JOIN public.cursanti c ON c.id_cursant = i.id_cursant
     WHERE c.cnp IN ('0000000035001','0000000035002')) AS programari_fixture,
  (SELECT count(*) FROM public.plati p
     JOIN public.inscrieri i ON i.id_inscriere = p.id_inscriere
     JOIN public.cursanti c ON c.id_cursant = i.id_cursant
     WHERE c.cnp IN ('0000000035001','0000000035002')) AS plati_fixture,
  (SELECT count(*) FROM public.examene e
     JOIN public.inscrieri i ON i.id_inscriere = e.id_inscriere
     JOIN public.cursanti c ON c.id_cursant = i.id_cursant
     WHERE c.cnp IN ('0000000035001','0000000035002')) AS examene_fixture;
