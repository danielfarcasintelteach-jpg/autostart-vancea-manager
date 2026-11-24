-- 013_intarire_securitate_inscrieri.sql
-- Etapa 5F5
--
-- Scop:
-- 1. Wrapper-ele publice ale modulului Inscrieri devin SECURITY DEFINER.
-- 2. Rolurile client nu mai pot executa direct functiile interne
--    din schema operatii.
-- 3. USAGE pe schema operatii NU este retras aici, deoarece alte
--    module existente pot depinde inca de aceasta permisiune.
--
-- Functiile interne continua sa verifice auth.uid(), profilul activ
-- si rolul aplicatiei.

begin;

-- ============================================================
-- 1. Wrapper-ele publice devin SECURITY DEFINER
-- ============================================================

alter function public.creare_inscriere(
  uuid,
  uuid,
  numeric,
  text
)
security definer;

alter function public.modifica_inscriere(
  uuid,
  jsonb
)
security definer;

alter function public.realoca_instructor(
  uuid,
  uuid
)
security definer;

alter function public.finalizeaza_inscriere(
  uuid
)
security definer;

alter function public.anuleaza_inscriere(
  uuid
)
security definer;

alter function public.lista_inscrieri_administrativ(
  text,
  character varying,
  integer,
  integer
)
security definer;

alter function public.detalii_inscriere_administrativ(
  uuid
)
security definer;

-- Wrapper-ele raman accesibile doar prin interfata publica
-- pentru rolurile autorizate la nivel de API.
revoke all on function public.creare_inscriere(
  uuid,
  uuid,
  numeric,
  text
) from public, anon;

revoke all on function public.modifica_inscriere(
  uuid,
  jsonb
) from public, anon;

revoke all on function public.realoca_instructor(
  uuid,
  uuid
) from public, anon;

revoke all on function public.finalizeaza_inscriere(
  uuid
) from public, anon;

revoke all on function public.anuleaza_inscriere(
  uuid
) from public, anon;

revoke all on function public.lista_inscrieri_administrativ(
  text,
  character varying,
  integer,
  integer
) from public, anon;

revoke all on function public.detalii_inscriere_administrativ(
  uuid
) from public, anon;

grant execute on function public.creare_inscriere(
  uuid,
  uuid,
  numeric,
  text
) to authenticated, service_role;

grant execute on function public.modifica_inscriere(
  uuid,
  jsonb
) to authenticated, service_role;

grant execute on function public.realoca_instructor(
  uuid,
  uuid
) to authenticated, service_role;

grant execute on function public.finalizeaza_inscriere(
  uuid
) to authenticated, service_role;

grant execute on function public.anuleaza_inscriere(
  uuid
) to authenticated, service_role;

grant execute on function public.lista_inscrieri_administrativ(
  text,
  character varying,
  integer,
  integer
) to authenticated, service_role;

grant execute on function public.detalii_inscriere_administrativ(
  uuid
) to authenticated, service_role;

-- ============================================================
-- 2. Inchidem accesul direct la implementarea interna
-- ============================================================

revoke all on function operatii.creare_inscriere(
  uuid,
  uuid,
  numeric,
  text
) from public, anon, authenticated;

revoke all on function operatii.modifica_inscriere(
  uuid,
  jsonb
) from public, anon, authenticated;

revoke all on function operatii.realoca_instructor(
  uuid,
  uuid
) from public, anon, authenticated;

revoke all on function operatii.finalizeaza_inscriere(
  uuid
) from public, anon, authenticated;

revoke all on function operatii.anuleaza_inscriere(
  uuid
) from public, anon, authenticated;

revoke all on function operatii.lista_inscrieri_administrativ(
  text,
  character varying,
  integer,
  integer
) from public, anon, authenticated;

revoke all on function operatii.detalii_inscriere_administrativ(
  uuid
) from public, anon, authenticated;

commit;