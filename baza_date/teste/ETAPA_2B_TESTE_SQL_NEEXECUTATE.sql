-- AUTOSTART VANCEA Manager - teste SQL propuse, NU au fost executate.
-- Rulati DUPA aplicarea migratiei, intr-o baza de dezvoltare/de test.
-- Cerinta: cel putin un rand in public.utilizatori legat de un cont Auth
-- creat prin administrarea Auth (NU inserati manual in auth.users).
-- Editorul SQL trebuie sa foloseasca un rol administrativ ce vede toate randurile.
-- Se folosesc date fictive; tot ce creeaza testul este anulat la final.

BEGIN;
-- Verificari de catalog posibile imediat, chiar inainte de creare profil Auth.
DO $catalog$
BEGIN
  IF (SELECT COUNT(*) FROM pg_class AS c JOIN pg_namespace AS n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relrowsecurity
        AND c.relname IN ('persoane','utilizatori','cursanti','instructori','vehicule',
                          'inscrieri','programari','plati','examene')) <> 9 THEN
    RAISE EXCEPTION 'RLS nu este activ pe toate cele 9 tabele';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_class AS c JOIN pg_namespace AS n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'r'
      AND c.relname IN ('persoane','utilizatori','cursanti','instructori','vehicule',
                        'inscrieri','programari','plati','examene')
      AND (has_table_privilege('anon', c.oid, 'SELECT')
        OR has_table_privilege('authenticated', c.oid, 'SELECT'))
  ) THEN
    RAISE EXCEPTION 'Exista SELECT la nivel de tabela pentru anon/authenticated';
  END IF;
  IF has_column_privilege('authenticated', 'public.cursanti', 'cnp', 'SELECT') THEN
    RAISE EXCEPTION 'CNP este citibil direct de authenticated';
  END IF;
  RAISE NOTICE 'Catalog: 9 RLS active, SELECT public revocat, CNP neexpus.';
END;
$catalog$;

DO $teste$
DECLARE
  actor uuid;
  persoana_c1 uuid;
  persoana_c2 uuid;
  persoana_dup uuid;
  persoana_i1 uuid;
  persoana_i2 uuid;
  persoana_i3 uuid;
  cursant_1 uuid;
  cursant_2 uuid;
  instructor_1 uuid;
  instructor_2 uuid;
  instructor_3 uuid;
  vehicul_1 uuid;
  vehicul_2 uuid;
  inscriere_veche uuid;
  inscriere_1 uuid;
  inscriere_2 uuid;
  programare_1 uuid;
  sfarsit_calculat timestamptz;
