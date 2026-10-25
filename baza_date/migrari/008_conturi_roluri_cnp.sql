-- AUTOSTART VANCEA Manager
-- Etapa 3.4C3: conturi, roluri si CNP. NEAPLICAT.
-- Se aplica o singura data, dupa 007, ca proprietar al obiectelor 001-007.
-- Contul Supabase Auth trebuie sa existe deja; aceasta migrare NU creeaza auth.users.
-- NU se ruleaza rollback-ul pentru testare. Testele au tranzactii proprii.

BEGIN;
SET LOCAL search_path = '';

-- =========================================================
-- 1. PREFLIGHT: starea 3.4C2 trebuie sa fie exact cea asteptata.
-- =========================================================
DO $preflight$
DECLARE
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
    'marcheaza_programare','modifica_cursant',
    'inregistreaza_plata','confirma_plata','anuleaza_plata_in_asteptare',
    'inregistreaza_rambursare','inregistreaza_examen',
    'inregistreaza_rezultat','anuleaza_examen'
  ];
  v_operatii_008 text[] := ARRAY[
    'creare_profil','schimba_rol_profil','schimba_activ_profil',
    'corecteaza_cnp','consulta_cnp'
  ];
BEGIN
  IF pg_catalog.to_regrole('authenticated') IS NULL
     OR pg_catalog.to_regrole('anon') IS NULL
     OR pg_catalog.to_regprocedure('auth.uid()') IS NULL
     OR pg_catalog.to_regclass('auth.users') IS NULL
     OR NOT pg_catalog.has_function_privilege(
       'authenticated','auth.uid()','EXECUTE'
     )
     OR NOT pg_catalog.has_schema_privilege(
       'authenticated','public','USAGE'
     ) THEN
    RAISE EXCEPTION 'Rolurile API, auth.uid() sau auth.users nu corespund';
  END IF;

  IF NOT EXISTS (
      SELECT 1
      FROM pg_catalog.pg_namespace
      WHERE nspname='operatii'
        AND nspowner=current_user::regrole
    )
    OR NOT pg_catalog.has_schema_privilege(
      'authenticated','operatii','USAGE'
    )
    OR pg_catalog.has_schema_privilege(
      'authenticated','operatii','CREATE'
    )
    OR pg_catalog.has_schema_privilege(
      'anon','operatii','USAGE, CREATE'
    )
    OR (
      SELECT pg_catalog.count(*)
      FROM pg_catalog.pg_proc
      WHERE pronamespace='operatii'::regnamespace
    ) <> 25 THEN
    RAISE EXCEPTION 'Schema operatii nu corespunde starii dupa 007';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='operatii'
      AND p.proname=ANY(v_operatii_existente)
  ) <> 25
  OR (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public'
      AND p.proname=ANY(v_operatii_existente)
  ) <> 25 THEN
    RAISE EXCEPTION 'Operatiile 004-007 sau wrapper-ele lor nu sunt exact 25';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname IN ('public','operatii')
      AND p.proname=ANY(v_operatii_008)
  ) THEN
    RAISE EXCEPTION 'Exista deja o operatie 008 sau o supraincarcare';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public'
      AND c.relname=ANY(v_tabele)
      AND c.relkind='r'
      AND c.relrowsecurity
      AND NOT c.relforcerowsecurity
      AND c.relowner=current_user::regrole
  ) <> 10 THEN
    RAISE EXCEPTION 'Cele 10 tabele, proprietarul sau RLS nu corespund';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_policy p
    JOIN pg_catalog.pg_class c ON c.oid=p.polrelid
    JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public'
      AND c.relname=ANY(v_tabele)
  ) <> 10 THEN
    RAISE EXCEPTION 'Politicile RLS nu mai sunt exact 10';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc
    WHERE pronamespace='intern'::regnamespace
  ) <> 10 THEN
    RAISE EXCEPTION 'Schema intern nu mai contine exact 10 helperi';
  END IF;

  IF pg_catalog.has_table_privilege(
       'authenticated','public.utilizatori','INSERT'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated','public.utilizatori','UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated','public.utilizatori','DELETE'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated','public.cursanti','UPDATE'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated','public.cursanti','cnp','SELECT'
     ) THEN
    RAISE EXCEPTION 'Exista acces direct interzis la profiluri sau CNP';
  END IF;

  IF pg_catalog.has_table_privilege(
       'authenticated','public.jurnal_audit','SELECT'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated','public.jurnal_audit','INSERT'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated','public.jurnal_audit','UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated','public.jurnal_audit','DELETE'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated','public.jurnal_audit','TRUNCATE'
     ) THEN
    RAISE EXCEPTION 'Jurnalul de audit are acces API direct neasteptat';
  END IF;
