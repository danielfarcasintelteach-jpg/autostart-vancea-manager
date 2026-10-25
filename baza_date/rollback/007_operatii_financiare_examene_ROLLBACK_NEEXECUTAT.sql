-- AUTOSTART VANCEA Manager
-- Etapa 3.4C2: rollback structural pentru migrarea 007. NEEXECUTAT.
-- NU se foloseste pentru testare. Nu sterge plati, examene sau jurnal de audit.
-- Refuza executia daca 3.4C3 este deja instalata.

BEGIN;
SET LOCAL search_path = '';

-- =========================================================
-- 1. PREFLIGHT: 007 trebuie sa fie instalata exact.
-- =========================================================
DO $preflight$
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
    RAISE EXCEPTION 'Rollback 007 refuzat: exista deja operatii 3.4C3';
  END IF;

  IF NOT EXISTS (
      SELECT 1 FROM pg_catalog.pg_namespace
      WHERE nspname='operatii' AND nspowner=current_user::regrole
    )
    OR (
      SELECT count(*) FROM pg_catalog.pg_proc
      WHERE pronamespace='operatii'::regnamespace
    ) <> 25 THEN
    RAISE EXCEPTION 'Rollback 007 refuzat: schema operatii nu este starea 3.4C2';
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
    RAISE EXCEPTION 'Rollback 007 refuzat: operatiile 004-007 nu sunt exact cele asteptate';
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
      RAISE EXCEPTION 'Rollback 007 refuzat: functie lipsa: %',v_sig;
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
      RAISE EXCEPTION 'Rollback 007 refuzat: securitate neasteptata: %',v_sig;
    END IF;
  END LOOP;

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
    RAISE EXCEPTION 'Rollback 007 refuzat: tabelele/RLS nu corespund';
  END IF;

  IF pg_catalog.to_regclass('public.uq_plati_cheie_idempotenta') IS NULL
     OR pg_catalog.to_regprocedure('public.protejeaza_jurnal_audit()') IS NULL
     OR pg_catalog.to_regprocedure('public.protejeaza_cheie_idempotenta_plata()') IS NULL THEN
    RAISE EXCEPTION 'Rollback 007 refuzat: infrastructura 006 nu corespunde';
  END IF;
END;
$preflight$;

-- =========================================================
-- 2. ELIMINARE NUMAI RPC-URI 007. DATELE RAMAN INTACTE.
-- =========================================================
DROP FUNCTION public.anuleaza_examen(uuid,varchar) RESTRICT;
DROP FUNCTION public.inregistreaza_rezultat(uuid,varchar,integer) RESTRICT;
DROP FUNCTION public.inregistreaza_examen(uuid,varchar,timestamp with time zone) RESTRICT;
DROP FUNCTION public.inregistreaza_rambursare(uuid,numeric,varchar,uuid) RESTRICT;
DROP FUNCTION public.anuleaza_plata_in_asteptare(uuid,varchar) RESTRICT;
DROP FUNCTION public.confirma_plata(uuid) RESTRICT;
DROP FUNCTION public.inregistreaza_plata(uuid,numeric,varchar,text,uuid) RESTRICT;

DROP FUNCTION operatii.anuleaza_examen(uuid,varchar) RESTRICT;
DROP FUNCTION operatii.inregistreaza_rezultat(uuid,varchar,integer) RESTRICT;
DROP FUNCTION operatii.inregistreaza_examen(uuid,varchar,timestamp with time zone) RESTRICT;
DROP FUNCTION operatii.inregistreaza_rambursare(uuid,numeric,varchar,uuid) RESTRICT;
DROP FUNCTION operatii.anuleaza_plata_in_asteptare(uuid,varchar) RESTRICT;
DROP FUNCTION operatii.confirma_plata(uuid) RESTRICT;
DROP FUNCTION operatii.inregistreaza_plata(uuid,numeric,varchar,text,uuid) RESTRICT;

-- =========================================================
-- 3. POSTFLIGHT: revenire exacta la starea 006/3.4C1.
-- =========================================================
DO $postflight$
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
  ) <> 18 THEN
    RAISE EXCEPTION 'Rollback 007: operatii nu a revenit la exact 18 functii';
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
    RAISE EXCEPTION 'Rollback 007: operatiile 004-005 au fost afectate';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname IN ('public','operatii')
      AND p.proname=ANY(v_operatii_007)
  ) THEN
    RAISE EXCEPTION 'Rollback 007: a ramas o functie 007';
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
    RAISE EXCEPTION 'Rollback 007: tabelele/RLS au fost afectate';
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
    RAISE EXCEPTION 'Rollback 007: politicile RLS au fost afectate';
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
  )
  OR NOT EXISTS (
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
    RAISE EXCEPTION 'Rollback 007: idempotenta 006 a fost afectata';
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
    RAISE EXCEPTION 'Rollback 007: protectiile 006 au fost afectate';
  END IF;

  IF pg_catalog.has_column_privilege(
       'authenticated','public.plati','cheie_idempotenta','SELECT')
     OR pg_catalog.has_column_privilege(
       'authenticated','public.cursanti','cnp','SELECT') THEN
    RAISE EXCEPTION 'Rollback 007: o coloana sensibila este expusa';
  END IF;
END;
$postflight$;

COMMIT;
