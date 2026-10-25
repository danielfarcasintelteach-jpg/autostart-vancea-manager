-- AUTOSTART VANCEA Manager
-- Etapa 3.4C3: rollback structural pentru migrarea 008. NEEXECUTAT.
-- NU se foloseste pentru testare.
-- Refuza executia daca operatiile 008 au fost deja folosite si auditate.

BEGIN;
SET LOCAL search_path = '';

DO $preflight$
DECLARE
  v_sig text;
  v_priv oid;
  v_pub oid;
  v_operatii_anterioare text[] := ARRAY[
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
  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc
    WHERE pronamespace='operatii'::regnamespace
  ) <> 30 THEN
    RAISE EXCEPTION 'Rollback 008 refuzat: schema operatii nu este starea 3.4C3';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='operatii'
      AND p.proname=ANY(v_operatii_anterioare||v_operatii_008)
  ) <> 30
  OR (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public'
      AND p.proname=ANY(v_operatii_anterioare||v_operatii_008)
  ) <> 30 THEN
    RAISE EXCEPTION 'Rollback 008 refuzat: operatiile 004-008 nu sunt exact cele asteptate';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.jurnal_audit j
    WHERE j.operatie=ANY(v_operatii_008)
  ) THEN
    RAISE EXCEPTION
      'Rollback 008 refuzat: exista evenimente 3.4C3 in jurnalul de audit';
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
      RAISE EXCEPTION 'Rollback 008 refuzat: functie lipsa: %',v_sig;
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
      RAISE EXCEPTION 'Rollback 008 refuzat: securitate neasteptata: %',v_sig;
    END IF;
  END LOOP;

  v_priv := pg_catalog.to_regprocedure(
    'operatii.consulta_cnp(uuid,varchar)'
  );
  v_pub := pg_catalog.to_regprocedure(
    'public.consulta_cnp(uuid,varchar)'
  );

  IF v_priv IS NULL OR v_pub IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM pg_catalog.pg_proc p
       WHERE p.oid=v_priv
         AND p.prorettype='character varying'::regtype
         AND p.prosecdef
         AND p.provolatile='v'
         AND p.proconfig @> ARRAY['search_path=""']
     )
     OR NOT EXISTS (
       SELECT 1 FROM pg_catalog.pg_proc p
       WHERE p.oid=v_pub
         AND p.prorettype='character varying'::regtype
         AND NOT p.prosecdef
         AND p.provolatile='v'
         AND p.proconfig @> ARRAY['search_path=""']
     ) THEN
    RAISE EXCEPTION 'Rollback 008 refuzat: consulta_cnp nu corespunde';
  END IF;

  IF pg_catalog.has_column_privilege(
       'authenticated','public.cursanti','cnp','SELECT'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated','public.utilizatori','INSERT'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated','public.utilizatori','UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated','public.utilizatori','DELETE'
     ) THEN
    RAISE EXCEPTION 'Rollback 008 refuzat: protectiile directe nu corespund';
  END IF;
END;
$preflight$;

DROP FUNCTION public.consulta_cnp(uuid,varchar) RESTRICT;
DROP FUNCTION public.corecteaza_cnp(uuid,varchar,varchar) RESTRICT;
DROP FUNCTION public.schimba_activ_profil(uuid,boolean,varchar) RESTRICT;
DROP FUNCTION public.schimba_rol_profil(uuid,varchar,varchar) RESTRICT;
DROP FUNCTION public.creare_profil(uuid,uuid,varchar,varchar) RESTRICT;

DROP FUNCTION operatii.consulta_cnp(uuid,varchar) RESTRICT;
DROP FUNCTION operatii.corecteaza_cnp(uuid,varchar,varchar) RESTRICT;
DROP FUNCTION operatii.schimba_activ_profil(uuid,boolean,varchar) RESTRICT;
DROP FUNCTION operatii.schimba_rol_profil(uuid,varchar,varchar) RESTRICT;
DROP FUNCTION operatii.creare_profil(uuid,uuid,varchar,varchar) RESTRICT;

DO $postflight$
DECLARE
  v_operatii_anterioare text[] := ARRAY[
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
  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc
    WHERE pronamespace='operatii'::regnamespace
  ) <> 25 THEN
    RAISE EXCEPTION 'Rollback 008 incomplet: operatii nu a revenit la 25';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='operatii'
      AND p.proname=ANY(v_operatii_anterioare)
  ) <> 25
  OR (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public'
      AND p.proname=ANY(v_operatii_anterioare)
  ) <> 25 THEN
    RAISE EXCEPTION 'Rollback 008 incomplet: operatiile anterioare nu corespund';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname IN ('public','operatii')
      AND p.proname=ANY(v_operatii_008)
  ) THEN
    RAISE EXCEPTION 'Rollback 008 incomplet: o functie 008 a ramas';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM pg_catalog.pg_policy p
    JOIN pg_catalog.pg_class c ON c.oid=p.polrelid
    JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public'
      AND c.relname=ANY(ARRAY[
        'persoane','utilizatori','cursanti','instructori','vehicule',
        'inscrieri','programari','plati','examene','jurnal_audit'
      ])
  ) <> 10 THEN
    RAISE EXCEPTION 'Rollback 008 a afectat politicile RLS';
  END IF;

  IF pg_catalog.has_column_privilege(
       'authenticated','public.cursanti','cnp','SELECT'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated','public.utilizatori','INSERT'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated','public.utilizatori','UPDATE'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated','public.utilizatori','DELETE'
     ) THEN
    RAISE EXCEPTION 'Rollback 008 a afectat protectiile directe';
  END IF;
END;
$postflight$;

COMMIT;
