BEGIN;

DROP POLICY utilizatori_citire_profil_activ
ON public.utilizatori;

REVOKE SELECT (id_utilizator, rol, activ)
ON TABLE public.utilizatori
FROM authenticated;

COMMIT;
