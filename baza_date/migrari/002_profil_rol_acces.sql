BEGIN;

CREATE POLICY utilizatori_citire_profil_activ
ON public.utilizatori
AS PERMISSIVE
FOR SELECT
TO authenticated
USING (
  id_utilizator = (SELECT auth.uid())
  AND activ IS TRUE
);

GRANT SELECT (id_utilizator, rol, activ)
ON TABLE public.utilizatori
TO authenticated;

COMMIT;
