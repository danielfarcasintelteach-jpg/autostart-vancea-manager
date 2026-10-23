-- Etapa 3.3. De aplicat numai dupa preflight-ul manual din ETAPA_3_3_TESTE_SQL.sql.
-- Verificati in Supabase API ca intern NU este in exposed schemas.
-- Rularea necesita proprietarul celor noua tabele; nu rulati cu service_role.
BEGIN;
SET LOCAL search_path = '';

DO $preflight$
DECLARE
  v_nume text;
  v_tabela record;
  v_coloana record;
  v_politica record;
  v_conditie text;
  v_asteptate text[] := ARRAY['persoane','utilizatori','cursanti','instructori',
    'vehicule','inscrieri','programari','plati','examene'];
BEGIN
  IF to_regrole('authenticated') IS NULL OR to_regrole('anon') IS NULL
     OR NOT has_schema_privilege('authenticated', 'public', 'USAGE')
     OR NOT has_database_privilege(current_user, current_database(), 'CREATE') THEN
    RAISE EXCEPTION 'Rolurile API, USAGE pe public sau CREATE pe baza nu corespund';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_namespace WHERE nspname = 'intern') THEN
    RAISE EXCEPTION 'Schema intern exista deja';
  END IF;
  IF (SELECT count(*) FROM pg_catalog.pg_class c
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = ANY(v_asteptate)
        AND c.relkind = 'r' AND c.relrowsecurity AND NOT c.relforcerowsecurity
        AND c.relowner = current_user::regrole) <> 9 THEN
    RAISE EXCEPTION 'Cele 9 tabele, RLS, FORCE RLS sau proprietarul nu corespund';
  END IF;
  IF (SELECT count(*) FROM pg_catalog.pg_policy p
      JOIN pg_catalog.pg_class c ON c.oid = p.polrelid
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = ANY(v_asteptate)) <> 1 THEN
    RAISE EXCEPTION 'Sunt asteptate exact politica Etapei 3.2 si nicio alta politica';
  END IF;
  SELECT p.polname, p.polcmd, p.polpermissive, p.polroles,
         pg_catalog.pg_get_expr(p.polqual, p.polrelid) AS conditie,
         p.polwithcheck IS NULL AS fara_check
    INTO v_politica
    FROM pg_catalog.pg_policy p
   WHERE p.polrelid = 'public.utilizatori'::regclass;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Politica Etapei 3.2 lipseste';
  END IF;
  v_conditie := pg_catalog.regexp_replace(v_politica.conditie, '[[:space:]]+', ' ', 'g');
  IF v_politica.polname <> 'utilizatori_citire_profil_activ'
     OR v_politica.polcmd <> 'r' OR NOT v_politica.polpermissive
     OR v_politica.polroles <> ARRAY['authenticated'::regrole::oid]
     OR NOT v_politica.fara_check
     OR v_conditie NOT IN (
       '((id_utilizator = ( SELECT auth.uid() AS uid)) AND (activ IS TRUE))',
       '((id_utilizator = ( SELECT auth.uid())) AND (activ IS TRUE))'
     ) THEN
    RAISE EXCEPTION 'Politica Etapei 3.2 difera: %', v_conditie;
  END IF;
  FOREACH v_nume IN ARRAY v_asteptate LOOP
    SELECT c.oid, c.relname INTO v_tabela
      FROM pg_catalog.pg_class c
     WHERE c.oid = pg_catalog.format('public.%I', v_nume)::regclass;
    IF has_table_privilege('anon', v_tabela.oid, 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
       OR has_any_column_privilege('anon', v_tabela.oid, 'SELECT, INSERT, UPDATE, REFERENCES')
       OR has_table_privilege('authenticated', v_tabela.oid,
                             'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER') THEN
      RAISE EXCEPTION 'Privilegiu neasteptat la nivel de tabela: %', v_nume;
    END IF;
    FOR v_coloana IN
      SELECT a.attname FROM pg_catalog.pg_attribute a
       WHERE a.attrelid = v_tabela.oid AND a.attnum > 0 AND NOT a.attisdropped
    LOOP
      IF has_column_privilege('anon', v_tabela.oid, v_coloana.attname,
                              'SELECT, INSERT, UPDATE, REFERENCES')
         OR has_column_privilege('authenticated', v_tabela.oid, v_coloana.attname,
                                 'INSERT, UPDATE, REFERENCES')
         OR has_column_privilege('authenticated', v_tabela.oid, v_coloana.attname, 'SELECT')
            IS DISTINCT FROM (v_nume = 'utilizatori'
              AND v_coloana.attname = ANY(ARRAY['id_utilizator','rol','activ'])) THEN
        RAISE EXCEPTION 'Privilegiu de coloana neasteptat: %.%', v_nume, v_coloana.attname;
      END IF;
    END LOOP;
  END LOOP;
  -- intern lipseste deja; verificarea explicita face contractul semnaturilor vizibil.
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc p
      JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'intern' AND p.proname = ANY(ARRAY[
        'rol_curent','id_persoana_curenta','id_cursant_curent',
        'id_instructor_curent','cursant_relevant','instructor_relevant',
        'persoana_relevanta','vehicul_relevant','inscriere_a_cursantului',
        'inscriere_a_instructorului'])) THEN
    RAISE EXCEPTION 'Un helper al Etapei 3.3 exista deja';
  END IF;
