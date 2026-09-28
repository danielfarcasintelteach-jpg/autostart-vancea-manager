-- AUTOSTART VANCEA Manager - Etapa 2B, rollback PROPUS, NEEXECUTAT.
-- DISTRUGE datele din cele noua tabele! Numai pentru baza de test izolata,
-- dupa export/backup si confirmarea explicita. Nu rula pe baza cu date reale.
-- Ordine inversa a dependentelor, fara CASCADE si fara atingerea auth.users.

BEGIN;
DROP TABLE public.examene RESTRICT;
DROP TABLE public.plati RESTRICT;
DROP TABLE public.programari RESTRICT;
DROP TABLE public.inscrieri RESTRICT;
DROP TABLE public.vehicule RESTRICT;
DROP TABLE public.instructori RESTRICT;
DROP TABLE public.cursanti RESTRICT;
DROP TABLE public.utilizatori RESTRICT;
DROP TABLE public.persoane RESTRICT;

-- DROP TABLE indeparteaza automat constrangerile, indexurile si trigger-ele proprii.
DROP FUNCTION public.verifica_examen() RESTRICT;
DROP FUNCTION public.verifica_plata() RESTRICT;
DROP FUNCTION public.protejeaza_cursant() RESTRICT;
DROP FUNCTION public.protejeaza_instructor() RESTRICT;
DROP FUNCTION public.protejeaza_vehicul() RESTRICT;
DROP FUNCTION public.verifica_programare() RESTRICT;
DROP FUNCTION public.verifica_inscriere() RESTRICT;
DROP FUNCTION public.actualizeaza_audit() RESTRICT;

-- btree_gist si schema extensions pot fi comune altor obiecte: se pastreaza.
COMMIT;
