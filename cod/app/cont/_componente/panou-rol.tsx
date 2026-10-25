import { deconecteaza } from "@/app/cont/actiuni";
import { etichetaRol, type RolAplicatie } from "@/lib/acces/roluri";

type PanouRolProps = {
  rol: RolAplicatie;
  titlu: string;
  descriere: string;
  sectiuni: readonly string[];
};

export function PanouRol({ rol, titlu, descriere, sectiuni }: PanouRolProps) {
  return (
    <main className="flex flex-1 justify-center bg-zinc-50 px-4 py-8 text-zinc-950 sm:px-6 sm:py-12">
      <section className="w-full max-w-5xl">
        <div className="mb-6 flex flex-col gap-4 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="mb-1 text-sm font-semibold tracking-wide text-zinc-500">
              AUTOSTART VANCEA Manager
            </p>
            <h1 className="text-2xl font-semibold">{titlu}</h1>
            <p className="mt-2 text-sm text-zinc-600">
              Rol activ: <span className="font-medium text-zinc-950">{etichetaRol(rol)}</span>
            </p>
          </div>

          <form action={deconecteaza}>
            <button
              className="rounded-lg bg-zinc-900 px-4 py-2.5 font-medium text-white transition-colors hover:bg-zinc-700"
              type="submit"
            >
              Deconectează-te
            </button>
          </form>
        </div>

        <div className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
          <p className="max-w-3xl text-zinc-600">{descriere}</p>

          <h2 className="mt-8 text-lg font-semibold">Zone disponibile pentru acest rol</h2>
          <div className="mt-4 grid gap-3 sm:grid-cols-2">
            {sectiuni.map((sectiune) => (
              <div
                className="rounded-xl border border-zinc-200 bg-zinc-50 px-4 py-4 text-sm font-medium text-zinc-800"
                key={sectiune}
              >
                {sectiune}
              </div>
            ))}
          </div>

          <p className="mt-6 text-sm text-zinc-500">
            În Etapa 3.5A verificăm separarea interfeței pe roluri. Funcționalitățile
            operaționale vor fi conectate etapizat la operațiile server și la politicile
            deja existente.
          </p>
        </div>
      </section>
    </main>
  );
}
