-- AUTOSTART VANCEA Manager
-- Etapa 5A - migrarea 009
-- Citire administrativa controlata pentru modulul Cursanti.
--
-- Principii:
-- - administrator/secretariat pot lista si consulta date administrative;
-- - instructor/cursant NU primesc coloane suplimentare;
-- - CNP NU este returnat de aceste functii;
-- - CNP ramane accesibil exclusiv prin consulta_cnp(), cu audit;
-- - wrapper-ele publice sunt SECURITY INVOKER;
-- - functiile private operatii.* sunt SECURITY DEFINER;
-- - nu se modifica politicile RLS existente.

RESET ROLE;

BEGIN;
SET LOCAL search_path = '';

-- =========================================================
-- 1. PREFLIGHT
-- =========================================================

DO $preflight$
BEGIN
  IF pg_catalog.to_regprocedure(
       'operatii.lista_cursanti_administrativ(text,varchar,integer,integer)'
     ) IS NOT NULL
     OR pg_catalog.to_regprocedure(
       'public.lista_cursanti_administrativ(text,varchar,integer,integer)'
     ) IS NOT NULL
     OR pg_catalog.to_regprocedure(
       'operatii.detalii_cursant_administrativ(uuid)'
     ) IS NOT NULL
     OR pg_catalog.to_regprocedure(
       'public.detalii_cursant_administrativ(uuid)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      '009 nu poate continua: una dintre functiile tinta exista deja';
  END IF;

  IF pg_catalog.to_regclass('public.persoane') IS NULL
     OR pg_catalog.to_regclass('public.cursanti') IS NULL THEN
    RAISE EXCEPTION
      '009 nu poate continua: lipsesc persoanele/cursantii';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc
    WHERE pronamespace = 'operatii'::regnamespace
  ) <> 30 THEN
    RAISE EXCEPTION
      '009 asteapta exact 30 functii existente in schema operatii';
  END IF;

  -- Coloanele administrative trebuie sa ramana inaccesibile direct.
  IF pg_catalog.has_column_privilege(
       'authenticated',
       'public.persoane',
       'telefon',
       'SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated',
       'public.persoane',
       'email',
       'SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated',
       'public.persoane',
       'data_nasterii',
       'SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated',
       'public.persoane',
       'adresa',
       'SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated',
       'public.cursanti',
       'cnp',
       'SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated',
       'public.cursanti',
       'observatii',
       'SELECT'
     ) THEN
    RAISE EXCEPTION
      '009: granturile directe sunt mai largi decat modelul asteptat';
  END IF;
END;
$preflight$;


-- =========================================================
-- 2. LISTA CURSANTI - FUNCTIE PRIVATA
-- =========================================================

