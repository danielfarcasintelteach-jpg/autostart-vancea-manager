-- AUTOSTART VANCEA Manager
-- Etapa 3.4C1: rollback structural pentru migrarea 006.
-- NEEXECUTAT.
--
-- IMPORTANT:
-- Acest rollback elimina numai infrastructura introdusa de 006.
-- NU foloseste CASCADE.
-- NU elimina operatiile 004-005.
-- NU atinge cele 9 tabele initiale, cu exceptia eliminarii coloanei
-- cheie_idempotenta adaugate de 006 din public.plati.
--
-- Daca jurnalul contine deja evenimente sau exista chei de idempotenta
-- utilizate, rollback-ul REFUZA executia pentru a nu distruge istoric.

BEGIN;

SET LOCAL search_path = '';

DO $preflight$
DECLARE
  v_operatii_3_4c text[] := ARRAY[
    'inregistreaza_plata',
    'confirma_plata',
    'anuleaza_plata_in_asteptare',
    'inregistreaza_rambursare',
    'inregistreaza_examen',
    'inregistreaza_rezultat',
    'anuleaza_examen',
    'creare_profil',
    'schimba_rol_profil',
    'schimba_activ_profil',
    'corecteaza_cnp',
    'consulta_cnp'
  ];
BEGIN
  IF pg_catalog.to_regclass('public.jurnal_audit') IS NULL THEN
    RAISE EXCEPTION
      'Rollback 006 refuzat: public.jurnal_audit lipseste';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_attribute a
    WHERE a.attrelid = 'public.plati'::regclass
      AND a.attname = 'cheie_idempotenta'
      AND a.atttypid = 'uuid'::regtype
      AND a.attnum > 0
      AND NOT a.attisdropped
  ) THEN
    RAISE EXCEPTION
      'Rollback 006 refuzat: coloana cheie_idempotenta lipseste';
  END IF;

  IF pg_catalog.to_regclass(
       'public.uq_plati_cheie_idempotenta'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Rollback 006 refuzat: indexul de idempotenta lipseste';
  END IF;

  IF pg_catalog.to_regprocedure(
       'public.protejeaza_jurnal_audit()'
     ) IS NULL
     OR pg_catalog.to_regprocedure(
       'public.protejeaza_cheie_idempotenta_plata()'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Rollback 006 refuzat: functiile auxiliare lipsesc';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_trigger t
    WHERE t.tgrelid = 'public.jurnal_audit'::regclass
      AND t.tgname = 'protejeaza_jurnal_audit'
      AND NOT t.tgisinternal
  )
  OR NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_trigger t
    WHERE t.tgrelid = 'public.jurnal_audit'::regclass
      AND t.tgname = 'protejeaza_jurnal_audit_truncate'
      AND NOT t.tgisinternal
  )
  OR NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_trigger t
    WHERE t.tgrelid = 'public.plati'::regclass
      AND t.tgname = 'protejeaza_cheie_idempotenta_plata'
      AND NOT t.tgisinternal
  ) THEN
    RAISE EXCEPTION
      'Rollback 006 refuzat: trigger-ele 006 nu corespund';
  END IF;

  -- 3.4C2/C3 nu trebuie sa fie deja aplicate.
  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname IN ('public', 'operatii')
      AND p.proname = ANY(v_operatii_3_4c)
  ) THEN
    RAISE EXCEPTION
      'Rollback 006 refuzat: exista deja operatii 3.4C dependente';
  END IF;

  -- Protectie impotriva pierderii jurnalului.
  IF EXISTS (
    SELECT 1
    FROM public.jurnal_audit
  ) THEN
    RAISE EXCEPTION
      'Rollback 006 refuzat: jurnal_audit contine deja evenimente';
  END IF;

  -- Protectie impotriva pierderii cheilor deja folosite.
  IF EXISTS (
    SELECT 1
    FROM public.plati
    WHERE cheie_idempotenta IS NOT NULL
  ) THEN
    RAISE EXCEPTION
      'Rollback 006 refuzat: exista chei de idempotenta utilizate';
  END IF;
END;
$preflight$;


-- =========================================================
-- 1. ELIMINARE PROTECTII IDEMPOTENTA
-- =========================================================

