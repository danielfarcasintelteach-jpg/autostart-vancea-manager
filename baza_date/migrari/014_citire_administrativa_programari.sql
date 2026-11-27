-- AUTOSTART VANCEA Manager
-- Etapa 5G1 - migrarea 014
-- Citire administrativa controlata pentru modulul Programari.
--
-- Principii:
-- - administrator/secretariat pot lista si consulta programarile;
-- - observatii si campurile de audit nu primesc SELECT direct;
-- - functiile private operatii.* sunt SECURITY DEFINER;
-- - wrapper-ele publice sunt SECURITY DEFINER;
-- - authenticated NU poate executa direct functiile private;
-- - nu se modifica politicile RLS existente.

RESET ROLE;

BEGIN;
SET LOCAL search_path = '';

-- ============================================================
-- 1. PREFLIGHT
-- ============================================================

DO $preflight$
BEGIN
  IF pg_catalog.to_regprocedure(
       'operatii.lista_programari_administrativ(text,varchar,date,integer,integer)'
     ) IS NOT NULL
     OR pg_catalog.to_regprocedure(
       'public.lista_programari_administrativ(text,varchar,date,integer,integer)'
     ) IS NOT NULL
     OR pg_catalog.to_regprocedure(
       'operatii.detalii_programare_administrativ(uuid)'
     ) IS NOT NULL
     OR pg_catalog.to_regprocedure(
       'public.detalii_programare_administrativ(uuid)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      '014 nu poate continua: una dintre functiile tinta exista deja';
  END IF;

  IF pg_catalog.to_regclass('public.programari') IS NULL
     OR pg_catalog.to_regclass('public.inscrieri') IS NULL
     OR pg_catalog.to_regclass('public.cursanti') IS NULL
     OR pg_catalog.to_regclass('public.instructori') IS NULL
     OR pg_catalog.to_regclass('public.vehicule') IS NULL
     OR pg_catalog.to_regclass('public.persoane') IS NULL THEN
    RAISE EXCEPTION
      '014 nu poate continua: lipseste una dintre tabelele necesare';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc
    WHERE pronamespace = 'operatii'::regnamespace
  ) <> 38 THEN
    RAISE EXCEPTION
      '014 asteapta exact 38 functii existente in schema operatii';
  END IF;

  IF pg_catalog.has_column_privilege(
       'authenticated',
       'public.programari',
       'observatii',
       'SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated',
       'public.programari',
       'id_utilizator_creare',
       'SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated',
       'public.programari',
       'data_crearii',
       'SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated',
       'public.programari',
       'data_modificarii',
       'SELECT'
     ) THEN
    RAISE EXCEPTION
      '014: granturile directe pe programari sunt mai largi decat modelul asteptat';
  END IF;

  IF pg_catalog.has_table_privilege(
       'authenticated',
       'public.programari',
       'INSERT'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated',
       'public.programari',
       'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated',
       'public.programari',
       'DELETE'
     ) THEN
    RAISE EXCEPTION
      '014: operatiile directe de scriere pe programari nu sunt blocate';
  END IF;
END;
$preflight$;

-- ============================================================
-- 2. LISTA PROGRAMARI - FUNCTIE PRIVATA
-- ============================================================