BEGIN
  SELECT id_utilizator INTO actor FROM public.utilizatori LIMIT 1;
  IF actor IS NULL THEN
    RAISE EXCEPTION 'Lipseste profilul demonstrativ utilizatori/Auth pentru id_utilizator_creare';
  END IF;

  INSERT INTO public.persoane(nume, prenume) VALUES ('TestC', 'Unu') RETURNING id_persoana INTO persoana_c1;
  INSERT INTO public.persoane(nume, prenume) VALUES ('TestC', 'Doi') RETURNING id_persoana INTO persoana_c2;
  INSERT INTO public.persoane(nume, prenume) VALUES ('TestC', 'Duplicat') RETURNING id_persoana INTO persoana_dup;
  INSERT INTO public.persoane(nume, prenume) VALUES ('TestI', 'Unu') RETURNING id_persoana INTO persoana_i1;
  INSERT INTO public.persoane(nume, prenume) VALUES ('TestI', 'Doi') RETURNING id_persoana INTO persoana_i2;
  INSERT INTO public.persoane(nume, prenume) VALUES ('TestI', 'Trei') RETURNING id_persoana INTO persoana_i3;
  INSERT INTO public.cursanti(id_persoana, cnp) VALUES (persoana_c1, '0000000000001') RETURNING id_cursant INTO cursant_1;
  INSERT INTO public.cursanti(id_persoana, cnp) VALUES (persoana_c2, '0000000000002') RETURNING id_cursant INTO cursant_2;
  INSERT INTO public.instructori(id_persoana) VALUES (persoana_i1) RETURNING id_instructor INTO instructor_1;
  INSERT INTO public.instructori(id_persoana) VALUES (persoana_i2) RETURNING id_instructor INTO instructor_2;
  INSERT INTO public.instructori(id_persoana) VALUES (persoana_i3) RETURNING id_instructor INTO instructor_3;
  INSERT INTO public.vehicule(numar_inmatriculare, marca, model)
    VALUES ('TESTB001', 'MarcaFictiva', 'ModelA') RETURNING id_vehicul INTO vehicul_1;
  INSERT INTO public.vehicule(numar_inmatriculare, marca, model)
    VALUES ('TESTB002', 'MarcaFictiva', 'ModelB') RETURNING id_vehicul INTO vehicul_2;

  -- 1. CNP duplicat: 23505 (UNIQUE); formatul este verificat separat de CHECK.
  BEGIN
    INSERT INTO public.cursanti(id_persoana, cnp) VALUES (persoana_dup, '0000000000001');
    RAISE EXCEPTION 'ESec test: CNP duplicat acceptat';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  INSERT INTO public.inscrieri(id_cursant, id_instructor, data_inscrierii, tarif_curs)
    VALUES (cursant_1, instructor_1, DATE '2025-12-31', 1000)
    RETURNING id_inscriere INTO inscriere_veche;
  INSERT INTO public.programari(id_inscriere, id_instructor, id_vehicul, inceput, id_utilizator_creare)
    VALUES (inscriere_veche, instructor_1, vehicul_1,
      '2026-01-15 10:00:00+02'::timestamptz, actor);
  UPDATE public.programari SET stare = 'finalizata' WHERE id_inscriere = inscriere_veche;
  UPDATE public.inscrieri SET stare = 'finalizata', data_finalizarii = DATE '2026-01-16'
    WHERE id_inscriere = inscriere_veche;
  INSERT INTO public.inscrieri(id_cursant, id_instructor, data_inscrierii, tarif_curs)
    VALUES (cursant_1, instructor_2, DATE '2026-01-17', 1000)
    RETURNING id_inscriere INTO inscriere_1;
  INSERT INTO public.inscrieri(id_cursant, id_instructor, tarif_curs)
    VALUES (cursant_2, instructor_2, 1000)
    RETURNING id_inscriere INTO inscriere_2;

  -- 2. Inscriere activa duplicata: 23505 (indexul unic partial).
  BEGIN
    INSERT INTO public.inscrieri(id_cursant, id_instructor, tarif_curs)
      VALUES (cursant_1, instructor_3, 900);
    RAISE EXCEPTION 'ESec test: a doua inscriere activa acceptata';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  -- 3. Tarif invalid: 23514 (CHECK).
  BEGIN
    INSERT INTO public.inscrieri(id_cursant, id_instructor, tarif_curs)
      VALUES (cursant_2, instructor_3, -1);
    RAISE EXCEPTION 'ESec test: tarif invalid acceptat';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- 4. Sfarsitul primit gresit este inlocuit de trigger cu inceput + 90 min.
  INSERT INTO public.programari(id_inscriere, id_instructor, id_vehicul,
                                inceput, sfarsit, id_utilizator_creare)
    VALUES (inscriere_1, instructor_2, vehicul_1,
      '2030-06-12 10:00:00+03', '2030-06-12 10:07:00+03', actor)
    RETURNING id_programare, sfarsit INTO programare_1, sfarsit_calculat;
  IF sfarsit_calculat <> '2030-06-12 11:30:00+03'::timestamptz THEN
    RAISE EXCEPTION 'ESec test: durata nu este de 90 de minute';
  END IF;

  -- 5. Suprapunere instructor: alt cursant, alt vehicul -> 23P01.
  BEGIN
    INSERT INTO public.programari(id_inscriere, id_instructor, id_vehicul, inceput, id_utilizator_creare)
      VALUES (inscriere_2, instructor_2, vehicul_2, '2030-06-12 11:00:00+03', actor);
    RAISE EXCEPTION 'ESec test: instructor suprapus';
  EXCEPTION WHEN exclusion_violation THEN NULL;
  END;

  -- Schimbam repartizarea studentului 2, fara programari viitoare ramase.
  UPDATE public.inscrieri SET id_instructor = instructor_3 WHERE id_inscriere = inscriere_2;

  -- 6. Suprapunere vehicul: alt cursant, alt instructor -> 23P01.
  BEGIN
    INSERT INTO public.programari(id_inscriere, id_instructor, id_vehicul, inceput, id_utilizator_creare)
      VALUES (inscriere_2, instructor_3, vehicul_1, '2030-06-12 11:00:00+03', actor);
    RAISE EXCEPTION 'ESec test: vehicul suprapus';
  EXCEPTION WHEN exclusion_violation THEN NULL;
  END;

  -- 7. Cursant prin inscriere veche: instructor si vehicul diferite -> 23P01.
  BEGIN
    INSERT INTO public.programari(id_inscriere, id_instructor, id_vehicul, inceput, id_utilizator_creare)
      VALUES (inscriere_1, instructor_2, vehicul_2, '2026-01-15 10:30:00+02', actor);
    RAISE EXCEPTION 'ESec test: cursant suprapus prin inscrieri diferite';
  EXCEPTION WHEN exclusion_violation THEN NULL;
  END;

  -- 8. Capat comun: acelasi cursant/instructor/vehicul la 11:30 -> succes.
  INSERT INTO public.programari(id_inscriere, id_instructor, id_vehicul, inceput, id_utilizator_creare)
    VALUES (inscriere_1, instructor_2, vehicul_1, '2030-06-12 11:30:00+03', actor);
  IF (SELECT COUNT(*) FROM public.programari
      WHERE id_inscriere = inscriere_1 AND inceput::date = DATE '2030-06-12') <> 2 THEN
    RAISE EXCEPTION 'ESec test: doua programari consecutive nu au fost acceptate';
  END IF;

  -- 9. Vehicul in service: 23514, chiar pe un interval fara conflict.
  UPDATE public.vehicule SET stare = 'service' WHERE id_vehicul = vehicul_2;
  BEGIN
    INSERT INTO public.programari(id_inscriere, id_instructor, id_vehicul, inceput, id_utilizator_creare)
      VALUES (inscriere_2, instructor_3, vehicul_2, '2030-06-12 14:00:00+03', actor);
    RAISE EXCEPTION 'ESec test: vehicul service acceptat';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- 10. FK RESTRICT blocheaza stergerea cursantului cu istoric: 23503.
  BEGIN
    DELETE FROM public.cursanti WHERE id_cursant = cursant_1;
    RAISE EXCEPTION 'ESec test: cursant cu istoric sters';
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;

  RAISE NOTICE 'Cele 10 verificari SQL de baza au trecut; tranzactia se anuleaza acum.';
END;
$teste$;

-- TESTE SUPLIMENTARE CU DOUA SESIUNI, dupa aplicare (nu pot fi dovedite de DO):
-- A si B: INSERT programari suprapuse pentru acelasi cursant, dar inscrieri
-- diferite; A tine tranzactia deschisa, B asteapta lockul pe cursanti; dupa
-- COMMIT A, B primeste 23P01. Repetati cu acelasi instructor/vehicul si cu
-- INSERT inscrieri active concurente. Rulati pe date fictive izolate.
-- Testati apoi rolurile anon/authenticated, RLS si citirea coloanei cnp separat.
ROLLBACK;