DROP TRIGGER protejeaza_cheie_idempotenta_plata
  ON public.plati;

DROP FUNCTION public.protejeaza_cheie_idempotenta_plata()
  RESTRICT;

DROP INDEX public.uq_plati_cheie_idempotenta;

ALTER TABLE public.plati
  DROP COLUMN cheie_idempotenta;


-- =========================================================
-- 2. ELIMINARE JURNAL AUDIT
-- =========================================================

DROP TRIGGER protejeaza_jurnal_audit_truncate
  ON public.jurnal_audit;

DROP TRIGGER protejeaza_jurnal_audit
  ON public.jurnal_audit;

DROP FUNCTION public.protejeaza_jurnal_audit()
  RESTRICT;

DROP TABLE public.jurnal_audit
  RESTRICT;


-- =========================================================
-- 3. POSTFLIGHT
-- =========================================================

DO $postflight$
DECLARE
  v_tabele_001 text[] := ARRAY[
    'persoane',
    'utilizatori',
    'cursanti',
    'instructori',
    'vehicule',
    'inscrieri',
    'programari',
    'plati',
    'examene'
  ];

  v_operatii_existente text[] := ARRAY[
    'creare_programare',
    'creare_cursant',
    'modifica_persoana',
    'schimba_stare_cursant',
    'creare_instructor',
    'modifica_instructor',
    'schimba_stare_instructor',
    'creare_vehicul',
    'modifica_vehicul',
    'schimba_stare_vehicul',
    'creare_inscriere',
    'modifica_inscriere',
    'finalizeaza_inscriere',
    'anuleaza_inscriere',
    'realoca_instructor',
    'anuleaza_programare',
    'marcheaza_programare',
    'modifica_cursant'
  ];
BEGIN
  IF pg_catalog.to_regclass('public.jurnal_audit') IS NOT NULL THEN
    RAISE EXCEPTION
      'Postflight rollback 006: jurnal_audit exista inca';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_attribute a
    WHERE a.attrelid = 'public.plati'::regclass
      AND a.attname = 'cheie_idempotenta'
      AND a.attnum > 0
      AND NOT a.attisdropped
  ) THEN
    RAISE EXCEPTION
      'Postflight rollback 006: coloana cheie_idempotenta exista inca';
  END IF;

  IF pg_catalog.to_regclass(
       'public.uq_plati_cheie_idempotenta'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Postflight rollback 006: indexul de idempotenta exista inca';
  END IF;

  IF pg_catalog.to_regprocedure(
       'public.protejeaza_jurnal_audit()'
     ) IS NOT NULL
     OR pg_catalog.to_regprocedure(
       'public.protejeaza_cheie_idempotenta_plata()'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Postflight rollback 006: functiile auxiliare exista inca';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = ANY(v_tabele_001)
      AND c.relkind = 'r'
      AND c.relrowsecurity
      AND NOT c.relforcerowsecurity
      AND c.relowner = current_user::regrole
  ) <> 9 THEN
    RAISE EXCEPTION
      'Postflight rollback 006: cele 9 tabele/RLS nu corespund';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'operatii'
      AND p.proname = ANY(v_operatii_existente)
  ) <> 18
  OR (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc p
    WHERE p.pronamespace = 'operatii'::regnamespace
  ) <> 18 THEN
    RAISE EXCEPTION
      'Postflight rollback 006: operatiile private 004-005 au fost afectate';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = ANY(v_operatii_existente)
  ) <> 18 THEN
    RAISE EXCEPTION
      'Postflight rollback 006: wrapperii 004-005 au fost afectati';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_policy p
    JOIN pg_catalog.pg_class c
      ON c.oid = p.polrelid
    JOIN pg_catalog.pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = ANY(v_tabele_001)
  ) <> 10 THEN
    RAISE EXCEPTION
      'Postflight rollback 006: politicile 002-003 au fost afectate';
  END IF;

  IF pg_catalog.has_column_privilege(
       'authenticated',
       'public.cursanti',
       'cnp',
       'SELECT'
     ) THEN
    RAISE EXCEPTION
      'Postflight rollback 006: CNP a devenit citibil direct';
  END IF;
END;
$postflight$;

COMMIT;