-- AUTOSTART VANCEA Manager
-- Etapa 5F1 - migrarea 012
-- Citire administrativa controlata pentru modulul Inscrieri.

RESET ROLE;

BEGIN;
SET LOCAL search_path = '';

DO $preflight$
BEGIN
  IF pg_catalog.to_regprocedure(
       'operatii.lista_inscrieri_administrativ(text,varchar,integer,integer)'
     ) IS NOT NULL
     OR pg_catalog.to_regprocedure(
       'public.lista_inscrieri_administrativ(text,varchar,integer,integer)'
     ) IS NOT NULL
     OR pg_catalog.to_regprocedure(
       'operatii.detalii_inscriere_administrativ(uuid)'
     ) IS NOT NULL
     OR pg_catalog.to_regprocedure(
       'public.detalii_inscriere_administrativ(uuid)'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      '012 nu poate continua: una dintre functiile tinta exista deja';
  END IF;

  IF pg_catalog.to_regclass('public.inscrieri') IS NULL
     OR pg_catalog.to_regclass('public.cursanti') IS NULL
     OR pg_catalog.to_regclass('public.instructori') IS NULL
     OR pg_catalog.to_regclass('public.persoane') IS NULL THEN
    RAISE EXCEPTION
      '012 nu poate continua: lipseste una dintre tabelele necesare';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc
    WHERE pronamespace = 'operatii'::regnamespace
  ) <> 36 THEN
    RAISE EXCEPTION
      '012 asteapta exact 36 functii existente in schema operatii';
  END IF;

  IF pg_catalog.has_column_privilege(
       'authenticated','public.inscrieri','tarif_curs','SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated','public.inscrieri','observatii','SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated','public.inscrieri','data_crearii','SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated','public.inscrieri','data_modificarii','SELECT'
     ) THEN
    RAISE EXCEPTION
      '012: granturile directe pe inscrieri sunt mai largi decat modelul asteptat';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_policy p
    JOIN pg_catalog.pg_class c ON c.oid = p.polrelid
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname IN (
        'persoane','utilizatori','cursanti','instructori','vehicule',
        'inscrieri','programari','plati','examene','jurnal_audit'
      )
  ) <> 10 THEN
    RAISE EXCEPTION
      '012: politicile RLS nu mai sunt exact 10';
  END IF;
END;
$preflight$;

