-- AUTOSTART VANCEA Manager
-- Etapa 3.4C2: operatii financiare si examene. NEAPLICAT.
-- Se aplica o singura data, dupa 006, ca proprietar al obiectelor 001-006.
-- NU se ruleaza rollback-ul pentru testare. Testele au tranzactii proprii.

BEGIN;
SET LOCAL search_path = '';

-- =========================================================
-- 1. PREFLIGHT: schema 001-006 trebuie sa fie exact baza asteptata.
-- =========================================================
DO $preflight$
DECLARE
  v_nume text;
  v_tabele text[] := ARRAY[
    'persoane','utilizatori','cursanti','instructori','vehicule',
    'inscrieri','programari','plati','examene','jurnal_audit'
  ];
  v_politici text[] := ARRAY[
    'utilizatori.utilizatori_citire_profil_activ',
    'utilizatori.utilizatori_citire_administrator',
    'persoane.persoane_citire_roluri',
    'cursanti.cursanti_citire_roluri',
    'instructori.instructori_citire_roluri',
    'vehicule.vehicule_citire_roluri',
    'inscrieri.inscrieri_citire_roluri',
    'programari.programari_citire_roluri',
    'plati.plati_citire_roluri',
    'examene.examene_citire_roluri'
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
  v_operatii_3_4c3 text[] := ARRAY[
    'creare_profil','schimba_rol_profil','schimba_activ_profil',
    'corecteaza_cnp','consulta_cnp'
  ];
BEGIN
  IF pg_catalog.to_regrole('authenticated') IS NULL
     OR pg_catalog.to_regrole('anon') IS NULL
     OR pg_catalog.to_regprocedure('auth.uid()') IS NULL
     OR NOT pg_catalog.has_function_privilege('authenticated','auth.uid()','EXECUTE')
     OR NOT pg_catalog.has_schema_privilege('authenticated','public','USAGE') THEN
    RAISE EXCEPTION 'Rolurile API sau auth.uid() nu corespund';
  END IF;

  IF NOT EXISTS (
      SELECT 1 FROM pg_catalog.pg_namespace
      WHERE nspname='operatii' AND nspowner=current_user::regrole
    )
    OR NOT pg_catalog.has_schema_privilege('authenticated','operatii','USAGE')
    OR pg_catalog.has_schema_privilege('authenticated','operatii','CREATE')
    OR pg_catalog.has_schema_privilege('anon','operatii','USAGE, CREATE')
    OR (
      SELECT count(*) FROM pg_catalog.pg_proc
      WHERE pronamespace='operatii'::regnamespace
    ) <> 18 THEN
    RAISE EXCEPTION 'Schema operatii nu corespunde starii dupa 005';
  END IF;

  IF (
    SELECT count(*)
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='operatii'
      AND p.proname=ANY(v_operatii_existente)
  ) <> 18
  OR (
    SELECT count(*)
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public'
      AND p.proname=ANY(v_operatii_existente)
  ) <> 18 THEN
    RAISE EXCEPTION 'Operatiile 004-005 sau wrapper-ele lor nu corespund';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname IN ('public','operatii')
      AND p.proname=ANY(v_operatii_007)
  ) THEN
    RAISE EXCEPTION 'Exista deja o operatie 007 sau o supraincarcare';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname IN ('public','operatii')
      AND p.proname=ANY(v_operatii_3_4c3)
  ) THEN
    RAISE EXCEPTION 'Operatiile 3.4C3 trebuie sa lipseasca inainte de 007';
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
    RAISE EXCEPTION 'Cele 10 tabele, proprietarul sau RLS nu corespund';
  END IF;

  IF (
    SELECT count(*)
    FROM pg_catalog.pg_policy p
    JOIN pg_catalog.pg_class c ON c.oid=p.polrelid
    JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname=ANY(v_tabele)
  ) <> 10 THEN
    RAISE EXCEPTION 'Politicile RLS 002-003 nu mai sunt exact 10';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_policy p
    JOIN pg_catalog.pg_class c ON c.oid=p.polrelid
    JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname=ANY(v_tabele)
      AND (
        c.relname||'.'||p.polname<>ALL(v_politici)
        OR p.polcmd<>'r'
        OR NOT p.polpermissive
        OR p.polroles<>ARRAY['authenticated'::regrole::oid]
        OR p.polqual IS NULL
        OR p.polwithcheck IS NOT NULL
      )
  ) THEN
    RAISE EXCEPTION 'O politica RLS 002-003 a fost modificata';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_policy
    WHERE polrelid='public.jurnal_audit'::regclass
  ) THEN
    RAISE EXCEPTION 'jurnal_audit nu trebuie sa aiba politici API';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_attribute a
    WHERE a.attrelid='public.plati'::regclass
      AND a.attname='cheie_idempotenta'
      AND a.atttypid='uuid'::regtype
      AND NOT a.attnotnull
      AND a.attnum>0
      AND NOT a.attisdropped
  ) THEN
    RAISE EXCEPTION 'Coloana plati.cheie_idempotenta din 006 lipseste';
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
    RAISE EXCEPTION 'Indexul de idempotenta 006 nu corespunde';
  END IF;

  IF pg_catalog.to_regprocedure('public.protejeaza_jurnal_audit()') IS NULL
     OR pg_catalog.to_regprocedure('public.protejeaza_cheie_idempotenta_plata()') IS NULL
     OR pg_catalog.has_function_privilege(
          'authenticated','public.protejeaza_jurnal_audit()','EXECUTE')
     OR pg_catalog.has_function_privilege(
          'authenticated','public.protejeaza_cheie_idempotenta_plata()','EXECUTE')
     OR pg_catalog.has_function_privilege(
          'anon','public.protejeaza_jurnal_audit()','EXECUTE')
     OR pg_catalog.has_function_privilege(
          'anon','public.protejeaza_cheie_idempotenta_plata()','EXECUTE') THEN
    RAISE EXCEPTION 'Functiile auxiliare 006 lipsesc sau sunt expuse';
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
    RAISE EXCEPTION 'Trigger-ele 006 nu corespund';
  END IF;

  FOREACH v_nume IN ARRAY ARRAY[
    'verifica_plata()','verifica_examen()','actualizeaza_audit()'
  ] LOOP
    IF pg_catalog.to_regprocedure('public.'||v_nume) IS NULL
       OR pg_catalog.has_function_privilege(
            'authenticated','public.'||v_nume,'EXECUTE')
       OR pg_catalog.has_function_privilege(
            'anon','public.'||v_nume,'EXECUTE') THEN
      RAISE EXCEPTION 'Functie-trigger 001 lipsa sau expusa: %',v_nume;
    END IF;
  END LOOP;

  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_trigger t
    WHERE t.tgrelid='public.plati'::regclass
      AND t.tgname='verifica_plata'
      AND t.tgfoid='public.verifica_plata()'::regprocedure
      AND t.tgenabled='O' AND NOT t.tgisinternal
  )
  OR NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_trigger t
    WHERE t.tgrelid='public.examene'::regclass
      AND t.tgname='verifica_examen'
      AND t.tgfoid='public.verifica_examen()'::regprocedure
      AND t.tgenabled='O' AND NOT t.tgisinternal
  ) THEN
    RAISE EXCEPTION 'Trigger-ele de business pentru plati/examene lipsesc';
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
    RAISE EXCEPTION 'authenticated are privilegii directe nepermise';
  END IF;

  IF pg_catalog.has_table_privilege('anon','public.plati','INSERT')
     OR pg_catalog.has_table_privilege('anon','public.plati','UPDATE')
     OR pg_catalog.has_table_privilege('anon','public.plati','DELETE')
     OR pg_catalog.has_table_privilege('anon','public.examene','INSERT')
     OR pg_catalog.has_table_privilege('anon','public.examene','UPDATE')
     OR pg_catalog.has_table_privilege('anon','public.examene','DELETE')
     OR pg_catalog.has_table_privilege('anon','public.jurnal_audit','SELECT')
     OR pg_catalog.has_table_privilege('anon','public.jurnal_audit','INSERT')
     OR pg_catalog.has_table_privilege('anon','public.jurnal_audit','UPDATE')
     OR pg_catalog.has_table_privilege('anon','public.jurnal_audit','DELETE')
     OR pg_catalog.has_table_privilege('anon','public.jurnal_audit','TRUNCATE') THEN
    RAISE EXCEPTION 'anon are privilegii directe nepermise';
  END IF;

  IF pg_catalog.has_column_privilege(
       'authenticated','public.plati','cheie_idempotenta','SELECT')
     OR pg_catalog.has_column_privilege(
       'authenticated','public.cursanti','cnp','SELECT') THEN
    RAISE EXCEPTION 'O coloana sensibila a devenit citibila direct';
  END IF;