END;
$preflight$;

CREATE SCHEMA intern;
REVOKE ALL ON SCHEMA intern FROM PUBLIC;
REVOKE ALL ON SCHEMA intern FROM anon, authenticated;
GRANT USAGE ON SCHEMA intern TO authenticated;

CREATE FUNCTION intern.rol_curent() RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT u.rol::text FROM public.utilizatori u
  WHERE u.id_utilizator = auth.uid() AND u.activ IS TRUE
$$;
REVOKE EXECUTE ON FUNCTION intern.rol_curent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION intern.rol_curent() TO authenticated;

CREATE FUNCTION intern.id_persoana_curenta() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT u.id_persoana FROM public.utilizatori u
  WHERE u.id_utilizator = auth.uid() AND u.activ IS TRUE
$$;
REVOKE EXECUTE ON FUNCTION intern.id_persoana_curenta() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION intern.id_persoana_curenta() TO authenticated;

CREATE FUNCTION intern.id_cursant_curent() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT c.id_cursant FROM public.utilizatori u
  JOIN public.cursanti c ON c.id_persoana = u.id_persoana
  WHERE u.id_utilizator = auth.uid() AND u.activ IS TRUE AND u.rol = 'cursant'
$$;
REVOKE EXECUTE ON FUNCTION intern.id_cursant_curent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION intern.id_cursant_curent() TO authenticated;

CREATE FUNCTION intern.id_instructor_curent() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT i.id_instructor FROM public.utilizatori u
  JOIN public.instructori i ON i.id_persoana = u.id_persoana
  WHERE u.id_utilizator = auth.uid() AND u.activ IS TRUE AND u.rol = 'instructor'
$$;
REVOKE EXECUTE ON FUNCTION intern.id_instructor_curent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION intern.id_instructor_curent() TO authenticated;

