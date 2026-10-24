-- AUTOSTART VANCEA Manager
-- Etapa 3.4C1: infrastructura pentru audit durabil si idempotenta platilor.
-- NU activeaza operatiile financiare, de examen, profil sau CNP.
-- Se aplica o singura data, dupa migrarea 005.
--
-- Obiective:
-- 1. al zecelea tabel: public.jurnal_audit, append-only;
-- 2. cheie UUID de idempotenta pentru public.plati;
-- 3. cheia de idempotenta devine imuabila dupa INSERT;
-- 4. nici anon, nici authenticated nu primesc acces direct la jurnal;
-- 5. cele 12 operatii 3.4C raman inexistente dupa aceasta migrare.

BEGIN;

SET LOCAL search_path = '';

DO $preflight$
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
  IF pg_catalog.to_regrole('authenticated') IS NULL
     OR pg_catalog.to_regrole('anon') IS NULL
     OR pg_catalog.to_regprocedure('auth.uid()') IS NULL THEN
    RAISE EXCEPTION
      'Rolurile API sau auth.uid() nu corespund starii asteptate';
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
      'Cele 9 tabele 001, proprietarul sau RLS nu corespund';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_namespace
    WHERE nspname = 'intern'
      AND nspowner = current_user::regrole
  )
  OR NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_namespace
    WHERE nspname = 'operatii'
      AND nspowner = current_user::regrole
  ) THEN
    RAISE EXCEPTION
      'Schemele intern/operatii nu corespund starii 003-005';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc p
    WHERE p.pronamespace = 'intern'::regnamespace
  ) <> 10 THEN
    RAISE EXCEPTION
      'Schema intern nu contine exact cele 10 functii asteptate';
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
      'Operatiile private 004-005 nu corespund';
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
      'Wrapperii publici 004-005 nu corespund';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname IN ('public', 'operatii')
      AND p.proname = ANY(v_operatii_3_4c)
  ) THEN
    RAISE EXCEPTION
      'Exista deja una dintre operatiile rezervate Etapei 3.4C';
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
      'Politicile RLS 002-003 nu mai sunt exact 10';
  END IF;

  IF pg_catalog.to_regclass('public.jurnal_audit') IS NOT NULL THEN
    RAISE EXCEPTION
      'public.jurnal_audit exista deja';
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
      'public.plati.cheie_idempotenta exista deja';
  END IF;

  IF pg_catalog.to_regclass(
       'public.uq_plati_cheie_idempotenta'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Indexul uq_plati_cheie_idempotenta exista deja';
  END IF;

  IF pg_catalog.to_regprocedure(
       'public.protejeaza_cheie_idempotenta_plata()'
     ) IS NOT NULL
     OR pg_catalog.to_regprocedure(
       'public.protejeaza_jurnal_audit()'
     ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Functiile auxiliare 006 exista deja';
  END IF;

  IF pg_catalog.has_table_privilege(
       'authenticated',
       'public.plati',
       'INSERT'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated',
       'public.plati',
       'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated',
       'public.plati',
       'DELETE'
     ) THEN
    RAISE EXCEPTION
      'authenticated are DML direct neasteptat pe plati';
  END IF;

  IF pg_catalog.has_column_privilege(
       'authenticated',
       'public.cursanti',
       'cnp',
       'SELECT'
     ) THEN
    RAISE EXCEPTION
      'CNP a devenit citibil direct';
  END IF;
END;
$preflight$;


-- =========================================================
-- 1. JURNAL DURABIL
-- =========================================================

CREATE TABLE public.jurnal_audit (
  id_eveniment uuid
    PRIMARY KEY
    DEFAULT pg_catalog.gen_random_uuid(),

  id_actor uuid NOT NULL
    REFERENCES public.utilizatori(id_utilizator)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT,

  operatie varchar(60) NOT NULL,
  entitate varchar(40) NOT NULL,
  id_tinta uuid NOT NULL,
  motiv varchar(80) NOT NULL,

  valoare_veche varchar(100),
  valoare_noua varchar(100),

  data_eveniment timestamptz NOT NULL
    DEFAULT pg_catalog.clock_timestamp(),

  CONSTRAINT ck_jurnal_audit_operatie
    CHECK (
      operatie ~ '^[a-z][a-z0-9_]{1,59}$'
    ),

  CONSTRAINT ck_jurnal_audit_entitate
    CHECK (
      entitate ~ '^[a-z][a-z0-9_]{1,39}$'
    ),

  CONSTRAINT ck_jurnal_audit_motiv
    CHECK (
      motiv ~ '^[a-z][a-z0-9_]{1,79}$'
    ),

  CONSTRAINT ck_jurnal_audit_valoare_veche
    CHECK (
      valoare_veche IS NULL
      OR pg_catalog.btrim(valoare_veche) <> ''
    ),

  CONSTRAINT ck_jurnal_audit_valoare_noua
    CHECK (
      valoare_noua IS NULL
      OR pg_catalog.btrim(valoare_noua) <> ''
    )
);

COMMENT ON TABLE public.jurnal_audit IS
  'AUTOSTART VANCEA Etapa 3.4C1: jurnal audit append-only; nu stocheaza CNP, parole sau tokenuri';

COMMENT ON COLUMN public.jurnal_audit.id_actor IS
  'Utilizatorul aplicatiei identificat din auth.uid() de operatia privata';

COMMENT ON COLUMN public.jurnal_audit.operatie IS
  'Codul operatiei auditate';

COMMENT ON COLUMN public.jurnal_audit.entitate IS
  'Tipul entitatii tinta';

COMMENT ON COLUMN public.jurnal_audit.id_tinta IS
  'UUID-ul entitatii tinta; nu reprezinta valoarea sensibila';

COMMENT ON COLUMN public.jurnal_audit.motiv IS
  'Cod operational al motivului; nu text liber cu date sensibile';

COMMENT ON COLUMN public.jurnal_audit.valoare_veche IS
  'Valoare minima nesensibila anterioara, daca este necesara';

COMMENT ON COLUMN public.jurnal_audit.valoare_noua IS
  'Valoare minima nesensibila ulterioara, daca este necesara';

ALTER TABLE public.jurnal_audit
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL
  ON TABLE public.jurnal_audit
  FROM PUBLIC, anon, authenticated;

CREATE INDEX idx_jurnal_audit_actor_data
  ON public.jurnal_audit (
    id_actor,
    data_eveniment DESC
  );

CREATE INDEX idx_jurnal_audit_tinta_data
  ON public.jurnal_audit (
    entitate,
    id_tinta,
    data_eveniment DESC
  );


-- Jurnalul este append-only inclusiv pentru viitoarele functii
-- SECURITY DEFINER. Corectarea istoricului nu face parte din CRUD-ul
-- operational al aplicatiei.

CREATE FUNCTION public.protejeaza_jurnal_audit()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  RAISE EXCEPTION
    'Jurnalul de audit este append-only'
    USING ERRCODE = '23514';

  RETURN NULL;
END;
$$;

REVOKE EXECUTE
  ON FUNCTION public.protejeaza_jurnal_audit()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER protejeaza_jurnal_audit
BEFORE UPDATE OR DELETE
ON public.jurnal_audit
FOR EACH ROW
EXECUTE FUNCTION public.protejeaza_jurnal_audit();

CREATE TRIGGER protejeaza_jurnal_audit_truncate
BEFORE TRUNCATE
ON public.jurnal_audit
FOR EACH STATEMENT
EXECUTE FUNCTION public.protejeaza_jurnal_audit();


-- =========================================================
-- 2. IDEMPOTENTA PLATILOR
-- =========================================================

ALTER TABLE public.plati
  ADD COLUMN cheie_idempotenta uuid;

COMMENT ON COLUMN public.plati.cheie_idempotenta IS
  'Cheie persistenta furnizata de viitorul RPC financiar; NULL numai pentru randuri istorice sau create anterior activarii 3.4C2';

CREATE UNIQUE INDEX uq_plati_cheie_idempotenta
  ON public.plati (cheie_idempotenta)
  WHERE cheie_idempotenta IS NOT NULL;


-- Cheia unei plati nu poate fi schimbata dupa crearea randului.

CREATE FUNCTION public.protejeaza_cheie_idempotenta_plata()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.cheie_idempotenta
       IS DISTINCT FROM OLD.cheie_idempotenta THEN
    RAISE EXCEPTION
      'Cheia de idempotenta a platii nu se modifica'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE
  ON FUNCTION public.protejeaza_cheie_idempotenta_plata()
  FROM PUBLIC, anon, authenticated;

CREATE TRIGGER protejeaza_cheie_idempotenta_plata
BEFORE UPDATE OF cheie_idempotenta
ON public.plati
FOR EACH ROW
EXECUTE FUNCTION public.protejeaza_cheie_idempotenta_plata();


-- =========================================================
-- 3. POSTFLIGHT
-- =========================================================

DO $postflight$
DECLARE
  v_tabele text[] := ARRAY[
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
  ];

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
  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = ANY(v_tabele)
      AND c.relkind = 'r'
      AND c.relrowsecurity
      AND NOT c.relforcerowsecurity
      AND c.relowner = current_user::regrole
  ) <> 10 THEN
    RAISE EXCEPTION
      'Postflight: cele 10 tabele/RLS/proprietarul nu corespund';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_policy p
    JOIN pg_catalog.pg_class c
      ON c.oid = p.polrelid
    JOIN pg_catalog.pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = ANY(v_tabele)
  ) <> 10 THEN
    RAISE EXCEPTION
      'Postflight: politicile SELECT 002-003 au fost modificate';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_policy p
    WHERE p.polrelid = 'public.jurnal_audit'::regclass
  ) THEN
    RAISE EXCEPTION
      'Postflight: jurnal_audit nu trebuie sa aiba politica API directa';
  END IF;

  IF pg_catalog.has_table_privilege(
       'authenticated',
       'public.jurnal_audit',
       'SELECT'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated',
       'public.jurnal_audit',
       'INSERT'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated',
       'public.jurnal_audit',
       'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated',
       'public.jurnal_audit',
       'DELETE'
     )
     OR pg_catalog.has_table_privilege(
       'anon',
       'public.jurnal_audit',
       'SELECT'
     )
     OR pg_catalog.has_table_privilege(
       'anon',
       'public.jurnal_audit',
       'INSERT'
     )
     OR pg_catalog.has_table_privilege(
       'anon',
       'public.jurnal_audit',
       'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'anon',
       'public.jurnal_audit',
       'DELETE'
     ) THEN
    RAISE EXCEPTION
      'Postflight: jurnal_audit are privilegii API directe';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_attribute a
    WHERE a.attrelid = 'public.plati'::regclass
      AND a.attname = 'cheie_idempotenta'
      AND a.atttypid = 'uuid'::regtype
      AND NOT a.attnotnull
      AND a.attnum > 0
      AND NOT a.attisdropped
  ) THEN
    RAISE EXCEPTION
      'Postflight: coloana cheie_idempotenta nu corespunde';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_index i
    JOIN pg_catalog.pg_attribute a
      ON a.attrelid = i.indrelid
     AND a.attname = 'cheie_idempotenta'
     AND a.attnum = i.indkey[0]
    WHERE i.indexrelid =
          'public.uq_plati_cheie_idempotenta'::regclass
      AND i.indrelid = 'public.plati'::regclass
      AND i.indisunique
      AND i.indisvalid
      AND i.indisready
      AND i.indnkeyatts = 1
      AND i.indpred IS NOT NULL
      AND pg_catalog.pg_get_expr(
            i.indpred,
            i.indrelid
          ) = '(cheie_idempotenta IS NOT NULL)'
  ) THEN
    RAISE EXCEPTION
      'Postflight: indexul unic partial de idempotenta nu corespunde';
  END IF;

  IF pg_catalog.to_regprocedure(
       'public.protejeaza_jurnal_audit()'
     ) IS NULL
     OR pg_catalog.to_regprocedure(
       'public.protejeaza_cheie_idempotenta_plata()'
     ) IS NULL THEN
    RAISE EXCEPTION
      'Postflight: functiile auxiliare 006 lipsesc';
  END IF;

  IF pg_catalog.has_function_privilege(
       'authenticated',
       'public.protejeaza_jurnal_audit()',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'authenticated',
       'public.protejeaza_cheie_idempotenta_plata()',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'anon',
       'public.protejeaza_jurnal_audit()',
       'EXECUTE'
     )
     OR pg_catalog.has_function_privilege(
       'anon',
       'public.protejeaza_cheie_idempotenta_plata()',
       'EXECUTE'
     ) THEN
    RAISE EXCEPTION
      'Postflight: functiile trigger 006 sunt apelabile direct din API';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_trigger t
    WHERE t.tgrelid = 'public.jurnal_audit'::regclass
      AND t.tgname = 'protejeaza_jurnal_audit'
      AND NOT t.tgisinternal
      AND t.tgenabled = 'O'
  )
  OR NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_trigger t
    WHERE t.tgrelid = 'public.jurnal_audit'::regclass
      AND t.tgname = 'protejeaza_jurnal_audit_truncate'
      AND NOT t.tgisinternal
      AND t.tgenabled = 'O'
  )
  OR NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_trigger t
    WHERE t.tgrelid = 'public.plati'::regclass
      AND t.tgname = 'protejeaza_cheie_idempotenta_plata'
      AND NOT t.tgisinternal
      AND t.tgenabled = 'O'
  ) THEN
    RAISE EXCEPTION
      'Postflight: trigger-ele 006 nu corespund';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname IN ('public', 'operatii')
      AND p.proname = ANY(v_operatii_3_4c)
  ) THEN
    RAISE EXCEPTION
      'Postflight: o operatie 3.4C a fost activata prematur';
  END IF;

  IF pg_catalog.has_table_privilege(
       'authenticated',
       'public.plati',
       'INSERT'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated',
       'public.plati',
       'UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated',
       'public.plati',
       'DELETE'
     ) THEN
    RAISE EXCEPTION
      'Postflight: authenticated a primit DML direct pe plati';
  END IF;

  IF pg_catalog.has_column_privilege(
       'authenticated',
       'public.cursanti',
       'cnp',
       'SELECT'
     ) THEN
    RAISE EXCEPTION
      'Postflight: CNP a devenit citibil direct';
  END IF;

  IF pg_catalog.has_column_privilege(
       'authenticated',
       'public.plati',
       'cheie_idempotenta',
       'SELECT'
     ) THEN
    RAISE EXCEPTION
      'Postflight: cheia de idempotenta a devenit citibila direct';
  END IF;
END;
$postflight$;

COMMIT;