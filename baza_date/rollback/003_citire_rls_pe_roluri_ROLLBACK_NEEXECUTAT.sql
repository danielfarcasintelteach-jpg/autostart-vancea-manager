-- NEEXECUTAT. Numai dupa verificarea ca 003 este singura schimbare peste 002.
BEGIN;

DROP POLICY utilizatori_citire_administrator ON public.utilizatori;
DROP POLICY persoane_citire_roluri ON public.persoane;
DROP POLICY cursanti_citire_roluri ON public.cursanti;
DROP POLICY instructori_citire_roluri ON public.instructori;
DROP POLICY vehicule_citire_roluri ON public.vehicule;
DROP POLICY inscrieri_citire_roluri ON public.inscrieri;
DROP POLICY programari_citire_roluri ON public.programari;
DROP POLICY plati_citire_roluri ON public.plati;
DROP POLICY examene_citire_roluri ON public.examene;

REVOKE SELECT (id_persoana,nume,prenume) ON TABLE public.persoane FROM authenticated;
REVOKE SELECT (id_cursant,id_persoana,stare) ON TABLE public.cursanti FROM authenticated;
REVOKE SELECT (id_instructor,id_persoana,stare) ON TABLE public.instructori FROM authenticated;
REVOKE SELECT (id_vehicul,numar_inmatriculare,marca,model,stare)
  ON TABLE public.vehicule FROM authenticated;
REVOKE SELECT (id_inscriere,id_cursant,id_instructor,categorie,data_inscrierii,stare,data_finalizarii)
  ON TABLE public.inscrieri FROM authenticated;
REVOKE SELECT (id_programare,id_inscriere,id_instructor,id_vehicul,inceput,sfarsit,stare)
  ON TABLE public.programari FROM authenticated;
REVOKE SELECT (id_plata,id_inscriere,tip,suma,stare,data_platii)
  ON TABLE public.plati FROM authenticated;
REVOKE SELECT (id_examen,id_inscriere,tip_examen,numar_incercare,data_examenului,stare,rezultat,punctaj)
  ON TABLE public.examene FROM authenticated;

REVOKE EXECUTE ON FUNCTION intern.persoana_relevanta(uuid),
  intern.vehicul_relevant(uuid), intern.cursant_relevant(uuid),
  intern.instructor_relevant(uuid), intern.inscriere_a_cursantului(uuid),
  intern.inscriere_a_instructorului(uuid), intern.id_cursant_curent(),
  intern.id_instructor_curent(), intern.id_persoana_curenta(),
  intern.rol_curent() FROM authenticated, anon, PUBLIC;
REVOKE ALL ON SCHEMA intern FROM authenticated, anon, PUBLIC;

DROP FUNCTION intern.persoana_relevanta(uuid);
DROP FUNCTION intern.vehicul_relevant(uuid);
DROP FUNCTION intern.cursant_relevant(uuid);
DROP FUNCTION intern.instructor_relevant(uuid);
DROP FUNCTION intern.inscriere_a_cursantului(uuid);
DROP FUNCTION intern.inscriere_a_instructorului(uuid);
DROP FUNCTION intern.id_cursant_curent();
DROP FUNCTION intern.id_instructor_curent();
DROP FUNCTION intern.id_persoana_curenta();
DROP FUNCTION intern.rol_curent();
DROP SCHEMA intern RESTRICT;

COMMIT;