CREATE FUNCTION operatii.lista_programari_administrativ(
  p_cautare text DEFAULT NULL,
  p_stare varchar DEFAULT NULL,
  p_data date DEFAULT NULL,
  p_limita integer DEFAULT 25,
  p_offset integer DEFAULT 0
)
RETURNS TABLE(
  id_programare uuid,
  id_inscriere uuid,
  id_cursant uuid,
  cursant_nume varchar,
  cursant_prenume varchar,
  id_instructor uuid,
  instructor_nume varchar,
  instructor_prenume varchar,
  id_vehicul uuid,
  numar_inmatriculare varchar,
  marca varchar,
  model varchar,
  inceput timestamptz,
  sfarsit timestamptz,
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
    AND u.activ IS TRUE;

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
     AND v_stare NOT IN (
       'programata',
       'finalizata',
       'anulata',
       'absent'
     ) THEN
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
    pr.id_programare,
    pr.id_inscriere,
    ins.id_cursant,
    pc.nume,
    pc.prenume,
    pr.id_instructor,
    pi.nume,
    pi.prenume,
    pr.id_vehicul,
    v.numar_inmatriculare,
    v.marca,
    v.model,
    pr.inceput,
    pr.sfarsit,
    pr.stare,
    pg_catalog.count(*) OVER()
  FROM public.programari pr
  JOIN public.inscrieri ins
    ON ins.id_inscriere = pr.id_inscriere
  JOIN public.cursanti c
    ON c.id_cursant = ins.id_cursant
  JOIN public.persoane pc
    ON pc.id_persoana = c.id_persoana
  JOIN public.instructori i
    ON i.id_instructor = pr.id_instructor
  JOIN public.persoane pi
    ON pi.id_persoana = i.id_persoana
  JOIN public.vehicule v
    ON v.id_vehicul = pr.id_vehicul
  WHERE
    (
      v_stare IS NULL
      OR pr.stare = v_stare
    )
    AND
    (
      p_data IS NULL
      OR (
        pr.inceput AT TIME ZONE 'Europe/Bucharest'
      )::date = p_data
    )
    AND
    (
      v_cautare IS NULL
      OR pg_catalog.strpos(
           pg_catalog.lower(
             pg_catalog.concat_ws(
               ' ',
               pc.nume,
               pc.prenume,
               pi.nume,
               pi.prenume,
               v.numar_inmatriculare,
               v.marca,
               v.model
             )
           ),
           pg_catalog.lower(v_cautare)
         ) > 0
    )
  ORDER BY
    pr.inceput DESC,
    pc.nume,
    pc.prenume,
    pr.id_programare
  LIMIT p_limita
  OFFSET p_offset;
END;
$$;

COMMENT ON FUNCTION operatii.lista_programari_administrativ(
  text,varchar,date,integer,integer
)
IS 'AUTOSTART VANCEA Etapa 5G1 migrarea 014: lista administrativa programari';

REVOKE ALL ON FUNCTION operatii.lista_programari_administrativ(
  text,varchar,date,integer,integer
)
FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 3. LISTA PROGRAMARI - WRAPPER PUBLIC
-- ============================================================

CREATE FUNCTION public.lista_programari_administrativ(
  p_cautare text DEFAULT NULL,
  p_stare varchar DEFAULT NULL,
  p_data date DEFAULT NULL,
  p_limita integer DEFAULT 25,
  p_offset integer DEFAULT 0
)
RETURNS TABLE(
  id_programare uuid,
  id_inscriere uuid,
  id_cursant uuid,
  cursant_nume varchar,
  cursant_prenume varchar,
  id_instructor uuid,
  instructor_nume varchar,
  instructor_prenume varchar,
  id_vehicul uuid,
  numar_inmatriculare varchar,
  marca varchar,
  model varchar,
  inceput timestamptz,
  sfarsit timestamptz,
  stare varchar,
  total_inregistrari bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT *
  FROM operatii.lista_programari_administrativ(
    p_cautare,
    p_stare,
    p_data,
    p_limita,
    p_offset
  )
$$;

COMMENT ON FUNCTION public.lista_programari_administrativ(
  text,varchar,date,integer,integer
)
IS 'AUTOSTART VANCEA Etapa 5G1 migrarea 014: wrapper RPC lista administrativa programari';

REVOKE ALL ON FUNCTION public.lista_programari_administrativ(
  text,varchar,date,integer,integer
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.lista_programari_administrativ(
  text,varchar,date,integer,integer
)
TO authenticated, service_role;

-- ============================================================
-- 4. DETALII PROGRAMARE - FUNCTIE PRIVATA
-- ============================================================

CREATE FUNCTION operatii.detalii_programare_administrativ(
  p_id_programare uuid
)
RETURNS TABLE(
  id_programare uuid,
  id_inscriere uuid,
  id_cursant uuid,
  cursant_nume varchar,
  cursant_prenume varchar,
  id_instructor uuid,
  instructor_nume varchar,
  instructor_prenume varchar,
  id_vehicul uuid,
  numar_inmatriculare varchar,
  marca varchar,
  model varchar,
  inceput timestamptz,
  sfarsit timestamptz,
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
    AND u.activ IS TRUE;

  IF NOT FOUND
     OR (v_rol IN ('administrator','secretariat')) IS NOT TRUE THEN
    RAISE EXCEPTION 'Operatie neautorizata'
      USING ERRCODE = 'PZ001';
  END IF;

  IF p_id_programare IS NULL THEN
    RAISE EXCEPTION 'Identificator programare invalid'
      USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.programari pr
    WHERE pr.id_programare = p_id_programare
  ) THEN
    RAISE EXCEPTION 'Programare inexistenta'
      USING ERRCODE = 'PZ002';
  END IF;

  RETURN QUERY
  SELECT
    pr.id_programare,
    pr.id_inscriere,
    ins.id_cursant,
    pc.nume,
    pc.prenume,
    pr.id_instructor,
    pi.nume,
    pi.prenume,
    pr.id_vehicul,
    v.numar_inmatriculare,
    v.marca,
    v.model,
    pr.inceput,
    pr.sfarsit,
    pr.stare,
    pr.observatii
  FROM public.programari pr
  JOIN public.inscrieri ins
    ON ins.id_inscriere = pr.id_inscriere
  JOIN public.cursanti c
    ON c.id_cursant = ins.id_cursant
  JOIN public.persoane pc
    ON pc.id_persoana = c.id_persoana
  JOIN public.instructori i
    ON i.id_instructor = pr.id_instructor
  JOIN public.persoane pi
    ON pi.id_persoana = i.id_persoana
  JOIN public.vehicule v
    ON v.id_vehicul = pr.id_vehicul
  WHERE pr.id_programare = p_id_programare;
END;
$$;

COMMENT ON FUNCTION operatii.detalii_programare_administrativ(uuid)
IS 'AUTOSTART VANCEA Etapa 5G1 migrarea 014: detalii administrative programare';

REVOKE ALL ON FUNCTION operatii.detalii_programare_administrativ(uuid)
FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 5. DETALII PROGRAMARE - WRAPPER PUBLIC
-- ============================================================

CREATE FUNCTION public.detalii_programare_administrativ(
  p_id_programare uuid
)
RETURNS TABLE(
  id_programare uuid,
  id_inscriere uuid,
  id_cursant uuid,
  cursant_nume varchar,
  cursant_prenume varchar,
  id_instructor uuid,
  instructor_nume varchar,
  instructor_prenume varchar,
  id_vehicul uuid,
  numar_inmatriculare varchar,
  marca varchar,
  model varchar,
  inceput timestamptz,
  sfarsit timestamptz,
  stare varchar,
  observatii text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT *
  FROM operatii.detalii_programare_administrativ(
    p_id_programare
  )
$$;

COMMENT ON FUNCTION public.detalii_programare_administrativ(uuid)
IS 'AUTOSTART VANCEA Etapa 5G1 migrarea 014: wrapper RPC detalii administrative programare';

REVOKE ALL ON FUNCTION public.detalii_programare_administrativ(uuid)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.detalii_programare_administrativ(uuid)
TO authenticated, service_role;

-- ============================================================
-- 6. POSTFLIGHT
-- ============================================================

DO $postflight$
DECLARE
  v_priv_lista oid :=
    pg_catalog.to_regprocedure(
      'operatii.lista_programari_administrativ(text,varchar,date,integer,integer)'
    );

  v_pub_lista oid :=
    pg_catalog.to_regprocedure(
      'public.lista_programari_administrativ(text,varchar,date,integer,integer)'
    );

  v_priv_detalii oid :=
    pg_catalog.to_regprocedure(
      'operatii.detalii_programare_administrativ(uuid)'
    );

  v_pub_detalii oid :=
    pg_catalog.to_regprocedure(
      'public.detalii_programare_administrativ(uuid)'
    );

  v_proc record;
BEGIN
  IF v_priv_lista IS NULL
     OR v_pub_lista IS NULL
     OR v_priv_detalii IS NULL
     OR v_pub_detalii IS NULL THEN
    RAISE EXCEPTION
      '014 postflight: lipseste una dintre functiile create';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc
    WHERE pronamespace = 'operatii'::regnamespace
  ) <> 40 THEN
    RAISE EXCEPTION
      '014 postflight: schema operatii nu contine exact 40 functii';
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
        '014 postflight: STABLE/search_path incorect pentru %.%',
        v_proc.nspname,
        v_proc.proname;
    END IF;

    IF NOT v_proc.prosecdef THEN
      RAISE EXCEPTION
        '014 postflight: functia %.% nu este SECURITY DEFINER',
        v_proc.nspname,
        v_proc.proname;
    END IF;

    IF v_proc.nspname = 'operatii' THEN
      IF pg_catalog.has_function_privilege(
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
          '014 postflight: functia privata %.% este accesibila clientului',
          v_proc.nspname,
          v_proc.proname;
      END IF;
    ELSE
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
          '014 postflight: grant EXECUTE incorect pentru %.%',
          v_proc.nspname,
          v_proc.proname;
      END IF;
    END IF;
  END LOOP;

  IF pg_catalog.has_column_privilege(
       'authenticated',
       'public.programari',
       'observatii',
       'SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated',
       'public.programari',
       'id_utilizator_creare',
       'SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated',
       'public.programari',
       'data_crearii',
       'SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated',
       'public.programari',
       'data_modificarii',
       'SELECT'
     ) THEN
    RAISE EXCEPTION
      '014 postflight: a fost largit accesul direct la coloane';
  END IF;

  RAISE NOTICE 'ETAPA_5G1_MIGRAREA_014_OK';
END;
$postflight$;

COMMIT;