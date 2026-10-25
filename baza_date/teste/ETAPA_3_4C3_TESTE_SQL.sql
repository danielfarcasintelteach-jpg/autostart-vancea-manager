-- AUTOSTART VANCEA Manager
-- Etapa 3.4C3 - teste pentru migrarea 008.
-- Sectiunea 1 se ruleaza separat dupa aplicarea 008.
-- Sectiunea 2 este functionala si se termina cu ROLLBACK.
-- Rollback-ul structural 008 NU se ruleaza pentru testare.

-- =========================================================
-- 1. TEST CATALOG / SECURITATE
-- =========================================================
DO $catalog$
DECLARE
  v_sig text;
  v_priv oid;
  v_pub oid;
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
    RAISE EXCEPTION 'TEST 3.4C3: operatii nu contine exact 30 functii';
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
    RAISE EXCEPTION
      'TEST 3.4C3: operatiile private/wrapper-ele 004-008 nu sunt exact 30';
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
      RAISE EXCEPTION 'TEST 3.4C3: functie lipsa: %',v_sig;
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
      RAISE EXCEPTION 'TEST 3.4C3: securitate neasteptata: %',v_sig;
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
      RAISE EXCEPTION 'TEST 3.4C3: granturi neasteptate: %',v_sig;
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
         AND p.proowner=current_user::regrole
         AND p.prorettype='character varying'::regtype
         AND p.prosecdef
         AND p.provolatile='v'
         AND p.proconfig @> ARRAY['search_path=""']
     )
     OR NOT EXISTS (
       SELECT 1 FROM pg_catalog.pg_proc p
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
    RAISE EXCEPTION 'TEST 3.4C3: consulta_cnp nu corespunde';
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
    RAISE EXCEPTION 'TEST 3.4C3: politicile RLS nu mai sunt exact 10';
  END IF;

  IF pg_catalog.has_column_privilege(
       'authenticated','public.cursanti','cnp','SELECT'
     )
     OR pg_catalog.has_table_privilege(
       'authenticated','public.cursanti','UPDATE'
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
    RAISE EXCEPTION 'TEST 3.4C3: exista acces direct interzis';
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
    RAISE EXCEPTION 'TEST 3.4C3: jurnal_audit are acces direct';
  END IF;
END;
$catalog$;

SELECT 'ETAPA_3_4C3_CATALOG_OK' AS rezultat;

-- =========================================================
-- 2. TESTE FUNCTIONALE - TOTUL SE ANULEAZA PRIN ROLLBACK
-- =========================================================
BEGIN;

DO $preconditii$
DECLARE
  v_admin uuid;
  v_target uuid;
BEGIN
  SELECT a.id INTO v_admin
  FROM auth.users a
  JOIN public.utilizatori u ON u.id_utilizator=a.id
  WHERE a.email='admin.demo@example.com'
    AND u.rol='administrator'
    AND u.activ IS TRUE;

  IF v_admin IS NULL THEN
    RAISE EXCEPTION
      'TEST 3.4C3: admin.demo@example.com nu este administrator activ';
  END IF;

  SELECT a.id INTO v_target
  FROM auth.users a
  LEFT JOIN public.utilizatori u ON u.id_utilizator=a.id
  WHERE u.id_utilizator IS NULL
    AND a.id<>v_admin
  ORDER BY a.created_at,a.id
  LIMIT 1;

  IF v_target IS NULL THEN
    RAISE EXCEPTION
      'TEST 3.4C3: este necesar un cont Auth existent fara profil public.utilizatori';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.cursanti
    WHERE cnp IN ('2980101999801','2980101999802')
  ) THEN
    RAISE EXCEPTION
      'TEST 3.4C3: CNP-urile fixture sunt deja folosite';
  END IF;
END;
$preconditii$;

SELECT pg_catalog.set_config(
  't34c3.admin',
  (
    SELECT a.id::text
    FROM auth.users a
    JOIN public.utilizatori u ON u.id_utilizator=a.id
    WHERE a.email='admin.demo@example.com'
      AND u.rol='administrator'
      AND u.activ IS TRUE
  ),
  true
);

SELECT pg_catalog.set_config(
  't34c3.target_auth',
  (
    SELECT a.id::text
    FROM auth.users a
    LEFT JOIN public.utilizatori u ON u.id_utilizator=a.id
    WHERE u.id_utilizator IS NULL
      AND a.id<>pg_catalog.current_setting('t34c3.admin')::uuid
    ORDER BY a.created_at,a.id
    LIMIT 1
  ),
  true
);

WITH p AS (
  INSERT INTO public.persoane(nume,prenume)
  VALUES ('TEST34C3','Profil')
  RETURNING id_persoana
)
SELECT pg_catalog.set_config(
  't34c3.persoana',
  (SELECT id_persoana::text FROM p),
  true
);

SELECT pg_catalog.set_config(
  'request.jwt.claim.sub',
  pg_catalog.current_setting('t34c3.admin'),
  true
);

SET LOCAL ROLE authenticated;

SELECT public.creare_profil(
  pg_catalog.current_setting('t34c3.target_auth')::uuid,
  pg_catalog.current_setting('t34c3.persoana')::uuid,
  'secretariat'::varchar,
  'test_creare_profil'::varchar
);

DO $profil_creat$
BEGIN
  BEGIN
    PERFORM public.creare_profil(
      pg_catalog.current_setting('t34c3.target_auth')::uuid,
      pg_catalog.current_setting('t34c3.persoana')::uuid,
      'secretariat'::varchar,
      'test_profil_duplicat'::varchar
    );
    RAISE EXCEPTION 'TEST 3.4C3: profilul duplicat a fost acceptat';
  EXCEPTION
    WHEN SQLSTATE 'PZ003' THEN NULL;
  END;

  BEGIN
    PERFORM public.creare_profil(
      '00000000-0000-0000-0000-000000000081'::uuid,
      pg_catalog.current_setting('t34c3.persoana')::uuid,
      'secretariat'::varchar,
      'test_auth_inexistent'::varchar
    );
    RAISE EXCEPTION 'TEST 3.4C3: contul Auth inexistent a fost acceptat';
  EXCEPTION
    WHEN SQLSTATE 'PZ002' THEN NULL;
  END;

  BEGIN
    PERFORM public.schimba_rol_profil(
      pg_catalog.current_setting('t34c3.target_auth')::uuid,
      'cursant'::varchar,
      'test_legatura_rol'::varchar
    );
    RAISE EXCEPTION 'TEST 3.4C3: rolul cursant fara legatura a fost acceptat';
  EXCEPTION
    WHEN SQLSTATE 'PZ003' THEN NULL;
  END;
END;
$profil_creat$;

SELECT pg_catalog.set_config(
  't34c3.cursant',
  public.creare_cursant(
    'TEST34C3'::varchar,
    'Cursant'::varchar,
    NULL::varchar,
    NULL::varchar,
    NULL::date,
    NULL::text,
    '2980101999801'::varchar,
    'fixture 3.4C3'::text
  )::text,
  true
);

-- Secretariatul creat trebuie sa poata lucra cu CNP, dar nu cu profiluri.
SELECT pg_catalog.set_config(
  'request.jwt.claim.sub',
  pg_catalog.current_setting('t34c3.target_auth'),
  true
);

DO $secretariat_fara_admin$
BEGIN
  BEGIN
    PERFORM public.schimba_rol_profil(
      pg_catalog.current_setting('t34c3.target_auth')::uuid,
      'administrator'::varchar,
      'test_secretariat_interzis'::varchar
    );
    RAISE EXCEPTION 'TEST 3.4C3: secretariatul a administrat profiluri';
  EXCEPTION
    WHEN SQLSTATE 'PZ001' THEN NULL;
  END;

  BEGIN
    PERFORM cnp
    FROM public.cursanti
    WHERE id_cursant=pg_catalog.current_setting('t34c3.cursant')::uuid;
    RAISE EXCEPTION 'TEST 3.4C3: CNP este citibil direct';
  EXCEPTION
    WHEN insufficient_privilege THEN NULL;
  END;
END;
$secretariat_fara_admin$;

DO $consulta_initiala$
DECLARE
  v_cnp varchar;
BEGIN
  v_cnp := public.consulta_cnp(
    pg_catalog.current_setting('t34c3.cursant')::uuid,
    'test_consulta_cnp'::varchar
  );
  IF v_cnp<>'2980101999801' THEN
    RAISE EXCEPTION 'TEST 3.4C3: consulta_cnp nu a returnat CNP-ul asteptat';
  END IF;
END;
$consulta_initiala$;

SELECT public.corecteaza_cnp(
  pg_catalog.current_setting('t34c3.cursant')::uuid,
  '2980101999802'::varchar,
  'test_corecteaza_cnp'::varchar
);

DO $consulta_dupa$
DECLARE
  v_cnp varchar;
BEGIN
  v_cnp := public.consulta_cnp(
    pg_catalog.current_setting('t34c3.cursant')::uuid,
    'test_consulta_cnp_dupa'::varchar
  );
  IF v_cnp<>'2980101999802' THEN
    RAISE EXCEPTION 'TEST 3.4C3: CNP-ul corectat nu este returnat';
  END IF;

  BEGIN
    PERFORM public.corecteaza_cnp(
      pg_catalog.current_setting('t34c3.cursant')::uuid,
      '123'::varchar,
      'test_cnp_invalid'::varchar
    );
    RAISE EXCEPTION 'TEST 3.4C3: CNP invalid acceptat';
  EXCEPTION
    WHEN SQLSTATE 'PZ003' THEN NULL;
  END;

  BEGIN
    PERFORM public.corecteaza_cnp(
      pg_catalog.current_setting('t34c3.cursant')::uuid,
      '2980101999802'::varchar,
      'test_cnp_identic'::varchar
    );
    RAISE EXCEPTION 'TEST 3.4C3: CNP identic acceptat ca o corectie';
  EXCEPTION
    WHEN SQLSTATE 'PZ003' THEN NULL;
  END;
END;
$consulta_dupa$;

-- Revenim la administrator pentru tranzitiile de profil.
SELECT pg_catalog.set_config(
  'request.jwt.claim.sub',
  pg_catalog.current_setting('t34c3.admin'),
  true
);

SELECT public.schimba_rol_profil(
  pg_catalog.current_setting('t34c3.target_auth')::uuid,
  'administrator'::varchar,
  'test_promovare_admin'::varchar
);

SELECT public.schimba_rol_profil(
  pg_catalog.current_setting('t34c3.target_auth')::uuid,
  'secretariat'::varchar,
  'test_revenire_secretariat'::varchar
);

SELECT public.schimba_activ_profil(
  pg_catalog.current_setting('t34c3.target_auth')::uuid,
  FALSE,
  'test_dezactivare_profil'::varchar
);

SELECT public.schimba_activ_profil(
  pg_catalog.current_setting('t34c3.target_auth')::uuid,
  TRUE,
  'test_reactivare_profil'::varchar
);

DO $protectii_admin$
DECLARE
  v_nr_admini integer;
BEGIN
  BEGIN
    PERFORM public.schimba_activ_profil(
      pg_catalog.current_setting('t34c3.admin')::uuid,
      FALSE,
      'test_autodezactivare'::varchar
    );
    RAISE EXCEPTION 'TEST 3.4C3: administratorul s-a dezactivat singur';
  EXCEPTION
    WHEN SQLSTATE 'PZ003' THEN NULL;
  END;

  SELECT pg_catalog.count(*)::integer INTO v_nr_admini
  FROM public.utilizatori
  WHERE rol='administrator' AND activ IS TRUE;

  IF v_nr_admini=1 THEN
    BEGIN
      PERFORM public.schimba_rol_profil(
        pg_catalog.current_setting('t34c3.admin')::uuid,
        'secretariat'::varchar,
        'test_ultim_admin'::varchar
      );
      RAISE EXCEPTION 'TEST 3.4C3: ultimul administrator activ a fost eliminat';
    EXCEPTION
      WHEN SQLSTATE 'PZ003' THEN NULL;
    END;
  END IF;
END;
$protectii_admin$;

RESET ROLE;

DO $verificare_finala$
DECLARE
  v_target uuid := pg_catalog.current_setting('t34c3.target_auth')::uuid;
  v_cursant uuid := pg_catalog.current_setting('t34c3.cursant')::uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.utilizatori u
    WHERE u.id_utilizator=v_target
      AND u.id_persoana=pg_catalog.current_setting('t34c3.persoana')::uuid
      AND u.rol='secretariat'
      AND u.activ IS TRUE
  ) THEN
    RAISE EXCEPTION 'TEST 3.4C3: starea finala a profilului fixture nu corespunde';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM public.jurnal_audit j
    WHERE j.id_tinta=v_target
      AND j.operatie IN (
        'creare_profil','schimba_rol_profil','schimba_activ_profil'
      )
  ) < 5 THEN
    RAISE EXCEPTION 'TEST 3.4C3: auditul profilului este incomplet';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM public.jurnal_audit j
    WHERE j.id_tinta=v_cursant
      AND j.operatie='consulta_cnp'
  ) <> 2 THEN
    RAISE EXCEPTION 'TEST 3.4C3: consultarile CNP nu sunt auditate exact';
  END IF;

  IF (
    SELECT pg_catalog.count(*)
    FROM public.jurnal_audit j
    WHERE j.id_tinta=v_cursant
      AND j.operatie='corecteaza_cnp'
  ) <> 1 THEN
    RAISE EXCEPTION 'TEST 3.4C3: corectarea CNP nu este auditata exact';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.jurnal_audit j
    WHERE j.id_tinta=v_cursant
      AND j.operatie IN ('consulta_cnp','corecteaza_cnp')
      AND (
        COALESCE(j.valoare_veche,'') LIKE '%2980101999801%'
        OR COALESCE(j.valoare_veche,'') LIKE '%2980101999802%'
        OR COALESCE(j.valoare_noua,'') LIKE '%2980101999801%'
        OR COALESCE(j.valoare_noua,'') LIKE '%2980101999802%'
        OR j.motiv LIKE '%2980101999801%'
        OR j.motiv LIKE '%2980101999802%'
      )
  ) THEN
    RAISE EXCEPTION 'TEST 3.4C3: o valoare CNP a ajuns in jurnal';
  END IF;
END;
$verificare_finala$;

ROLLBACK;

SELECT 'ETAPA_3_4C3_FUNCTIONAL_OK' AS rezultat;