CREATE FUNCTION operatii.lista_inscrieri_administrativ(
  p_cautare text DEFAULT NULL,
  p_stare varchar DEFAULT NULL,
  p_limita integer DEFAULT 25,
  p_offset integer DEFAULT 0
)
RETURNS TABLE(
  id_inscriere uuid,
  id_cursant uuid,
  cursant_nume varchar,
  cursant_prenume varchar,
  id_instructor uuid,
  instructor_nume varchar,
  instructor_prenume varchar,
  categorie char(1),
  data_inscrierii date,
  tarif_curs numeric(12,2),
  stare varchar,
  data_finalizarii date,
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

  v_cautare := NULLIF(pg_catalog.btrim(p_cautare), '');
  v_stare := NULLIF(pg_catalog.btrim(p_stare), '');

  IF v_cautare IS NOT NULL
     AND pg_catalog.char_length(v_cautare) > 100 THEN
    RAISE EXCEPTION 'Cautare prea lunga'
      USING ERRCODE = '22023';
  END IF;

  IF v_stare IS NOT NULL
     AND v_stare NOT IN ('activa','finalizata','anulata') THEN
    RAISE EXCEPTION 'Filtru stare invalid'
      USING ERRCODE = '22023';
  END IF;

  IF p_limita IS NULL OR p_limita < 1 OR p_limita > 100 THEN
    RAISE EXCEPTION 'Limita invalida'
      USING ERRCODE = '22023';
  END IF;

  IF p_offset IS NULL OR p_offset < 0 THEN
    RAISE EXCEPTION 'Offset invalid'
      USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT
    ins.id_inscriere,
    ins.id_cursant,
    pc.nume,
    pc.prenume,
    ins.id_instructor,
    pi.nume,
    pi.prenume,
    ins.categorie,
    ins.data_inscrierii,
    ins.tarif_curs,
    ins.stare,
    ins.data_finalizarii,
    pg_catalog.count(*) OVER()
  FROM public.inscrieri ins
  JOIN public.cursanti c
    ON c.id_cursant = ins.id_cursant
  JOIN public.persoane pc
    ON pc.id_persoana = c.id_persoana
  JOIN public.instructori i
    ON i.id_instructor = ins.id_instructor
  JOIN public.persoane pi
    ON pi.id_persoana = i.id_persoana
  WHERE
    (v_stare IS NULL OR ins.stare = v_stare)
    AND (
      v_cautare IS NULL
      OR pg_catalog.strpos(
           pg_catalog.lower(
             pg_catalog.concat_ws(
               ' ',
               pc.nume,
               pc.prenume,
               pi.nume,
               pi.prenume
             )
           ),
           pg_catalog.lower(v_cautare)
         ) > 0
    )
  ORDER BY
    CASE ins.stare
      WHEN 'activa' THEN 0
      WHEN 'finalizata' THEN 1
      ELSE 2
    END,
    ins.data_inscrierii DESC,
    pg_catalog.lower(pc.nume),
    pg_catalog.lower(pc.prenume),
    ins.id_inscriere
  LIMIT p_limita
  OFFSET p_offset;
END;
$$;

COMMENT ON FUNCTION operatii.lista_inscrieri_administrativ(
  text,varchar,integer,integer
)
IS 'AUTOSTART VANCEA Etapa 5F1 migrarea 012: lista administrativa inscrieri';

REVOKE EXECUTE ON FUNCTION operatii.lista_inscrieri_administrativ(
  text,varchar,integer,integer
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION operatii.lista_inscrieri_administrativ(
  text,varchar,integer,integer
)
TO authenticated;

CREATE FUNCTION public.lista_inscrieri_administrativ(
  p_cautare text DEFAULT NULL,
  p_stare varchar DEFAULT NULL,
  p_limita integer DEFAULT 25,
  p_offset integer DEFAULT 0
)
RETURNS TABLE(
  id_inscriere uuid,
  id_cursant uuid,
  cursant_nume varchar,
  cursant_prenume varchar,
  id_instructor uuid,
  instructor_nume varchar,
  instructor_prenume varchar,
  categorie char(1),
  data_inscrierii date,
  tarif_curs numeric(12,2),
  stare varchar,
  data_finalizarii date,
  total_inregistrari bigint
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT *
  FROM operatii.lista_inscrieri_administrativ(
    p_cautare,p_stare,p_limita,p_offset
  )
$$;

COMMENT ON FUNCTION public.lista_inscrieri_administrativ(
  text,varchar,integer,integer
)
IS 'AUTOSTART VANCEA Etapa 5F1 migrarea 012: wrapper RPC lista administrativa inscrieri';

REVOKE EXECUTE ON FUNCTION public.lista_inscrieri_administrativ(
  text,varchar,integer,integer
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.lista_inscrieri_administrativ(
  text,varchar,integer,integer
)
TO authenticated;

CREATE FUNCTION operatii.detalii_inscriere_administrativ(
  p_id_inscriere uuid
)
RETURNS TABLE(
  id_inscriere uuid,
  id_cursant uuid,
  cursant_nume varchar,
  cursant_prenume varchar,
  id_instructor uuid,
  instructor_nume varchar,
  instructor_prenume varchar,
  categorie char(1),
  data_inscrierii date,
  tarif_curs numeric(12,2),
  stare varchar,
  data_finalizarii date,
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

  IF p_id_inscriere IS NULL THEN
    RAISE EXCEPTION 'Identificator inscriere invalid'
      USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.inscrieri ins
    WHERE ins.id_inscriere = p_id_inscriere
  ) THEN
    RAISE EXCEPTION 'Inscriere inexistenta'
      USING ERRCODE = 'PZ002';
  END IF;

  RETURN QUERY
  SELECT
    ins.id_inscriere,
    ins.id_cursant,
    pc.nume,
    pc.prenume,
    ins.id_instructor,
    pi.nume,
    pi.prenume,
    ins.categorie,
    ins.data_inscrierii,
    ins.tarif_curs,
    ins.stare,
    ins.data_finalizarii,
    ins.observatii
  FROM public.inscrieri ins
  JOIN public.cursanti c
    ON c.id_cursant = ins.id_cursant
  JOIN public.persoane pc
    ON pc.id_persoana = c.id_persoana
  JOIN public.instructori i
    ON i.id_instructor = ins.id_instructor
  JOIN public.persoane pi
    ON pi.id_persoana = i.id_persoana
  WHERE ins.id_inscriere = p_id_inscriere;
END;
$$;

COMMENT ON FUNCTION operatii.detalii_inscriere_administrativ(uuid)
IS 'AUTOSTART VANCEA Etapa 5F1 migrarea 012: detalii administrative inscriere';

REVOKE EXECUTE ON FUNCTION operatii.detalii_inscriere_administrativ(uuid)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION operatii.detalii_inscriere_administrativ(uuid)
TO authenticated;

CREATE FUNCTION public.detalii_inscriere_administrativ(
  p_id_inscriere uuid
)
RETURNS TABLE(
  id_inscriere uuid,
  id_cursant uuid,
  cursant_nume varchar,
  cursant_prenume varchar,
  id_instructor uuid,
  instructor_nume varchar,
  instructor_prenume varchar,
  categorie char(1),
  data_inscrierii date,
  tarif_curs numeric(12,2),
  stare varchar,
  data_finalizarii date,
  observatii text
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT *
  FROM operatii.detalii_inscriere_administrativ(p_id_inscriere)
$$;

COMMENT ON FUNCTION public.detalii_inscriere_administrativ(uuid)
IS 'AUTOSTART VANCEA Etapa 5F1 migrarea 012: wrapper RPC detalii administrative inscriere';

REVOKE EXECUTE ON FUNCTION public.detalii_inscriere_administrativ(uuid)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.detalii_inscriere_administrativ(uuid)
TO authenticated;

DO $postflight$
DECLARE
  v_priv_lista oid :=
    pg_catalog.to_regprocedure(
      'operatii.lista_inscrieri_administrativ(text,varchar,integer,integer)'
    );
  v_pub_lista oid :=
    pg_catalog.to_regprocedure(
      'public.lista_inscrieri_administrativ(text,varchar,integer,integer)'
    );
  v_priv_detalii oid :=
    pg_catalog.to_regprocedure(
      'operatii.detalii_inscriere_administrativ(uuid)'
    );
  v_pub_detalii oid :=
    pg_catalog.to_regprocedure(
      'public.detalii_inscriere_administrativ(uuid)'
    );
  v_proc record;
BEGIN
  IF v_priv_lista IS NULL
     OR v_pub_lista IS NULL
     OR v_priv_detalii IS NULL
     OR v_pub_detalii IS NULL THEN
    RAISE EXCEPTION
      '012 postflight: lipseste una dintre functiile create';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc
    WHERE pronamespace = 'operatii'::regnamespace
  ) <> 38 THEN
    RAISE EXCEPTION
      '012 postflight: schema operatii nu contine exact 38 functii';
  END IF;

  FOR v_proc IN
    SELECT
      p.oid,n.nspname,p.proname,p.prosecdef,p.provolatile,p.proconfig
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
    WHERE p.oid IN (
      v_priv_lista,v_pub_lista,v_priv_detalii,v_pub_detalii
    )
  LOOP
    IF v_proc.provolatile <> 's'
       OR NOT (v_proc.proconfig @> ARRAY['search_path=""']) THEN
      RAISE EXCEPTION
        '012 postflight: STABLE/search_path incorect pentru %.%',
        v_proc.nspname,v_proc.proname;
    END IF;

    IF v_proc.nspname = 'operatii' AND NOT v_proc.prosecdef THEN
      RAISE EXCEPTION
        '012 postflight: functia privata %.% nu este SECURITY DEFINER',
        v_proc.nspname,v_proc.proname;
    END IF;

    IF v_proc.nspname = 'public' AND v_proc.prosecdef THEN
      RAISE EXCEPTION
        '012 postflight: wrapper-ul %.% nu este SECURITY INVOKER',
        v_proc.nspname,v_proc.proname;
    END IF;

    IF NOT pg_catalog.has_function_privilege(
         'authenticated',v_proc.oid,'EXECUTE'
       )
       OR pg_catalog.has_function_privilege(
         'anon',v_proc.oid,'EXECUTE'
       ) THEN
      RAISE EXCEPTION
        '012 postflight: grant EXECUTE incorect pentru %.%',
        v_proc.nspname,v_proc.proname;
    END IF;
  END LOOP;

  IF pg_catalog.has_column_privilege(
       'authenticated','public.inscrieri','tarif_curs','SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated','public.inscrieri','observatii','SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated','public.inscrieri','data_crearii','SELECT'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated','public.inscrieri','data_modificarii','SELECT'
     ) THEN
    RAISE EXCEPTION
      '012 postflight: a fost largit accesul direct la coloane';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_policy p
    JOIN pg_catalog.pg_class c ON c.oid = p.polrelid
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname IN (
        'persoane','utilizatori','cursanti','instructori','vehicule',
        'inscrieri','programari','plati','examene','jurnal_audit'
      )
  ) <> 10 THEN
    RAISE EXCEPTION
      '012 postflight: politicile RLS nu mai sunt exact 10';
  END IF;

  RAISE NOTICE 'ETAPA_5F1_MIGRAREA_012_OK';
END;
$postflight$;

COMMIT;