END;
$preflight$;

-- =========================================================
-- 2. OPERATII FINANCIARE
-- =========================================================

CREATE FUNCTION operatii.inregistreaza_plata(
  p_id_inscriere uuid,
  p_suma numeric,
  p_metoda_plata varchar,
  p_referinta text,
  p_cheie_idempotenta uuid
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor uuid;
  v_rol varchar(20);
  v_stare_inscriere varchar(12);
  v_existenta public.plati%ROWTYPE;
  v_id_plata uuid;
BEGIN
  v_actor := auth.uid();
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;

  SELECT u.rol INTO v_rol
  FROM public.utilizatori u
  WHERE u.id_utilizator=v_actor AND u.activ IS TRUE
  FOR SHARE;
  IF NOT FOUND OR (v_rol IN ('administrator','secretariat')) IS NOT TRUE THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;

  IF p_id_inscriere IS NULL
     OR p_suma IS NULL OR p_suma<=0
     OR p_suma>9999999999.99
     OR p_suma IS DISTINCT FROM pg_catalog.round(p_suma,2)
     OR p_cheie_idempotenta IS NULL THEN
    RAISE EXCEPTION 'Date plata invalide' USING ERRCODE='PZ003';
  END IF;
  IF p_metoda_plata IS NOT NULL
     AND (pg_catalog.btrim(p_metoda_plata)='' OR pg_catalog.char_length(p_metoda_plata)>20) THEN
    RAISE EXCEPTION 'Metoda de plata invalida' USING ERRCODE='PZ003';
  END IF;
  IF p_referinta IS NOT NULL AND pg_catalog.btrim(p_referinta)='' THEN
    RAISE EXCEPTION 'Referinta plata invalida' USING ERRCODE='PZ003';
  END IF;

  SELECT i.stare INTO v_stare_inscriere
  FROM public.inscrieri i
  WHERE i.id_inscriere=p_id_inscriere
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Inscriere inexistenta' USING ERRCODE='PZ002';
  END IF;
  SELECT p.* INTO v_existenta
  FROM public.plati p
  WHERE p.cheie_idempotenta=p_cheie_idempotenta;
  IF FOUND THEN
    IF v_existenta.tip<>'plata'
       OR v_existenta.id_inscriere IS DISTINCT FROM p_id_inscriere
       OR v_existenta.id_plata_initiala IS NOT NULL
       OR v_existenta.suma IS DISTINCT FROM p_suma
       OR v_existenta.metoda_plata IS DISTINCT FROM p_metoda_plata
       OR v_existenta.referinta IS DISTINCT FROM p_referinta THEN
      RAISE EXCEPTION 'Cheia de idempotenta apartine altei cereri'
        USING ERRCODE='PZ003';
    END IF;
    RETURN v_existenta.id_plata;
  END IF;

  IF v_stare_inscriere='anulata' THEN
    RAISE EXCEPTION 'Nu se inregistreaza plati noi pe o inscriere anulata'
      USING ERRCODE='PZ003';
  END IF;

  INSERT INTO public.plati(
    id_inscriere,id_utilizator_inregistrare,id_plata_initiala,
    tip,suma,stare,metoda_plata,referinta,cheie_idempotenta
  ) VALUES (
    p_id_inscriere,v_actor,NULL,
    'plata',p_suma,'in_asteptare',p_metoda_plata,p_referinta,p_cheie_idempotenta
  )
  ON CONFLICT (cheie_idempotenta)
    WHERE (cheie_idempotenta IS NOT NULL)
  DO NOTHING
  RETURNING id_plata INTO v_id_plata;

  IF v_id_plata IS NOT NULL THEN
    RETURN v_id_plata;
  END IF;

  SELECT p.* INTO v_existenta
  FROM public.plati p
  WHERE p.cheie_idempotenta=p_cheie_idempotenta;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Conflict de idempotenta neasteptat' USING ERRCODE='PZ003';
  END IF;
  IF v_existenta.tip<>'plata'
     OR v_existenta.id_inscriere IS DISTINCT FROM p_id_inscriere
     OR v_existenta.id_plata_initiala IS NOT NULL
     OR v_existenta.suma IS DISTINCT FROM p_suma
     OR v_existenta.metoda_plata IS DISTINCT FROM p_metoda_plata
     OR v_existenta.referinta IS DISTINCT FROM p_referinta THEN
    RAISE EXCEPTION 'Cheia de idempotenta apartine altei cereri'
      USING ERRCODE='PZ003';
  END IF;
  RETURN v_existenta.id_plata;
END;
$$;
COMMENT ON FUNCTION operatii.inregistreaza_plata(uuid,numeric,varchar,text,uuid)
  IS 'AUTOSTART VANCEA Etapa 3.4C2 migrarea 007: functie privata inregistreaza_plata';
REVOKE EXECUTE ON FUNCTION operatii.inregistreaza_plata(uuid,numeric,varchar,text,uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION operatii.inregistreaza_plata(uuid,numeric,varchar,text,uuid)
  TO authenticated;

CREATE FUNCTION public.inregistreaza_plata(
  p_id_inscriere uuid,
  p_suma numeric,
  p_metoda_plata varchar,
  p_referinta text,
  p_cheie_idempotenta uuid
) RETURNS uuid
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = '' AS $$
  SELECT operatii.inregistreaza_plata(
    p_id_inscriere,p_suma,p_metoda_plata,p_referinta,p_cheie_idempotenta
  )
$$;
COMMENT ON FUNCTION public.inregistreaza_plata(uuid,numeric,varchar,text,uuid)
  IS 'AUTOSTART VANCEA Etapa 3.4C2 migrarea 007: wrapper RPC inregistreaza_plata';
REVOKE EXECUTE ON FUNCTION public.inregistreaza_plata(uuid,numeric,varchar,text,uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.inregistreaza_plata(uuid,numeric,varchar,text,uuid)
  TO authenticated;

CREATE FUNCTION operatii.confirma_plata(
  p_id_plata uuid
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor uuid;
  v_rol varchar(20);
  v_id_inscriere uuid;
  v_stare_inscriere varchar(12);
  v_plata public.plati%ROWTYPE;
BEGIN
  v_actor := auth.uid();
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;
  SELECT u.rol INTO v_rol
  FROM public.utilizatori u
  WHERE u.id_utilizator=v_actor AND u.activ IS TRUE
  FOR SHARE;
  IF NOT FOUND OR (v_rol IN ('administrator','secretariat')) IS NOT TRUE THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;

  SELECT p.id_inscriere INTO v_id_inscriere
  FROM public.plati p
  WHERE p.id_plata=p_id_plata;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Plata inexistenta' USING ERRCODE='PZ002';
  END IF;

  SELECT i.stare INTO v_stare_inscriere
  FROM public.inscrieri i
  WHERE i.id_inscriere=v_id_inscriere
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Inscriere inexistenta' USING ERRCODE='PZ002';
  END IF;

  SELECT p.* INTO v_plata
  FROM public.plati p
  WHERE p.id_plata=p_id_plata
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Plata inexistenta' USING ERRCODE='PZ002';
  END IF;
  IF v_plata.id_inscriere IS DISTINCT FROM v_id_inscriere
     OR v_plata.tip<>'plata' THEN
    RAISE EXCEPTION 'Plata nu poate fi confirmata' USING ERRCODE='PZ003';
  END IF;
  IF v_plata.stare='confirmata' THEN
    RETURN p_id_plata;
  END IF;
  IF v_plata.stare<>'in_asteptare' THEN
    RAISE EXCEPTION 'Plata nu poate fi confirmata' USING ERRCODE='PZ003';
  END IF;
  IF v_stare_inscriere='anulata' THEN
    RAISE EXCEPTION 'Plata unei inscrieri anulate nu poate fi confirmata'
      USING ERRCODE='PZ003';
  END IF;

  UPDATE public.plati
  SET stare='confirmata'
  WHERE id_plata=p_id_plata;

  INSERT INTO public.jurnal_audit(
    id_actor,operatie,entitate,id_tinta,motiv,valoare_veche,valoare_noua
  ) VALUES (
    v_actor,'confirma_plata','plata',p_id_plata,'confirmare_plata',
    'in_asteptare','confirmata'
  );

  RETURN p_id_plata;
END;
$$;
COMMENT ON FUNCTION operatii.confirma_plata(uuid)
  IS 'AUTOSTART VANCEA Etapa 3.4C2 migrarea 007: functie privata confirma_plata';
REVOKE EXECUTE ON FUNCTION operatii.confirma_plata(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION operatii.confirma_plata(uuid) TO authenticated;

CREATE FUNCTION public.confirma_plata(p_id_plata uuid) RETURNS uuid
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = '' AS $$
  SELECT operatii.confirma_plata(p_id_plata)
$$;
COMMENT ON FUNCTION public.confirma_plata(uuid)
  IS 'AUTOSTART VANCEA Etapa 3.4C2 migrarea 007: wrapper RPC confirma_plata';
REVOKE EXECUTE ON FUNCTION public.confirma_plata(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.confirma_plata(uuid) TO authenticated;

CREATE FUNCTION operatii.anuleaza_plata_in_asteptare(
  p_id_plata uuid,
  p_motiv varchar
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor uuid;
  v_rol varchar(20);
  v_id_inscriere uuid;
  v_plata public.plati%ROWTYPE;
BEGIN
  v_actor := auth.uid();
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;
  SELECT u.rol INTO v_rol
  FROM public.utilizatori u
  WHERE u.id_utilizator=v_actor AND u.activ IS TRUE
  FOR SHARE;
  IF NOT FOUND OR (v_rol IN ('administrator','secretariat')) IS NOT TRUE THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;

  IF p_motiv IS NULL
     OR pg_catalog.char_length(p_motiv)>80
     OR p_motiv !~ '^[a-z0-9_]+$' THEN
    RAISE EXCEPTION 'Motiv invalid' USING ERRCODE='PZ003';
  END IF;

  SELECT p.id_inscriere INTO v_id_inscriere
  FROM public.plati p
  WHERE p.id_plata=p_id_plata;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Plata inexistenta' USING ERRCODE='PZ002';
  END IF;

  PERFORM 1
  FROM public.inscrieri i
  WHERE i.id_inscriere=v_id_inscriere
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Inscriere inexistenta' USING ERRCODE='PZ002';
  END IF;

  SELECT p.* INTO v_plata
  FROM public.plati p
  WHERE p.id_plata=p_id_plata
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Plata inexistenta' USING ERRCODE='PZ002';
  END IF;
  IF v_plata.id_inscriere IS DISTINCT FROM v_id_inscriere
     OR v_plata.tip<>'plata' THEN
    RAISE EXCEPTION 'Plata nu poate fi anulata' USING ERRCODE='PZ003';
  END IF;
  IF v_plata.stare='anulata' THEN
    IF EXISTS (
      SELECT 1 FROM public.jurnal_audit j
      WHERE j.operatie='anuleaza_plata_in_asteptare'
        AND j.entitate='plata'
        AND j.id_tinta=p_id_plata
        AND j.motiv=p_motiv
    ) THEN
      RETURN p_id_plata;
    END IF;
    RAISE EXCEPTION 'Plata nu poate fi anulata' USING ERRCODE='PZ003';
  END IF;
  IF v_plata.stare<>'in_asteptare' THEN
    RAISE EXCEPTION 'Plata nu poate fi anulata' USING ERRCODE='PZ003';
  END IF;

  UPDATE public.plati
  SET stare='anulata'
  WHERE id_plata=p_id_plata;

  INSERT INTO public.jurnal_audit(
    id_actor,operatie,entitate,id_tinta,motiv,valoare_veche,valoare_noua
  ) VALUES (
    v_actor,'anuleaza_plata_in_asteptare','plata',p_id_plata,p_motiv,
    'in_asteptare','anulata'
  );

  RETURN p_id_plata;
END;
$$;
COMMENT ON FUNCTION operatii.anuleaza_plata_in_asteptare(uuid,varchar)
  IS 'AUTOSTART VANCEA Etapa 3.4C2 migrarea 007: functie privata anuleaza_plata_in_asteptare';
REVOKE EXECUTE ON FUNCTION operatii.anuleaza_plata_in_asteptare(uuid,varchar)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION operatii.anuleaza_plata_in_asteptare(uuid,varchar)
  TO authenticated;

CREATE FUNCTION public.anuleaza_plata_in_asteptare(
  p_id_plata uuid,
  p_motiv varchar
) RETURNS uuid
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = '' AS $$
  SELECT operatii.anuleaza_plata_in_asteptare(p_id_plata,p_motiv)
$$;
COMMENT ON FUNCTION public.anuleaza_plata_in_asteptare(uuid,varchar)
  IS 'AUTOSTART VANCEA Etapa 3.4C2 migrarea 007: wrapper RPC anuleaza_plata_in_asteptare';
REVOKE EXECUTE ON FUNCTION public.anuleaza_plata_in_asteptare(uuid,varchar)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.anuleaza_plata_in_asteptare(uuid,varchar)
  TO authenticated;

CREATE FUNCTION operatii.inregistreaza_rambursare(
  p_id_plata_initiala uuid,
  p_suma numeric,
  p_motiv varchar,
  p_cheie_idempotenta uuid
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor uuid;
  v_rol varchar(20);
  v_id_inscriere uuid;
  v_initiala public.plati%ROWTYPE;
  v_existenta public.plati%ROWTYPE;
  v_id_rambursare uuid;
BEGIN
  v_actor := auth.uid();
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;
  SELECT u.rol INTO v_rol
  FROM public.utilizatori u
  WHERE u.id_utilizator=v_actor AND u.activ IS TRUE
  FOR SHARE;
  IF NOT FOUND OR v_rol<>'administrator' THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;

  IF p_suma IS NULL OR p_suma<=0
     OR p_suma>9999999999.99
     OR p_suma IS DISTINCT FROM pg_catalog.round(p_suma,2)
     OR p_cheie_idempotenta IS NULL THEN
    RAISE EXCEPTION 'Date rambursare invalide' USING ERRCODE='PZ003';
  END IF;
  IF p_motiv IS NULL
     OR pg_catalog.char_length(p_motiv)>80
     OR p_motiv !~ '^[a-z0-9_]+$' THEN
    RAISE EXCEPTION 'Motiv invalid' USING ERRCODE='PZ003';
  END IF;

  SELECT p.id_inscriere INTO v_id_inscriere
  FROM public.plati p
  WHERE p.id_plata=p_id_plata_initiala;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Plata initiala inexistenta' USING ERRCODE='PZ002';
  END IF;

  PERFORM 1
  FROM public.inscrieri i
  WHERE i.id_inscriere=v_id_inscriere
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Inscriere inexistenta' USING ERRCODE='PZ002';
  END IF;

  SELECT p.* INTO v_initiala
  FROM public.plati p
  WHERE p.id_plata=p_id_plata_initiala
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Plata initiala inexistenta' USING ERRCODE='PZ002';
  END IF;
  IF v_initiala.id_inscriere IS DISTINCT FROM v_id_inscriere
     OR v_initiala.tip<>'plata'
     OR v_initiala.stare<>'confirmata' THEN
    RAISE EXCEPTION 'Rambursarea cere o plata initiala confirmata'
      USING ERRCODE='PZ003';
  END IF;
  IF p_suma>v_initiala.suma THEN
    RAISE EXCEPTION 'Rambursarea depaseste plata initiala'
      USING ERRCODE='PZ003';
  END IF;

  SELECT p.* INTO v_existenta
  FROM public.plati p
  WHERE p.cheie_idempotenta=p_cheie_idempotenta;
  IF FOUND THEN
    IF v_existenta.tip<>'rambursare'
       OR v_existenta.id_plata_initiala IS DISTINCT FROM p_id_plata_initiala
       OR v_existenta.id_inscriere IS DISTINCT FROM v_id_inscriere
       OR v_existenta.suma IS DISTINCT FROM p_suma
       OR NOT EXISTS (
         SELECT 1 FROM public.jurnal_audit j
         WHERE j.operatie='inregistreaza_rambursare'
           AND j.entitate='plata'
           AND j.id_tinta=v_existenta.id_plata
           AND j.motiv=p_motiv
       ) THEN
      RAISE EXCEPTION 'Cheia de idempotenta apartine altei cereri'
        USING ERRCODE='PZ003';
    END IF;
    RETURN v_existenta.id_plata;
  END IF;

  INSERT INTO public.plati(
    id_inscriere,id_utilizator_inregistrare,id_plata_initiala,
    tip,suma,stare,metoda_plata,referinta,cheie_idempotenta
  ) VALUES (
    v_id_inscriere,v_actor,p_id_plata_initiala,
    'rambursare',p_suma,'confirmata',NULL,NULL,p_cheie_idempotenta
  )
  ON CONFLICT (cheie_idempotenta)
    WHERE (cheie_idempotenta IS NOT NULL)
  DO NOTHING
  RETURNING id_plata INTO v_id_rambursare;

  IF v_id_rambursare IS NULL THEN
    SELECT p.* INTO v_existenta
    FROM public.plati p
    WHERE p.cheie_idempotenta=p_cheie_idempotenta;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Conflict de idempotenta neasteptat'
        USING ERRCODE='PZ003';
    END IF;
    IF v_existenta.tip<>'rambursare'
       OR v_existenta.id_plata_initiala IS DISTINCT FROM p_id_plata_initiala
       OR v_existenta.id_inscriere IS DISTINCT FROM v_id_inscriere
       OR v_existenta.suma IS DISTINCT FROM p_suma
       OR NOT EXISTS (
         SELECT 1 FROM public.jurnal_audit j
         WHERE j.operatie='inregistreaza_rambursare'
           AND j.entitate='plata'
           AND j.id_tinta=v_existenta.id_plata
           AND j.motiv=p_motiv
       ) THEN
      RAISE EXCEPTION 'Cheia de idempotenta apartine altei cereri'
        USING ERRCODE='PZ003';
    END IF;
    RETURN v_existenta.id_plata;
  END IF;

  INSERT INTO public.jurnal_audit(
    id_actor,operatie,entitate,id_tinta,motiv,valoare_veche,valoare_noua
  ) VALUES (
    v_actor,'inregistreaza_rambursare','plata',v_id_rambursare,p_motiv,
    'plata_confirmata','rambursare_confirmata'
  );

  RETURN v_id_rambursare;
END;
$$;
COMMENT ON FUNCTION operatii.inregistreaza_rambursare(uuid,numeric,varchar,uuid)
  IS 'AUTOSTART VANCEA Etapa 3.4C2 migrarea 007: functie privata inregistreaza_rambursare';
REVOKE EXECUTE ON FUNCTION operatii.inregistreaza_rambursare(uuid,numeric,varchar,uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION operatii.inregistreaza_rambursare(uuid,numeric,varchar,uuid)
  TO authenticated;

CREATE FUNCTION public.inregistreaza_rambursare(
  p_id_plata_initiala uuid,
  p_suma numeric,
  p_motiv varchar,
  p_cheie_idempotenta uuid
) RETURNS uuid
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = '' AS $$
  SELECT operatii.inregistreaza_rambursare(
    p_id_plata_initiala,p_suma,p_motiv,p_cheie_idempotenta
  )
$$;
COMMENT ON FUNCTION public.inregistreaza_rambursare(uuid,numeric,varchar,uuid)
  IS 'AUTOSTART VANCEA Etapa 3.4C2 migrarea 007: wrapper RPC inregistreaza_rambursare';
REVOKE EXECUTE ON FUNCTION public.inregistreaza_rambursare(uuid,numeric,varchar,uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.inregistreaza_rambursare(uuid,numeric,varchar,uuid)
  TO authenticated;

-- =========================================================
-- 3. OPERATII EXAMENE
-- =========================================================

CREATE FUNCTION operatii.inregistreaza_examen(
  p_id_inscriere uuid,
  p_tip_examen varchar,
  p_data_examenului timestamptz
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor uuid;
  v_rol varchar(20);
  v_stare_inscriere varchar(12);
  v_examen_programat public.examene%ROWTYPE;
  v_id_examen uuid;
BEGIN
  v_actor := auth.uid();
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;
  SELECT u.rol INTO v_rol
  FROM public.utilizatori u
  WHERE u.id_utilizator=v_actor AND u.activ IS TRUE
  FOR SHARE;
  IF NOT FOUND OR (v_rol IN ('administrator','secretariat')) IS NOT TRUE THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;

  IF p_tip_examen IS NULL OR p_tip_examen NOT IN ('teoretic','practic')
     OR p_data_examenului IS NULL
     OR p_data_examenului<=pg_catalog.clock_timestamp() THEN
    RAISE EXCEPTION 'Date examen invalide' USING ERRCODE='PZ003';
  END IF;

  SELECT i.stare INTO v_stare_inscriere
  FROM public.inscrieri i
  WHERE i.id_inscriere=p_id_inscriere
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Inscriere inexistenta' USING ERRCODE='PZ002';
  END IF;
  IF v_stare_inscriere='anulata' THEN
    RAISE EXCEPTION 'Examenul nu se programeaza pentru inscriere anulata'
      USING ERRCODE='PZ003';
  END IF;

  SELECT e.* INTO v_examen_programat
  FROM public.examene e
  WHERE e.id_inscriere=p_id_inscriere
    AND e.tip_examen=p_tip_examen
    AND e.stare='programat'
    AND e.data_examenului=p_data_examenului
  ORDER BY e.numar_incercare
  LIMIT 1;
  IF FOUND THEN
    RETURN v_examen_programat.id_examen;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.examene e
    WHERE e.id_inscriere=p_id_inscriere
      AND e.tip_examen=p_tip_examen
      AND e.stare='programat'
  ) THEN
    RAISE EXCEPTION 'Exista deja un examen de acest tip programat'
      USING ERRCODE='PZ003';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.examene e
    WHERE e.id_inscriere=p_id_inscriere
      AND e.tip_examen=p_tip_examen
      AND e.stare='sustinut'
      AND e.rezultat='admis'
  ) THEN
    RAISE EXCEPTION 'Examenul de acest tip este deja promovat'
      USING ERRCODE='PZ003';
  END IF;

  INSERT INTO public.examene(
    id_inscriere,tip_examen,data_examenului,stare
  ) VALUES (
    p_id_inscriere,p_tip_examen,p_data_examenului,'programat'
  )
  RETURNING id_examen INTO v_id_examen;

  INSERT INTO public.jurnal_audit(
    id_actor,operatie,entitate,id_tinta,motiv,valoare_veche,valoare_noua
  ) VALUES (
    v_actor,'inregistreaza_examen','examen',v_id_examen,'programare_examen',
    NULL,'programat'
  );

  RETURN v_id_examen;
END;
$$;
COMMENT ON FUNCTION operatii.inregistreaza_examen(uuid,varchar,timestamptz)
  IS 'AUTOSTART VANCEA Etapa 3.4C2 migrarea 007: functie privata inregistreaza_examen';
REVOKE EXECUTE ON FUNCTION operatii.inregistreaza_examen(uuid,varchar,timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION operatii.inregistreaza_examen(uuid,varchar,timestamptz)
  TO authenticated;

CREATE FUNCTION public.inregistreaza_examen(
  p_id_inscriere uuid,
  p_tip_examen varchar,
  p_data_examenului timestamptz
) RETURNS uuid
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = '' AS $$
  SELECT operatii.inregistreaza_examen(
    p_id_inscriere,p_tip_examen,p_data_examenului
  )
$$;
COMMENT ON FUNCTION public.inregistreaza_examen(uuid,varchar,timestamptz)
  IS 'AUTOSTART VANCEA Etapa 3.4C2 migrarea 007: wrapper RPC inregistreaza_examen';
REVOKE EXECUTE ON FUNCTION public.inregistreaza_examen(uuid,varchar,timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.inregistreaza_examen(uuid,varchar,timestamptz)
  TO authenticated;

CREATE FUNCTION operatii.inregistreaza_rezultat(
  p_id_examen uuid,
  p_rezultat varchar,
  p_punctaj integer
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor uuid;
  v_rol varchar(20);
  v_id_inscriere uuid;
  v_stare_inscriere varchar(12);
  v_examen public.examene%ROWTYPE;
  v_valoare_noua varchar(100);
BEGIN
  v_actor := auth.uid();
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;
  SELECT u.rol INTO v_rol
  FROM public.utilizatori u
  WHERE u.id_utilizator=v_actor AND u.activ IS TRUE
  FOR SHARE;
  IF NOT FOUND OR (v_rol IN ('administrator','secretariat')) IS NOT TRUE THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;

  IF p_rezultat IS NULL
     OR p_rezultat NOT IN ('admis','respins','neprezentat') THEN
    RAISE EXCEPTION 'Rezultat invalid' USING ERRCODE='PZ003';
  END IF;
  IF p_punctaj IS NOT NULL AND (p_punctaj<0 OR p_punctaj>32767) THEN
    RAISE EXCEPTION 'Punctaj invalid' USING ERRCODE='PZ003';
  END IF;

  SELECT e.id_inscriere INTO v_id_inscriere
  FROM public.examene e
  WHERE e.id_examen=p_id_examen;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Examen inexistent' USING ERRCODE='PZ002';
  END IF;

  SELECT i.stare INTO v_stare_inscriere
  FROM public.inscrieri i
  WHERE i.id_inscriere=v_id_inscriere
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Inscriere inexistenta' USING ERRCODE='PZ002';
  END IF;

  SELECT e.* INTO v_examen
  FROM public.examene e
  WHERE e.id_examen=p_id_examen
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Examen inexistent' USING ERRCODE='PZ002';
  END IF;

  IF v_examen.id_inscriere IS DISTINCT FROM v_id_inscriere THEN
    RAISE EXCEPTION 'Rezultatul nu mai poate fi inregistrat'
      USING ERRCODE='PZ003';
  END IF;
  IF v_examen.tip_examen='practic' AND p_punctaj IS NOT NULL THEN
    RAISE EXCEPTION 'Examenul practic nu foloseste punctaj numeric'
      USING ERRCODE='PZ003';
  END IF;
  IF p_rezultat='neprezentat' AND p_punctaj IS NOT NULL THEN
    RAISE EXCEPTION 'Neprezentarea nu foloseste punctaj'
      USING ERRCODE='PZ003';
  END IF;
  IF v_examen.stare<>'programat' THEN
    IF p_rezultat='neprezentat'
       AND v_examen.stare='neprezentat'
       AND v_examen.rezultat IS NULL
       AND v_examen.punctaj IS NULL
       AND EXISTS (
         SELECT 1 FROM public.jurnal_audit j
         WHERE j.operatie='inregistreaza_rezultat'
           AND j.entitate='examen'
           AND j.id_tinta=p_id_examen
           AND j.motiv='neprezentare_examen'
       ) THEN
      RETURN p_id_examen;
    ELSIF p_rezultat IN ('admis','respins')
       AND v_examen.stare='sustinut'
       AND v_examen.rezultat=p_rezultat
       AND v_examen.punctaj IS NOT DISTINCT FROM p_punctaj::smallint
       AND EXISTS (
         SELECT 1 FROM public.jurnal_audit j
         WHERE j.operatie='inregistreaza_rezultat'
           AND j.entitate='examen'
           AND j.id_tinta=p_id_examen
           AND j.motiv='rezultat_examen'
       ) THEN
      RETURN p_id_examen;
    END IF;
    RAISE EXCEPTION 'Rezultatul nu mai poate fi inregistrat'
      USING ERRCODE='PZ003';
  END IF;
  IF v_stare_inscriere='anulata' THEN
    RAISE EXCEPTION 'Rezultatul nu se inregistreaza pentru inscriere anulata'
      USING ERRCODE='PZ003';
  END IF;
  IF v_examen.data_examenului>pg_catalog.clock_timestamp() THEN
    RAISE EXCEPTION 'Rezultatul nu se inregistreaza inaintea examenului'
      USING ERRCODE='PZ003';
  END IF;

  IF p_rezultat='neprezentat' THEN
    UPDATE public.examene
    SET stare='neprezentat',rezultat=NULL,punctaj=NULL
    WHERE id_examen=p_id_examen;
    v_valoare_noua := 'neprezentat';
  ELSE
    UPDATE public.examene
    SET stare='sustinut',rezultat=p_rezultat,
        punctaj=p_punctaj::smallint
    WHERE id_examen=p_id_examen;
    v_valoare_noua := 'sustinut_'||p_rezultat;
  END IF;

  INSERT INTO public.jurnal_audit(
    id_actor,operatie,entitate,id_tinta,motiv,valoare_veche,valoare_noua
  ) VALUES (
    v_actor,'inregistreaza_rezultat','examen',p_id_examen,
    CASE WHEN p_rezultat='neprezentat'
         THEN 'neprezentare_examen' ELSE 'rezultat_examen' END,
    'programat',v_valoare_noua
  );

  RETURN p_id_examen;
END;
$$;
COMMENT ON FUNCTION operatii.inregistreaza_rezultat(uuid,varchar,integer)
  IS 'AUTOSTART VANCEA Etapa 3.4C2 migrarea 007: functie privata inregistreaza_rezultat';
REVOKE EXECUTE ON FUNCTION operatii.inregistreaza_rezultat(uuid,varchar,integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION operatii.inregistreaza_rezultat(uuid,varchar,integer)
  TO authenticated;

CREATE FUNCTION public.inregistreaza_rezultat(
  p_id_examen uuid,
  p_rezultat varchar,
  p_punctaj integer
) RETURNS uuid
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = '' AS $$
  SELECT operatii.inregistreaza_rezultat(p_id_examen,p_rezultat,p_punctaj)
$$;
COMMENT ON FUNCTION public.inregistreaza_rezultat(uuid,varchar,integer)
  IS 'AUTOSTART VANCEA Etapa 3.4C2 migrarea 007: wrapper RPC inregistreaza_rezultat';
REVOKE EXECUTE ON FUNCTION public.inregistreaza_rezultat(uuid,varchar,integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.inregistreaza_rezultat(uuid,varchar,integer)
  TO authenticated;

CREATE FUNCTION operatii.anuleaza_examen(
  p_id_examen uuid,
  p_motiv varchar
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_actor uuid;
  v_rol varchar(20);
  v_id_inscriere uuid;
  v_examen public.examene%ROWTYPE;
BEGIN
  v_actor := auth.uid();
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;
  SELECT u.rol INTO v_rol
  FROM public.utilizatori u
  WHERE u.id_utilizator=v_actor AND u.activ IS TRUE
  FOR SHARE;
  IF NOT FOUND OR (v_rol IN ('administrator','secretariat')) IS NOT TRUE THEN
    RAISE EXCEPTION 'Operatie neautorizata' USING ERRCODE='PZ001';
  END IF;

  IF p_motiv IS NULL
     OR pg_catalog.char_length(p_motiv)>80
     OR p_motiv !~ '^[a-z0-9_]+$' THEN
    RAISE EXCEPTION 'Motiv invalid' USING ERRCODE='PZ003';
  END IF;

  SELECT e.id_inscriere INTO v_id_inscriere
  FROM public.examene e
  WHERE e.id_examen=p_id_examen;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Examen inexistent' USING ERRCODE='PZ002';
  END IF;

  PERFORM 1
  FROM public.inscrieri i
  WHERE i.id_inscriere=v_id_inscriere
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Inscriere inexistenta' USING ERRCODE='PZ002';
  END IF;

  SELECT e.* INTO v_examen
  FROM public.examene e
  WHERE e.id_examen=p_id_examen
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Examen inexistent' USING ERRCODE='PZ002';
  END IF;
  IF v_examen.id_inscriere IS DISTINCT FROM v_id_inscriere THEN
    RAISE EXCEPTION 'Examenul nu mai poate fi anulat' USING ERRCODE='PZ003';
  END IF;
  IF v_examen.stare='anulat' THEN
    IF EXISTS (
      SELECT 1 FROM public.jurnal_audit j
      WHERE j.operatie='anuleaza_examen'
        AND j.entitate='examen'
        AND j.id_tinta=p_id_examen
        AND j.motiv=p_motiv
    ) THEN
      RETURN p_id_examen;
    END IF;
    RAISE EXCEPTION 'Examenul nu mai poate fi anulat' USING ERRCODE='PZ003';
  END IF;
  IF v_examen.stare<>'programat'
     OR v_examen.data_examenului<=pg_catalog.clock_timestamp() THEN
    RAISE EXCEPTION 'Examenul nu mai poate fi anulat' USING ERRCODE='PZ003';
  END IF;

  UPDATE public.examene
  SET stare='anulat',rezultat=NULL,punctaj=NULL
  WHERE id_examen=p_id_examen;

  INSERT INTO public.jurnal_audit(
    id_actor,operatie,entitate,id_tinta,motiv,valoare_veche,valoare_noua
  ) VALUES (
    v_actor,'anuleaza_examen','examen',p_id_examen,p_motiv,
    'programat','anulat'
  );

  RETURN p_id_examen;
END;
$$;
COMMENT ON FUNCTION operatii.anuleaza_examen(uuid,varchar)
  IS 'AUTOSTART VANCEA Etapa 3.4C2 migrarea 007: functie privata anuleaza_examen';
REVOKE EXECUTE ON FUNCTION operatii.anuleaza_examen(uuid,varchar)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION operatii.anuleaza_examen(uuid,varchar)
  TO authenticated;

CREATE FUNCTION public.anuleaza_examen(
  p_id_examen uuid,
  p_motiv varchar
) RETURNS uuid
LANGUAGE sql VOLATILE SECURITY INVOKER SET search_path = '' AS $$
  SELECT operatii.anuleaza_examen(p_id_examen,p_motiv)
$$;
COMMENT ON FUNCTION public.anuleaza_examen(uuid,varchar)
  IS 'AUTOSTART VANCEA Etapa 3.4C2 migrarea 007: wrapper RPC anuleaza_examen';
REVOKE EXECUTE ON FUNCTION public.anuleaza_examen(uuid,varchar)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.anuleaza_examen(uuid,varchar)
  TO authenticated;

-- =========================================================
-- 4. POSTFLIGHT: orice abatere anuleaza intreaga migrare 007.
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
    RAISE EXCEPTION 'Schema operatii nu contine exact 25 functii dupa 007';
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
    RAISE EXCEPTION 'Operatiile 004-007 sau wrapper-ele lor nu sunt exact 25';
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
      RAISE EXCEPTION 'Functie 007 lipsa: %',v_sig;
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
      RAISE EXCEPTION 'Securitatea functiei 007 nu corespunde: %',v_sig;
    END IF;
    IF NOT pg_catalog.has_function_privilege('authenticated',v_priv,'EXECUTE')
       OR NOT pg_catalog.has_function_privilege('authenticated',v_pub,'EXECUTE')
       OR pg_catalog.has_function_privilege('anon',v_priv,'EXECUTE')
       OR pg_catalog.has_function_privilege('anon',v_pub,'EXECUTE') THEN
      RAISE EXCEPTION 'Granturile functiei 007 nu corespund: %',v_sig;
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
    RAISE EXCEPTION 'O operatie 3.4C3 a aparut prematur';
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
    RAISE EXCEPTION 'Tabelele/RLS au fost afectate de 007';
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
    RAISE EXCEPTION 'Politicile RLS au fost afectate de 007';
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
    RAISE EXCEPTION '007 a acordat privilegii directe nepermise';
  END IF;

  IF pg_catalog.has_column_privilege(
       'authenticated','public.plati','cheie_idempotenta','SELECT')
     OR pg_catalog.has_column_privilege(
       'authenticated','public.cursanti','cnp','SELECT') THEN
    RAISE EXCEPTION '007 a expus o coloana sensibila';
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
    RAISE EXCEPTION '007 a afectat indexul de idempotenta';
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
    RAISE EXCEPTION '007 a afectat protectiile 006';
  END IF;
END;
$postflight$;

COMMIT;