END;
$preflight$;

-- =========================================================
-- 2. ADMINISTRARE PROFILURI
-- =========================================================

CREATE FUNCTION operatii.creare_profil(
  p_id_utilizator uuid,
  p_id_persoana uuid,
  p_rol varchar,
  p_motiv varchar
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor uuid;
  v_rol_actor varchar(20);
BEGIN
  v_actor := auth.uid();
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;

  SELECT u.rol INTO v_rol_actor
  FROM public.utilizatori u
  WHERE u.id_utilizator=v_actor
    AND u.activ IS TRUE;
  IF NOT FOUND OR v_rol_actor<>'administrator' THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;

  -- Serializeaza toate operatiile care pot modifica guvernanta conturilor.
  PERFORM pg_catalog.pg_advisory_xact_lock(34003,3);

  SELECT u.rol INTO v_rol_actor
  FROM public.utilizatori u
  WHERE u.id_utilizator=v_actor
    AND u.activ IS TRUE
  FOR SHARE;
  IF NOT FOUND OR v_rol_actor<>'administrator' THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;

  IF p_id_utilizator IS NULL
     OR p_id_persoana IS NULL
     OR p_rol IS NULL
     OR p_rol NOT IN ('administrator','secretariat','instructor','cursant') THEN
    RAISE EXCEPTION 'Date profil invalide' USING ERRCODE='PZ003';
  END IF;

  IF p_motiv IS NULL
     OR pg_catalog.char_length(p_motiv)>80
     OR p_motiv !~ '^[a-z0-9_]+$' THEN
    RAISE EXCEPTION 'Motiv invalid' USING ERRCODE='PZ003';
  END IF;

  PERFORM 1
  FROM auth.users a
  WHERE a.id=p_id_utilizator;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cont Auth inexistent' USING ERRCODE='PZ002';
  END IF;

  PERFORM 1
  FROM public.persoane p
  WHERE p.id_persoana=p_id_persoana
  FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Persoana inexistenta' USING ERRCODE='PZ002';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.utilizatori u
    WHERE u.id_utilizator=p_id_utilizator
  ) THEN
    RAISE EXCEPTION 'Contul are deja profil' USING ERRCODE='PZ003';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.utilizatori u
    WHERE u.id_persoana=p_id_persoana
  ) THEN
    RAISE EXCEPTION 'Persoana are deja profil' USING ERRCODE='PZ003';
  END IF;

  IF p_rol='cursant'
     AND NOT EXISTS (
       SELECT 1 FROM public.cursanti c
       WHERE c.id_persoana=p_id_persoana
     ) THEN
    RAISE EXCEPTION 'Persoana nu este cursant' USING ERRCODE='PZ003';
  END IF;

  IF p_rol='instructor'
     AND NOT EXISTS (
       SELECT 1 FROM public.instructori i
       WHERE i.id_persoana=p_id_persoana
     ) THEN
    RAISE EXCEPTION 'Persoana nu este instructor' USING ERRCODE='PZ003';
  END IF;

  INSERT INTO public.utilizatori(
    id_utilizator,id_persoana,rol,activ
  ) VALUES (
    p_id_utilizator,p_id_persoana,p_rol,TRUE
  );

  INSERT INTO public.jurnal_audit(
    id_actor,operatie,entitate,id_tinta,motiv,valoare_veche,valoare_noua
  ) VALUES (
    v_actor,'creare_profil','utilizator',p_id_utilizator,p_motiv,
    NULL,p_rol
  );

  RETURN p_id_utilizator;