CREATE FUNCTION operatii.lista_cursanti_administrativ(
  p_cautare text DEFAULT NULL,
  p_stare varchar DEFAULT NULL,
  p_limita integer DEFAULT 25,
  p_offset integer DEFAULT 0
)
RETURNS TABLE(
  id_cursant uuid,
  id_persoana uuid,
  nume varchar,
  prenume varchar,
  telefon varchar,
  email varchar,
  stare varchar,
  total_inregistrari bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
  v_rol varchar(20);
  v_cautare text;
  v_stare text;
BEGIN
  v_actor := auth.uid();

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Operatie neautorizata'
      USING ERRCODE = 'PZ001';
  END IF;

  SELECT u.rol
  INTO v_rol
  FROM public.utilizatori u
  WHERE u.id_utilizator = v_actor
    AND u.activ IS TRUE
;

  IF NOT FOUND
     OR (v_rol IN ('administrator','secretariat')) IS NOT TRUE THEN
    RAISE EXCEPTION 'Operatie neautorizata'
      USING ERRCODE = 'PZ001';
  END IF;

  v_cautare := NULLIF(
    pg_catalog.btrim(p_cautare),
    ''
  );

  v_stare := NULLIF(
    pg_catalog.btrim(p_stare),
    ''
  );

  IF v_cautare IS NOT NULL
     AND pg_catalog.char_length(v_cautare) > 100 THEN
    RAISE EXCEPTION 'Cautare prea lunga'
      USING ERRCODE = '22023';
  END IF;

  IF v_stare IS NOT NULL
     AND v_stare NOT IN ('activ','inactiv') THEN
    RAISE EXCEPTION 'Filtru stare invalid'
      USING ERRCODE = '22023';
  END IF;

  IF p_limita IS NULL
     OR p_limita < 1
     OR p_limita > 100 THEN
    RAISE EXCEPTION 'Limita invalida'
      USING ERRCODE = '22023';
  END IF;

  IF p_offset IS NULL
     OR p_offset < 0 THEN
    RAISE EXCEPTION 'Offset invalid'
      USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT
    c.id_cursant,
    p.id_persoana,
    p.nume,
    p.prenume,
    p.telefon,
    p.email,
    c.stare,
    pg_catalog.count(*) OVER() AS total_inregistrari
  FROM public.cursanti c
  JOIN public.persoane p
    ON p.id_persoana = c.id_persoana
  WHERE
    (
      v_stare IS NULL
      OR c.stare = v_stare
    )
    AND
    (
      v_cautare IS NULL
      OR pg_catalog.strpos(
           pg_catalog.lower(
             pg_catalog.concat_ws(
               ' ',
               p.nume,
               p.prenume,
               p.telefon,
               p.email
             )
           ),
           pg_catalog.lower(v_cautare)
         ) > 0
    )
  ORDER BY
    pg_catalog.lower(p.nume),
    pg_catalog.lower(p.prenume),
    c.id_cursant
  LIMIT p_limita
  OFFSET p_offset;
END;
$$;

COMMENT ON FUNCTION operatii.lista_cursanti_administrativ(
  text,varchar,integer,integer
)
IS 'AUTOSTART VANCEA Etapa 5A migrarea 009: lista administrativa cursanti fara CNP';

REVOKE EXECUTE ON FUNCTION operatii.lista_cursanti_administrativ(
  text,varchar,integer,integer
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION operatii.lista_cursanti_administrativ(
  text,varchar,integer,integer
)
TO authenticated;


-- =========================================================
-- 3. LISTA CURSANTI - WRAPPER PUBLIC
-- =========================================================

CREATE FUNCTION public.lista_cursanti_administrativ(
  p_cautare text DEFAULT NULL,
  p_stare varchar DEFAULT NULL,
  p_limita integer DEFAULT 25,
  p_offset integer DEFAULT 0
)
RETURNS TABLE(
  id_cursant uuid,
  id_persoana uuid,
  nume varchar,
  prenume varchar,
  telefon varchar,
  email varchar,
  stare varchar,
  total_inregistrari bigint
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT *
  FROM operatii.lista_cursanti_administrativ(
    p_cautare,
    p_stare,
    p_limita,
    p_offset
  )
$$;

COMMENT ON FUNCTION public.lista_cursanti_administrativ(
  text,varchar,integer,integer
)
IS 'AUTOSTART VANCEA Etapa 5A migrarea 009: wrapper RPC lista administrativa cursanti fara CNP';

REVOKE EXECUTE ON FUNCTION public.lista_cursanti_administrativ(
  text,varchar,integer,integer
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.lista_cursanti_administrativ(
  text,varchar,integer,integer
)
TO authenticated;


-- =========================================================
-- 4. DETALII CURSANT - FUNCTIE PRIVATA
-- =========================================================

CREATE FUNCTION operatii.detalii_cursant_administrativ(
  p_id_cursant uuid
)
RETURNS TABLE(
  id_cursant uuid,
  id_persoana uuid,
  nume varchar,
  prenume varchar,
  telefon varchar,
  email varchar,
  data_nasterii date,
  adresa text,
  stare varchar,
  observatii text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid;
  v_rol varchar(20);
BEGIN
  v_actor := auth.uid();

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Operatie neautorizata'
      USING ERRCODE = 'PZ001';
  END IF;

  SELECT u.rol
  INTO v_rol
  FROM public.utilizatori u
  WHERE u.id_utilizator = v_actor
    AND u.activ IS TRUE
;

  IF NOT FOUND
     OR (v_rol IN ('administrator','secretariat')) IS NOT TRUE THEN
    RAISE EXCEPTION 'Operatie neautorizata'
      USING ERRCODE = 'PZ001';
  END IF;

  IF p_id_cursant IS NULL THEN
    RAISE EXCEPTION 'Identificator cursant invalid'
      USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.cursanti c
    WHERE c.id_cursant = p_id_cursant
  ) THEN
    RAISE EXCEPTION 'Cursant inexistent'
      USING ERRCODE = 'PZ002';
  END IF;

  RETURN QUERY
  SELECT
    c.id_cursant,
    p.id_persoana,
    p.nume,
    p.prenume,
    p.telefon,
    p.email,
    p.data_nasterii,
    p.adresa,
    c.stare,
    c.observatii
  FROM public.cursanti c
  JOIN public.persoane p
    ON p.id_persoana = c.id_persoana
  WHERE c.id_cursant = p_id_cursant;
END;
$$;

COMMENT ON FUNCTION operatii.detalii_cursant_administrativ(uuid)
IS 'AUTOSTART VANCEA Etapa 5A migrarea 009: detalii administrative cursant fara CNP';

REVOKE EXECUTE ON FUNCTION operatii.detalii_cursant_administrativ(uuid)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION operatii.detalii_cursant_administrativ(uuid)
TO authenticated;


-- =========================================================
-- 5. DETALII CURSANT - WRAPPER PUBLIC
-- =========================================================

CREATE FUNCTION public.detalii_cursant_administrativ(
  p_id_cursant uuid
)
RETURNS TABLE(
  id_cursant uuid,
  id_persoana uuid,
  nume varchar,
  prenume varchar,
  telefon varchar,
  email varchar,
  data_nasterii date,
  adresa text,
  stare varchar,
  observatii text
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT *
  FROM operatii.detalii_cursant_administrativ(
    p_id_cursant
  )
$$;

COMMENT ON FUNCTION public.detalii_cursant_administrativ(uuid)
IS 'AUTOSTART VANCEA Etapa 5A migrarea 009: wrapper RPC detalii administrative cursant fara CNP';

REVOKE EXECUTE ON FUNCTION public.detalii_cursant_administrativ(uuid)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.detalii_cursant_administrativ(uuid)
TO authenticated;


-- =========================================================
-- 6. POSTFLIGHT
-- =========================================================

DO $postflight$
DECLARE
  v_priv_lista oid :=
    pg_catalog.to_regprocedure(
      'operatii.lista_cursanti_administrativ(text,varchar,integer,integer)'
    );

  v_pub_lista oid :=
    pg_catalog.to_regprocedure(
      'public.lista_cursanti_administrativ(text,varchar,integer,integer)'
    );

  v_priv_detalii oid :=
    pg_catalog.to_regprocedure(
      'operatii.detalii_cursant_administrativ(uuid)'
    );

  v_pub_detalii oid :=
    pg_catalog.to_regprocedure(
      'public.detalii_cursant_administrativ(uuid)'
    );

  v_proc record;
BEGIN
  IF v_priv_lista IS NULL
     OR v_pub_lista IS NULL
     OR v_priv_detalii IS NULL
     OR v_pub_detalii IS NULL THEN
    RAISE EXCEPTION
      '009 postflight: lipseste una dintre functiile create';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc
    WHERE pronamespace = 'operatii'::regnamespace
  ) <> 32 THEN
    RAISE EXCEPTION
      '009 postflight: schema operatii nu contine exact 32 functii';
  END IF;

  FOR v_proc IN
    SELECT
      p.oid,
      n.nspname,
      p.proname,
      p.prosecdef,
      p.provolatile,
      p.proconfig
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n
      ON n.oid = p.pronamespace
    WHERE p.oid IN (
      v_priv_lista,
      v_pub_lista,
      v_priv_detalii,
      v_pub_detalii
    )
  LOOP
    IF v_proc.provolatile <> 's'
       OR NOT (
         v_proc.proconfig @> ARRAY['search_path=""']
       ) THEN
      RAISE EXCEPTION
        '009 postflight: STABLE/search_path incorect pentru %.%',
        v_proc.nspname,
        v_proc.proname;
    END IF;

    IF v_proc.nspname = 'operatii'
       AND NOT v_proc.prosecdef THEN
      RAISE EXCEPTION
        '009 postflight: functia privata %.% nu este SECURITY DEFINER',
        v_proc.nspname,
        v_proc.proname;
    END IF;

    IF v_proc.nspname = 'public'
       AND v_proc.prosecdef THEN
      RAISE EXCEPTION
        '009 postflight: wrapper-ul %.% nu este SECURITY INVOKER',
        v_proc.nspname,
        v_proc.proname;
    END IF;

    IF NOT pg_catalog.has_function_privilege(
         'authenticated',
         v_proc.oid,
         'EXECUTE'
       )
       OR pg_catalog.has_function_privilege(
         'anon',
         v_proc.oid,
         'EXECUTE'
       ) THEN
      RAISE EXCEPTION
        '009 postflight: grant EXECUTE incorect pentru %.%',
        v_proc.nspname,
        v_proc.proname;
    END IF;
  END LOOP;

  -- Nicio coloana administrativa sensibila nu devine SELECT direct.
  IF pg_catalog.has_column_privilege(
       'authenticated',
       'public.persoane',
       'telefon',
       'SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated',
       'public.persoane',
       'email',
       'SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated',
       'public.persoane',
       'data_nasterii',
       'SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated',
       'public.persoane',
       'adresa',
       'SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated',
       'public.cursanti',
       'cnp',
       'SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated',
       'public.cursanti',
       'observatii',
       'SELECT'
     ) THEN
    RAISE EXCEPTION
      '009 postflight: a fost largit accesul direct la coloane';
  END IF;

  -- Politicile RLS existente nu trebuie schimbate.
  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_policy p
    JOIN pg_catalog.pg_class c
      ON c.oid = p.polrelid
    JOIN pg_catalog.pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname IN (
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
      )
  ) <> 10 THEN
    RAISE EXCEPTION
      '009 postflight: politicile RLS nu mai sunt exact 10';
  END IF;

  RAISE NOTICE
    'ETAPA_5A_MIGRAREA_009_OK';
END;
$postflight$;

COMMIT;