CREATE FUNCTION intern.cursant_relevant(p_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT intern.rol_curent() = 'instructor' AND (
    EXISTS (SELECT 1 FROM public.inscrieri i
      WHERE i.id_cursant = p_id AND i.id_instructor = intern.id_instructor_curent()
        AND i.stare = 'activa')
    OR EXISTS (SELECT 1 FROM public.programari p
      JOIN public.inscrieri i ON i.id_inscriere = p.id_inscriere
      WHERE i.id_cursant = p_id AND p.id_instructor = intern.id_instructor_curent()
        AND p.stare IN ('finalizata','absent'))
  )
$$;
REVOKE EXECUTE ON FUNCTION intern.cursant_relevant(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION intern.cursant_relevant(uuid) TO authenticated;

CREATE FUNCTION intern.instructor_relevant(p_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT intern.rol_curent() = 'cursant' AND EXISTS (
    SELECT 1 FROM public.inscrieri i
    WHERE i.id_cursant = intern.id_cursant_curent()
      AND (i.id_instructor = p_id OR EXISTS (
        SELECT 1 FROM public.programari p
        WHERE p.id_inscriere = i.id_inscriere AND p.id_instructor = p_id))
  )
$$;
REVOKE EXECUTE ON FUNCTION intern.instructor_relevant(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION intern.instructor_relevant(uuid) TO authenticated;

CREATE FUNCTION intern.persoana_relevanta(p_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT p_id = intern.id_persoana_curenta()
    OR (intern.rol_curent() = 'instructor' AND EXISTS (
      SELECT 1 FROM public.cursanti c
      WHERE c.id_persoana = p_id AND intern.cursant_relevant(c.id_cursant)))
    OR (intern.rol_curent() = 'cursant' AND EXISTS (
      SELECT 1 FROM public.instructori i
      WHERE i.id_persoana = p_id AND intern.instructor_relevant(i.id_instructor)))
$$;
REVOKE EXECUTE ON FUNCTION intern.persoana_relevanta(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION intern.persoana_relevanta(uuid) TO authenticated;

CREATE FUNCTION intern.vehicul_relevant(p_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT (intern.rol_curent() = 'instructor' AND EXISTS (
    SELECT 1 FROM public.programari p
    WHERE p.id_vehicul = p_id AND p.id_instructor = intern.id_instructor_curent()))
    OR (intern.rol_curent() = 'cursant' AND EXISTS (
      SELECT 1 FROM public.programari p
      JOIN public.inscrieri i ON i.id_inscriere = p.id_inscriere
      WHERE p.id_vehicul = p_id AND i.id_cursant = intern.id_cursant_curent()))
$$;
REVOKE EXECUTE ON FUNCTION intern.vehicul_relevant(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION intern.vehicul_relevant(uuid) TO authenticated;

CREATE FUNCTION intern.inscriere_a_cursantului(p_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT intern.rol_curent() = 'cursant' AND EXISTS (
    SELECT 1 FROM public.inscrieri i
    WHERE i.id_inscriere = p_id AND i.id_cursant = intern.id_cursant_curent())
$$;
REVOKE EXECUTE ON FUNCTION intern.inscriere_a_cursantului(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION intern.inscriere_a_cursantului(uuid) TO authenticated;

CREATE FUNCTION intern.inscriere_a_instructorului(p_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT intern.rol_curent() = 'instructor' AND EXISTS (
    SELECT 1 FROM public.inscrieri i
    WHERE i.id_inscriere = p_id AND i.id_instructor = intern.id_instructor_curent())
$$;
REVOKE EXECUTE ON FUNCTION intern.inscriere_a_instructorului(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION intern.inscriere_a_instructorului(uuid) TO authenticated;

-- Proprietarul functiilor trebuie sa fie acelasi cu al tabelelor: ocoleste RLS
-- doar in interiorul helperilor, fara a acorda SELECT direct pe coloane sensibile.
DO $owner$
BEGIN
  IF (SELECT count(*) FROM pg_catalog.pg_proc p
      JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'intern' AND p.proowner = current_user::regrole
        AND p.prosecdef AND p.provolatile = 's' AND p.proconfig @> ARRAY['search_path=""']) <> 10 THEN
    RAISE EXCEPTION 'Proprietarul sau securizarea helperilor nu corespunde';
  END IF;
END;
$owner$;

CREATE POLICY utilizatori_citire_administrator ON public.utilizatori
AS PERMISSIVE FOR SELECT TO authenticated
USING ((SELECT intern.rol_curent()) = 'administrator');
CREATE POLICY persoane_citire_roluri ON public.persoane
AS PERMISSIVE FOR SELECT TO authenticated
USING ((SELECT intern.rol_curent()) IN ('administrator','secretariat')
  OR intern.persoana_relevanta(id_persoana));
CREATE POLICY cursanti_citire_roluri ON public.cursanti
AS PERMISSIVE FOR SELECT TO authenticated
USING ((SELECT intern.rol_curent()) IN ('administrator','secretariat')
  OR id_cursant = (SELECT intern.id_cursant_curent())
  OR intern.cursant_relevant(id_cursant));
CREATE POLICY instructori_citire_roluri ON public.instructori
AS PERMISSIVE FOR SELECT TO authenticated
USING ((SELECT intern.rol_curent()) IN ('administrator','secretariat')
  OR id_instructor = (SELECT intern.id_instructor_curent())
  OR intern.instructor_relevant(id_instructor));
CREATE POLICY vehicule_citire_roluri ON public.vehicule
AS PERMISSIVE FOR SELECT TO authenticated
USING ((SELECT intern.rol_curent()) IN ('administrator','secretariat')
  OR intern.vehicul_relevant(id_vehicul));
CREATE POLICY inscrieri_citire_roluri ON public.inscrieri
AS PERMISSIVE FOR SELECT TO authenticated
USING ((SELECT intern.rol_curent()) IN ('administrator','secretariat')
  OR id_instructor = (SELECT intern.id_instructor_curent())
  OR id_cursant = (SELECT intern.id_cursant_curent()));
CREATE POLICY programari_citire_roluri ON public.programari
AS PERMISSIVE FOR SELECT TO authenticated
USING ((SELECT intern.rol_curent()) IN ('administrator','secretariat')
  OR id_instructor = (SELECT intern.id_instructor_curent())
  OR intern.inscriere_a_cursantului(id_inscriere));
CREATE POLICY plati_citire_roluri ON public.plati
AS PERMISSIVE FOR SELECT TO authenticated
USING ((SELECT intern.rol_curent()) IN ('administrator','secretariat')
  OR intern.inscriere_a_cursantului(id_inscriere));
CREATE POLICY examene_citire_roluri ON public.examene
AS PERMISSIVE FOR SELECT TO authenticated
USING ((SELECT intern.rol_curent()) IN ('administrator','secretariat')
  OR intern.inscriere_a_instructorului(id_inscriere)
  OR intern.inscriere_a_cursantului(id_inscriere));

GRANT SELECT (id_persoana,nume,prenume) ON TABLE public.persoane TO authenticated;
GRANT SELECT (id_cursant,id_persoana,stare) ON TABLE public.cursanti TO authenticated;
GRANT SELECT (id_instructor,id_persoana,stare) ON TABLE public.instructori TO authenticated;
GRANT SELECT (id_vehicul,numar_inmatriculare,marca,model,stare) ON TABLE public.vehicule TO authenticated;
GRANT SELECT (id_inscriere,id_cursant,id_instructor,categorie,data_inscrierii,stare,data_finalizarii)
  ON TABLE public.inscrieri TO authenticated;
GRANT SELECT (id_programare,id_inscriere,id_instructor,id_vehicul,inceput,sfarsit,stare)
  ON TABLE public.programari TO authenticated;
GRANT SELECT (id_plata,id_inscriere,tip,suma,stare,data_platii)
  ON TABLE public.plati TO authenticated;
GRANT SELECT (id_examen,id_inscriere,tip_examen,numar_incercare,data_examenului,stare,rezultat,punctaj)
  ON TABLE public.examene TO authenticated;

COMMIT;