END;
$$;

COMMENT ON FUNCTION operatii.creare_profil(uuid,uuid,varchar,varchar)
  IS 'AUTOSTART VANCEA Etapa 3.4C3 migrarea 008: functie privata creare_profil';
REVOKE EXECUTE ON FUNCTION operatii.creare_profil(uuid,uuid,varchar,varchar)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION operatii.creare_profil(uuid,uuid,varchar,varchar)
  TO authenticated;

CREATE FUNCTION public.creare_profil(
  p_id_utilizator uuid,
  p_id_persoana uuid,
  p_rol varchar,
  p_motiv varchar
) RETURNS uuid
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = '' AS $$
  SELECT operatii.creare_profil(
    p_id_utilizator,p_id_persoana,p_rol,p_motiv
  )
$$;

COMMENT ON FUNCTION public.creare_profil(uuid,uuid,varchar,varchar)
  IS 'AUTOSTART VANCEA Etapa 3.4C3 migrarea 008: wrapper RPC creare_profil';
REVOKE EXECUTE ON FUNCTION public.creare_profil(uuid,uuid,varchar,varchar)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.creare_profil(uuid,uuid,varchar,varchar)
  TO authenticated;


CREATE FUNCTION operatii.schimba_rol_profil(
  p_id_utilizator uuid,
  p_rol_nou varchar,
  p_motiv varchar
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor uuid;
  v_rol_actor varchar(20);
  v_tinta public.utilizatori%ROWTYPE;
  v_alti_admini integer;
BEGIN
  v_actor := auth.uid();
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;

  SELECT u.rol INTO v_rol_actor
  FROM public.utilizatori u
  WHERE u.id_utilizator=v_actor
    AND u.activ IS TRUE;
  IF NOT FOUND OR v_rol_actor<>'administrator' THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(34003,3);

  SELECT u.rol INTO v_rol_actor
  FROM public.utilizatori u
  WHERE u.id_utilizator=v_actor
    AND u.activ IS TRUE
  FOR SHARE;
  IF NOT FOUND OR v_rol_actor<>'administrator' THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;

  IF p_rol_nou IS NULL
     OR p_rol_nou NOT IN ('administrator','secretariat','instructor','cursant') THEN
    RAISE EXCEPTION 'Rol nou invalid' USING ERRCODE='PZ003';
  END IF;

  IF p_motiv IS NULL
     OR pg_catalog.char_length(p_motiv)>80
     OR p_motiv !~ '^[a-z0-9_]+$' THEN
    RAISE EXCEPTION 'Motiv invalid' USING ERRCODE='PZ003';
  END IF;

  SELECT u.* INTO v_tinta
  FROM public.utilizatori u
  WHERE u.id_utilizator=p_id_utilizator
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profil inexistent' USING ERRCODE='PZ002';
  END IF;

  IF v_tinta.rol=p_rol_nou THEN
    RAISE EXCEPTION 'Rolul este deja setat' USING ERRCODE='PZ003';
  END IF;

  IF p_rol_nou='cursant'
     AND NOT EXISTS (
       SELECT 1 FROM public.cursanti c
       WHERE c.id_persoana=v_tinta.id_persoana
     ) THEN
    RAISE EXCEPTION 'Persoana nu este cursant' USING ERRCODE='PZ003';
  END IF;

  IF p_rol_nou='instructor'
     AND NOT EXISTS (
       SELECT 1 FROM public.instructori i
       WHERE i.id_persoana=v_tinta.id_persoana
     ) THEN
    RAISE EXCEPTION 'Persoana nu este instructor' USING ERRCODE='PZ003';
  END IF;

  IF v_tinta.rol='administrator'
     AND v_tinta.activ IS TRUE
     AND p_rol_nou<>'administrator' THEN
    SELECT pg_catalog.count(*)::integer INTO v_alti_admini
    FROM public.utilizatori u
    WHERE u.rol='administrator'
      AND u.activ IS TRUE
      AND u.id_utilizator<>p_id_utilizator;

    IF v_alti_admini<1 THEN
      RAISE EXCEPTION 'Nu poate fi eliminat ultimul administrator activ'
        USING ERRCODE='PZ003';
    END IF;
  END IF;

  UPDATE public.utilizatori
  SET rol=p_rol_nou
  WHERE id_utilizator=p_id_utilizator;

  INSERT INTO public.jurnal_audit(
    id_actor,operatie,entitate,id_tinta,motiv,valoare_veche,valoare_noua
  ) VALUES (
    v_actor,'schimba_rol_profil','utilizator',p_id_utilizator,p_motiv,
    v_tinta.rol,p_rol_nou
  );

  RETURN p_id_utilizator;
END;
$$;

COMMENT ON FUNCTION operatii.schimba_rol_profil(uuid,varchar,varchar)
  IS 'AUTOSTART VANCEA Etapa 3.4C3 migrarea 008: functie privata schimba_rol_profil';
REVOKE EXECUTE ON FUNCTION operatii.schimba_rol_profil(uuid,varchar,varchar)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION operatii.schimba_rol_profil(uuid,varchar,varchar)
  TO authenticated;

CREATE FUNCTION public.schimba_rol_profil(
  p_id_utilizator uuid,
  p_rol_nou varchar,
  p_motiv varchar
) RETURNS uuid
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = '' AS $$
  SELECT operatii.schimba_rol_profil(
    p_id_utilizator,p_rol_nou,p_motiv
  )
$$;

COMMENT ON FUNCTION public.schimba_rol_profil(uuid,varchar,varchar)
  IS 'AUTOSTART VANCEA Etapa 3.4C3 migrarea 008: wrapper RPC schimba_rol_profil';
REVOKE EXECUTE ON FUNCTION public.schimba_rol_profil(uuid,varchar,varchar)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.schimba_rol_profil(uuid,varchar,varchar)
  TO authenticated;


CREATE FUNCTION operatii.schimba_activ_profil(
  p_id_utilizator uuid,
  p_activ boolean,
  p_motiv varchar
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor uuid;
  v_rol_actor varchar(20);
  v_tinta public.utilizatori%ROWTYPE;
  v_alti_admini integer;
BEGIN
  v_actor := auth.uid();
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;

  SELECT u.rol INTO v_rol_actor
  FROM public.utilizatori u
  WHERE u.id_utilizator=v_actor
    AND u.activ IS TRUE;
  IF NOT FOUND OR v_rol_actor<>'administrator' THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(34003,3);

  SELECT u.rol INTO v_rol_actor
  FROM public.utilizatori u
  WHERE u.id_utilizator=v_actor
    AND u.activ IS TRUE
  FOR SHARE;
  IF NOT FOUND OR v_rol_actor<>'administrator' THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;

  IF p_activ IS NULL THEN
    RAISE EXCEPTION 'Stare profil invalida' USING ERRCODE='PZ003';
  END IF;

  IF p_motiv IS NULL
     OR pg_catalog.char_length(p_motiv)>80
     OR p_motiv !~ '^[a-z0-9_]+$' THEN
    RAISE EXCEPTION 'Motiv invalid' USING ERRCODE='PZ003';
  END IF;

  SELECT u.* INTO v_tinta
  FROM public.utilizatori u
  WHERE u.id_utilizator=p_id_utilizator
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profil inexistent' USING ERRCODE='PZ002';
  END IF;

  IF v_tinta.activ IS NOT DISTINCT FROM p_activ THEN
    RAISE EXCEPTION 'Starea profilului este deja setata'
      USING ERRCODE='PZ003';
  END IF;

  IF p_id_utilizator=v_actor AND p_activ IS FALSE THEN
    RAISE EXCEPTION 'Administratorul nu se poate dezactiva singur'
      USING ERRCODE='PZ003';
  END IF;

  IF p_activ IS TRUE AND v_tinta.rol='cursant'
     AND NOT EXISTS (
       SELECT 1 FROM public.cursanti c
       WHERE c.id_persoana=v_tinta.id_persoana
     ) THEN
    RAISE EXCEPTION 'Persoana nu mai are legatura de cursant'
      USING ERRCODE='PZ003';
  END IF;

  IF p_activ IS TRUE AND v_tinta.rol='instructor'
     AND NOT EXISTS (
       SELECT 1 FROM public.instructori i
       WHERE i.id_persoana=v_tinta.id_persoana
     ) THEN
    RAISE EXCEPTION 'Persoana nu mai are legatura de instructor'
      USING ERRCODE='PZ003';
  END IF;

  IF v_tinta.rol='administrator'
     AND v_tinta.activ IS TRUE
     AND p_activ IS FALSE THEN
    SELECT pg_catalog.count(*)::integer INTO v_alti_admini
    FROM public.utilizatori u
    WHERE u.rol='administrator'
      AND u.activ IS TRUE
      AND u.id_utilizator<>p_id_utilizator;

    IF v_alti_admini<1 THEN
      RAISE EXCEPTION 'Nu poate fi dezactivat ultimul administrator activ'
        USING ERRCODE='PZ003';
    END IF;
  END IF;

  UPDATE public.utilizatori
  SET activ=p_activ
  WHERE id_utilizator=p_id_utilizator;

  INSERT INTO public.jurnal_audit(
    id_actor,operatie,entitate,id_tinta,motiv,valoare_veche,valoare_noua
  ) VALUES (
    v_actor,'schimba_activ_profil','utilizator',p_id_utilizator,p_motiv,
    CASE WHEN v_tinta.activ THEN 'activ' ELSE 'inactiv' END,
    CASE WHEN p_activ THEN 'activ' ELSE 'inactiv' END
  );

  RETURN p_id_utilizator;
END;
$$;

COMMENT ON FUNCTION operatii.schimba_activ_profil(uuid,boolean,varchar)
  IS 'AUTOSTART VANCEA Etapa 3.4C3 migrarea 008: functie privata schimba_activ_profil';
REVOKE EXECUTE ON FUNCTION operatii.schimba_activ_profil(uuid,boolean,varchar)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION operatii.schimba_activ_profil(uuid,boolean,varchar)
  TO authenticated;

CREATE FUNCTION public.schimba_activ_profil(
  p_id_utilizator uuid,
  p_activ boolean,
  p_motiv varchar
) RETURNS uuid
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = '' AS $$
  SELECT operatii.schimba_activ_profil(
    p_id_utilizator,p_activ,p_motiv
  )
$$;

COMMENT ON FUNCTION public.schimba_activ_profil(uuid,boolean,varchar)
  IS 'AUTOSTART VANCEA Etapa 3.4C3 migrarea 008: wrapper RPC schimba_activ_profil';
REVOKE EXECUTE ON FUNCTION public.schimba_activ_profil(uuid,boolean,varchar)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.schimba_activ_profil(uuid,boolean,varchar)
  TO authenticated;

-- =========================================================
-- 3. CNP: CORECTARE SI CONSULTARE AUDITATA
-- =========================================================

CREATE FUNCTION operatii.corecteaza_cnp(
  p_id_cursant uuid,
  p_cnp_nou varchar,
  p_motiv varchar
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor uuid;
  v_rol varchar(20);
  v_cnp_vechi varchar(13);
BEGIN
  v_actor := auth.uid();
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;

  SELECT u.rol INTO v_rol
  FROM public.utilizatori u
  WHERE u.id_utilizator=v_actor
    AND u.activ IS TRUE
  FOR SHARE;
  IF NOT FOUND
     OR (v_rol IN ('administrator','secretariat')) IS NOT TRUE THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;

  IF p_cnp_nou IS NULL
     OR p_cnp_nou !~ '^[0-9]{13}$' THEN
    RAISE EXCEPTION 'CNP nou invalid' USING ERRCODE='PZ003';
  END IF;

  IF p_motiv IS NULL
     OR pg_catalog.char_length(p_motiv)>80
     OR p_motiv !~ '^[a-z0-9_]+$' THEN
    RAISE EXCEPTION 'Motiv invalid' USING ERRCODE='PZ003';
  END IF;

  SELECT c.cnp INTO v_cnp_vechi
  FROM public.cursanti c
  WHERE c.id_cursant=p_id_cursant
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cursant inexistent' USING ERRCODE='PZ002';
  END IF;

  IF v_cnp_vechi=p_cnp_nou THEN
    RAISE EXCEPTION 'CNP-ul este deja setat' USING ERRCODE='PZ003';
  END IF;

  UPDATE public.cursanti
  SET cnp=p_cnp_nou
  WHERE id_cursant=p_id_cursant;

  -- Nu jurnalizam niciodata valoarea CNP, veche sau noua.
  INSERT INTO public.jurnal_audit(
    id_actor,operatie,entitate,id_tinta,motiv,valoare_veche,valoare_noua
  ) VALUES (
    v_actor,'corecteaza_cnp','cursant',p_id_cursant,p_motiv,
    'cnp_inregistrat','cnp_corectat'
  );

  RETURN p_id_cursant;
END;
$$;

COMMENT ON FUNCTION operatii.corecteaza_cnp(uuid,varchar,varchar)
  IS 'AUTOSTART VANCEA Etapa 3.4C3 migrarea 008: functie privata corecteaza_cnp';
REVOKE EXECUTE ON FUNCTION operatii.corecteaza_cnp(uuid,varchar,varchar)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION operatii.corecteaza_cnp(uuid,varchar,varchar)
  TO authenticated;

CREATE FUNCTION public.corecteaza_cnp(
  p_id_cursant uuid,
  p_cnp_nou varchar,
  p_motiv varchar
) RETURNS uuid
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = '' AS $$
  SELECT operatii.corecteaza_cnp(
    p_id_cursant,p_cnp_nou,p_motiv
  )
$$;

COMMENT ON FUNCTION public.corecteaza_cnp(uuid,varchar,varchar)
  IS 'AUTOSTART VANCEA Etapa 3.4C3 migrarea 008: wrapper RPC corecteaza_cnp';
REVOKE EXECUTE ON FUNCTION public.corecteaza_cnp(uuid,varchar,varchar)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.corecteaza_cnp(uuid,varchar,varchar)
  TO authenticated;


CREATE FUNCTION operatii.consulta_cnp(
  p_id_cursant uuid,
  p_motiv varchar
) RETURNS varchar
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor uuid;
  v_rol varchar(20);
  v_cnp varchar(13);
BEGIN
  v_actor := auth.uid();
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;

  SELECT u.rol INTO v_rol
  FROM public.utilizatori u
  WHERE u.id_utilizator=v_actor
    AND u.activ IS TRUE
  FOR SHARE;
  IF NOT FOUND
     OR (v_rol IN ('administrator','secretariat')) IS NOT TRUE THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;

  IF p_motiv IS NULL
     OR pg_catalog.char_length(p_motiv)>80
     OR p_motiv !~ '^[a-z0-9_]+$' THEN
    RAISE EXCEPTION 'Motiv invalid' USING ERRCODE='PZ003';
  END IF;

  SELECT c.cnp INTO v_cnp
  FROM public.cursanti c
  WHERE c.id_cursant=p_id_cursant
  FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cursant inexistent' USING ERRCODE='PZ002';
  END IF;

  -- Audit obligatoriu in aceeasi tranzactie; CNP-ul nu intra in jurnal.
  INSERT INTO public.jurnal_audit(
    id_actor,operatie,entitate,id_tinta,motiv,valoare_veche,valoare_noua
  ) VALUES (
    v_actor,'consulta_cnp','cursant',p_id_cursant,p_motiv,
    NULL,NULL
  );

  RETURN v_cnp;
END;
$$;

COMMENT ON FUNCTION operatii.consulta_cnp(uuid,varchar)
  IS 'AUTOSTART VANCEA Etapa 3.4C3 migrarea 008: functie privata consulta_cnp';
REVOKE EXECUTE ON FUNCTION operatii.consulta_cnp(uuid,varchar)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION operatii.consulta_cnp(uuid,varchar)
  TO authenticated;

CREATE FUNCTION public.consulta_cnp(
  p_id_cursant uuid,
  p_motiv varchar
) RETURNS varchar
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = '' AS $$
  SELECT operatii.consulta_cnp(p_id_cursant,p_motiv)
$$;

COMMENT ON FUNCTION public.consulta_cnp(uuid,varchar)
  IS 'AUTOSTART VANCEA Etapa 3.4C3 migrarea 008: wrapper RPC consulta_cnp';
REVOKE EXECUTE ON FUNCTION public.consulta_cnp(uuid,varchar)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consulta_cnp(uuid,varchar)
  TO authenticated;

-- =========================================================
-- 4. POSTFLIGHT
-- =========================================================
DO $postflight$
DECLARE
  v_sig text;
  v_priv oid;
  v_pub oid;
  v_tabele text[] := ARRAY[
    'persoane','utilizatori','cursanti','instructori','vehicule',
    'inscrieri','programari','plati','examene','jurnal_audit'
  ];
  v_operatii_toate text[] := ARRAY[
    'creare_programare',
    'creare_cursant','modifica_persoana','schimba_stare_cursant',
    'creare_instructor','modifica_instructor','schimba_stare_instructor',
    'creare_vehicul','modifica_vehicul','schimba_stare_vehicul',
    'creare_inscriere','modifica_inscriere','finalizeaza_inscriere',
    'anuleaza_inscriere','realoca_instructor','anuleaza_programare',
    'marcheaza_programare','modifica_cursant',
    'inregistreaza_plata','confirma_plata','anuleaza_plata_in_asteptare',
    'inregistreaza_rambursare','inregistreaza_examen',
    'inregistreaza_rezultat','anuleaza_examen',
    'creare_profil','schimba_rol_profil','schimba_activ_profil',
    'corecteaza_cnp','consulta_cnp'
  ];
BEGIN
  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc
    WHERE pronamespace='operatii'::regnamespace
  ) <> 30 THEN
    RAISE EXCEPTION 'Schema operatii nu contine exact 30 functii dupa 008';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='operatii'
      AND p.proname=ANY(v_operatii_toate)
  ) <> 30
  OR (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public'
      AND p.proname=ANY(v_operatii_toate)
  ) <> 30 THEN
    RAISE EXCEPTION 'Operatiile private/wrapper-ele 004-008 nu sunt exact 30';
  END IF;

  FOREACH v_sig IN ARRAY ARRAY[
    'creare_profil(uuid,uuid,varchar,varchar)',
    'schimba_rol_profil(uuid,varchar,varchar)',
    'schimba_activ_profil(uuid,boolean,varchar)',
    'corecteaza_cnp(uuid,varchar,varchar)'
  ] LOOP
    v_priv := pg_catalog.to_regprocedure('operatii.'||v_sig);
    v_pub := pg_catalog.to_regprocedure('public.'||v_sig);

    IF v_priv IS NULL OR v_pub IS NULL THEN
      RAISE EXCEPTION 'Functie 008 lipsa: %',v_sig;
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_catalog.pg_proc p
      WHERE p.oid=v_priv
        AND p.proowner=current_user::regrole
        AND p.prorettype='uuid'::regtype
        AND p.prosecdef
        AND p.provolatile='v'
        AND p.proconfig @> ARRAY['search_path=""']
    )
    OR NOT EXISTS (
      SELECT 1
      FROM pg_catalog.pg_proc p
      WHERE p.oid=v_pub
        AND p.proowner=current_user::regrole
        AND p.prorettype='uuid'::regtype
        AND NOT p.prosecdef
        AND p.provolatile='v'
        AND p.proconfig @> ARRAY['search_path=""']
    ) THEN
      RAISE EXCEPTION 'Securitatea functiei 008 nu corespunde: %',v_sig;
    END IF;

    IF NOT pg_catalog.has_function_privilege(
         'authenticated',v_priv,'EXECUTE'
       )
       OR NOT pg_catalog.has_function_privilege(
         'authenticated',v_pub,'EXECUTE'
       )
       OR pg_catalog.has_function_privilege(
         'anon',v_priv,'EXECUTE'
       )
       OR pg_catalog.has_function_privilege(
         'anon',v_pub,'EXECUTE'
       ) THEN
      RAISE EXCEPTION 'Granturile functiei 008 nu corespund: %',v_sig;
    END IF;
  END LOOP;

  v_priv := pg_catalog.to_regprocedure(
    'operatii.consulta_cnp(uuid,varchar)'
  );
  v_pub := pg_catalog.to_regprocedure(
    'public.consulta_cnp(uuid,varchar)'
  );

  IF v_priv IS NULL OR v_pub IS NULL THEN
    RAISE EXCEPTION 'Functia consulta_cnp lipseste';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc p
    WHERE p.oid=v_priv
      AND p.proowner=current_user::regrole
      AND p.prorettype='character varying'::regtype
      AND p.prosecdef
      AND p.provolatile='v'
      AND p.proconfig @> ARRAY['search_path=""']
  )
  OR NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc p
    WHERE p.oid=v_pub
      AND p.proowner=current_user::regrole
      AND p.prorettype='character varying'::regtype
      AND NOT p.prosecdef
      AND p.provolatile='v'
      AND p.proconfig @> ARRAY['search_path=""']
  )
  OR NOT pg_catalog.has_function_privilege(
       'authenticated',v_priv,'EXECUTE'
     )
  OR NOT pg_catalog.has_function_privilege(
       'authenticated',v_pub,'EXECUTE'
     )
  OR pg_catalog.has_function_privilege(
       'anon',v_priv,'EXECUTE'
     )
  OR pg_catalog.has_function_privilege(
       'anon',v_pub,'EXECUTE'
     ) THEN
    RAISE EXCEPTION 'Securitatea sau granturile consulta_cnp nu corespund';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public'
      AND c.relname=ANY(v_tabele)
      AND c.relkind='r'
      AND c.relrowsecurity
      AND NOT c.relforcerowsecurity
      AND c.relowner=current_user::regrole
  ) <> 10 THEN
    RAISE EXCEPTION 'Tabelele/RLS au fost modificate de 008';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_policy p
    JOIN pg_catalog.pg_class c ON c.oid=p.polrelid
    JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public'
      AND c.relname=ANY(v_tabele)
  ) <> 10 THEN
    RAISE EXCEPTION 'Politicile RLS au fost modificate de 008';
  END IF;

  IF pg_catalog.has_table_privilege(
       'authenticated','public.utilizatori','INSERT'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated','public.utilizatori','UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated','public.utilizatori','DELETE'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated','public.cursanti','UPDATE'
     )
     OR pg_catalog.has_column_privilege(
       'authenticated','public.cursanti','cnp','SELECT'
     ) THEN
    RAISE EXCEPTION '008 a acordat acces direct interzis';
  END IF;

  IF pg_catalog.has_table_privilege(
       'authenticated','public.jurnal_audit','SELECT'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated','public.jurnal_audit','INSERT'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated','public.jurnal_audit','UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated','public.jurnal_audit','DELETE'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated','public.jurnal_audit','TRUNCATE'
     ) THEN
    RAISE EXCEPTION '008 a expus jurnalul de audit';
  END IF;
END;
$postflight$;

COMMIT;
