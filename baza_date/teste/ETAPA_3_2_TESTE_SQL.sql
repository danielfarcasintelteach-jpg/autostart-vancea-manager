-- Etapa 3.2: rulare controlata DOAR dupa aplicarea migrarii 002, in mediul de dezvoltare.
-- SQL Editor trebuie sa ruleze cu un rol administrativ care poate SET ROLE authenticated.
-- Este necesar profilul fictiv, activ, admin.demo@example.com din Etapa 2B.
-- Nu se afiseaza date personale si nu se creeaza conturi Auth. Modificarea temporara
-- a profilului demonstrativ este anulata prin ROLLBACK. Daca o verificare esueaza,
-- executati ROLLBACK in aceeasi sesiune inainte de orice alta operatiune.

BEGIN;

DO $catalog$
DECLARE
  v_tabela record;
  v_coloana record;
  v_politica record;
BEGIN
  -- USAGE poate lipsi chiar daca exista granturile pe coloane. Nu il acordam aici.
  IF NOT has_schema_privilege('authenticated', 'public', 'USAGE') THEN
    RAISE EXCEPTION 'Diferenta de configuratie: authenticated nu are USAGE pe schema public. Opriti testarea si revizuiti strategia.';
  END IF;

  IF (SELECT count(*) FROM pg_class AS c
      JOIN pg_namespace AS n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relrowsecurity
        AND c.relname = ANY (ARRAY['persoane','utilizatori','cursanti','instructori',
                                   'vehicule','inscrieri','programari','plati','examene'])) <> 9 THEN
    RAISE EXCEPTION 'RLS trebuie sa fie activ pe toate cele 9 tabele';
  END IF;

  IF (SELECT count(*) FROM pg_policy AS p
      JOIN pg_class AS c ON c.oid = p.polrelid
      JOIN pg_namespace AS n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relname = ANY (ARRAY['persoane','utilizatori','cursanti','instructori',
                                   'vehicule','inscrieri','programari','plati','examene'])) <> 1 THEN
    RAISE EXCEPTION 'Trebuie sa existe exact politica Etapei 3.2 pe cele 9 tabele';
  END IF;

  SELECT p.polname, p.polcmd, p.polpermissive, p.polroles,
         lower(pg_get_expr(p.polqual, p.polrelid)) AS conditie
    INTO v_politica
    FROM pg_policy AS p
   WHERE p.polrelid = 'public.utilizatori'::regclass;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Politica utilizatori_citire_profil_activ lipseste';
  END IF;

  IF v_politica.polname IS DISTINCT FROM 'utilizatori_citire_profil_activ'
     OR v_politica.polcmd IS DISTINCT FROM 'r'
     OR v_politica.polpermissive IS DISTINCT FROM TRUE
     OR v_politica.polroles IS DISTINCT FROM ARRAY['authenticated'::regrole::oid]
     OR position('id_utilizator' IN v_politica.conditie) = 0
     OR position('uid()' IN v_politica.conditie) = 0
     OR position('activ' IN v_politica.conditie) = 0
     OR position('true' IN v_politica.conditie) = 0 THEN
    RAISE EXCEPTION 'Politica SELECT nu corespunde profilului propriu activ';
  END IF;

  IF has_table_privilege('authenticated', 'public.utilizatori', 'SELECT') THEN
    RAISE EXCEPTION 'authenticated are SELECT la nivel de tabela pe utilizatori';
  END IF;

  FOR v_coloana IN
    SELECT a.attname
      FROM pg_attribute AS a
     WHERE a.attrelid = 'public.utilizatori'::regclass
       AND a.attnum > 0 AND NOT a.attisdropped
  LOOP
    IF has_column_privilege('authenticated', 'public.utilizatori', v_coloana.attname, 'SELECT')
       IS DISTINCT FROM (v_coloana.attname = ANY (ARRAY['id_utilizator','rol','activ'])) THEN
      RAISE EXCEPTION 'Grant SELECT neasteptat pe utilizatori.%', v_coloana.attname;
    END IF;
  END LOOP;

  IF has_column_privilege('authenticated', 'public.utilizatori', 'id_persoana', 'SELECT')
     OR has_column_privilege('authenticated', 'public.cursanti', 'cnp', 'SELECT') THEN
    RAISE EXCEPTION 'id_persoana sau cursanti.cnp este citibil de authenticated';
  END IF;

  FOR v_tabela IN
    SELECT c.oid, c.relname
      FROM pg_class AS c
      JOIN pg_namespace AS n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public' AND c.relkind = 'r'
       AND c.relname = ANY (ARRAY['persoane','utilizatori','cursanti','instructori',
                                  'vehicule','inscrieri','programari','plati','examene'])
  LOOP
    IF has_table_privilege('authenticated', v_tabela.oid, 'INSERT')
       OR has_any_column_privilege('authenticated', v_tabela.oid, 'INSERT')
       OR has_table_privilege('authenticated', v_tabela.oid, 'UPDATE')
       OR has_any_column_privilege('authenticated', v_tabela.oid, 'UPDATE')
       OR has_table_privilege('authenticated', v_tabela.oid, 'DELETE') THEN
      RAISE EXCEPTION 'authenticated poate modifica tabela %', v_tabela.relname;
    END IF;

    IF has_table_privilege('anon', v_tabela.oid, 'SELECT')
       OR has_any_column_privilege('anon', v_tabela.oid, 'SELECT')
       OR has_table_privilege('anon', v_tabela.oid, 'INSERT')
       OR has_any_column_privilege('anon', v_tabela.oid, 'INSERT')
       OR has_table_privilege('anon', v_tabela.oid, 'UPDATE')
       OR has_any_column_privilege('anon', v_tabela.oid, 'UPDATE')
       OR has_table_privilege('anon', v_tabela.oid, 'DELETE') THEN
      RAISE EXCEPTION 'anon are drepturi neasteptate pe tabela %', v_tabela.relname;
    END IF;

    IF v_tabela.relname <> 'utilizatori'
       AND (has_table_privilege('authenticated', v_tabela.oid, 'SELECT')
            OR has_any_column_privilege('authenticated', v_tabela.oid, 'SELECT')) THEN
      RAISE EXCEPTION 'authenticated poate citi tabela % in afara Etapei 3.2', v_tabela.relname;
    END IF;
  END LOOP;

  RAISE NOTICE 'Catalog verificat: USAGE public, 9 RLS, o politica, 3 coloane SELECT, 8 tabele blocate, fara mutatii.';
END;
$catalog$;

-- Actorul este exclusiv contul fictiv de test. Nu folosim date reale sau ID furnizat de browser.
DO $actor$
DECLARE
  v_id uuid;
  v_activ boolean;
BEGIN
  SELECT u.id_utilizator, u.activ INTO v_id, v_activ
    FROM public.utilizatori AS u
    JOIN auth.users AS a ON a.id = u.id_utilizator
   WHERE a.email = 'admin.demo@example.com';

  IF v_id IS NULL OR v_activ IS DISTINCT FROM TRUE THEN
    RAISE EXCEPTION 'Lipseste profilul fictiv activ admin.demo@example.com';
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_id::text, true);
END;
$actor$;

SET LOCAL ROLE authenticated;

DO $rls_activ$
DECLARE
  v_id uuid;
  v_rol text;
  v_activ boolean;
  v_tabela text;
BEGIN
  SELECT id_utilizator, rol, activ INTO v_id, v_rol, v_activ
    FROM public.utilizatori;

  IF NOT FOUND OR v_id IS DISTINCT FROM auth.uid() OR v_activ IS DISTINCT FROM TRUE
     OR v_rol NOT IN ('administrator','secretariat','instructor','cursant') THEN
    RAISE EXCEPTION 'Profilul propriu activ nu este singurul profil vizibil';
  END IF;

  IF (SELECT count(id_utilizator) FROM public.utilizatori) <> 1
     OR (SELECT count(id_utilizator) FROM public.utilizatori
         WHERE id_utilizator <> auth.uid()) <> 0 THEN
    RAISE EXCEPTION 'RLS permite citirea unui alt profil';
  END IF;

  BEGIN
    EXECUTE 'SELECT id_persoana FROM public.utilizatori LIMIT 1';
    RAISE EXCEPTION 'id_persoana este citibil';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    EXECUTE 'SELECT * FROM public.utilizatori LIMIT 1';
    RAISE EXCEPTION 'SELECT * este permis pe utilizatori';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    EXECUTE 'SELECT cnp FROM public.cursanti LIMIT 1';
    RAISE EXCEPTION 'cursanti.cnp este citibil';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  FOREACH v_tabela IN ARRAY ARRAY['persoane','cursanti','instructori','vehicule',
                                  'inscrieri','programari','plati','examene'] LOOP
    BEGIN
      EXECUTE format('SELECT 1 FROM public.%I LIMIT 1', v_tabela);
      RAISE EXCEPTION 'SELECT permis pe tabela %', v_tabela;
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
  END LOOP;

  -- WHERE FALSE asigura ca nici o mutatie nu atinge date, chiar daca un grant e gresit.
  BEGIN
    EXECUTE 'INSERT INTO public.utilizatori (id_utilizator) SELECT auth.uid() WHERE FALSE';
    RAISE EXCEPTION 'INSERT permis pe utilizatori';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    EXECUTE 'UPDATE public.utilizatori SET activ = activ WHERE FALSE';
    RAISE EXCEPTION 'UPDATE permis pe utilizatori';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    EXECUTE 'DELETE FROM public.utilizatori WHERE FALSE';
    RAISE EXCEPTION 'DELETE permis pe utilizatori';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  RAISE NOTICE 'RLS activ: numai profilul propriu si numai cele 3 coloane permise.';
END;
$rls_activ$;

RESET ROLE;

-- Dezactivare temporara a contului demonstrativ in aceeasi tranzactie.
UPDATE public.utilizatori
   SET activ = FALSE
 WHERE id_utilizator = current_setting('request.jwt.claim.sub')::uuid;

SET LOCAL ROLE authenticated;

DO $rls_inactiv$
BEGIN
  IF EXISTS (SELECT id_utilizator FROM public.utilizatori) THEN
    RAISE EXCEPTION 'Profilul inactiv este vizibil';
  END IF;
  RAISE NOTICE 'RLS inactiv: profilul propriu nu este vizibil.';
END;
$rls_inactiv$;

RESET ROLE;

-- Identitate fictiva fara profil; nu este introdusa in auth.users.
DO $absent$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', gen_random_uuid()::text, true);
END;
$absent$;

SET LOCAL ROLE authenticated;

DO $rls_absent$
BEGIN
  IF EXISTS (SELECT id_utilizator FROM public.utilizatori) THEN
    RAISE EXCEPTION 'Identitatea fara profil poate citi utilizatori';
  END IF;
  RAISE NOTICE 'RLS absent: niciun profil vizibil.';
END;
$rls_absent$;

RESET ROLE;
ROLLBACK;
