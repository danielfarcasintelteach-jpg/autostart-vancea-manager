import type { Metadata } from "next";
import Link from "next/link";

import { creeazaVehicul } from "@/app/cont/vehicule/actiuni";
import { cereRoluri } from "@/lib/acces/protectie-ruta";

export const metadata: Metadata = {
  title: "Adaugă vehicul | AUTOSTART VANCEA Manager",
};

type Parametru = string | string[] | undefined;

function primaValoare(valoare: Parametru) {
  return Array.isArray(valoare) ? valoare[0] : valoare;
}

function mesajEroare(cod: string | undefined) {
  switch (cod) {
    case "date_invalide":
      return "Verifică datele introduse. Numărul de înmatriculare, marca și modelul sunt obligatorii. Numărul poate conține numai litere și cifre, fără spații sau cratime, iar anul fabricației trebuie să fie minimum 1900.";
    case "numar_existent":
      return "Există deja un vehicul cu acest număr de înmatriculare.";
    case "server":
      return "Vehiculul nu a putut fi creat din cauza unei erori.";
    default:
      return null;
  }
}

export default async function PaginaVehiculNou({
  searchParams,
}: {
  searchParams: Promise<{ eroare?: Parametru }>;
}) {
  const profil = await cereRoluri("administrator", "secretariat");
  const parametri = await searchParams;
  const eroare = mesajEroare(primaValoare(parametri.eroare));

  const calePanou =
    profil.rol === "administrator"
      ? "/cont/administrator"
      : "/cont/secretariat";

  return (
    <main className="flex flex-1 justify-center bg-zinc-50 px-4 py-8 text-zinc-950 sm:px-6 sm:py-12">
      <section className="w-full max-w-4xl">
        <div className="mb-6 flex flex-col gap-4 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="mb-1 text-sm font-semibold tracking-wide text-zinc-500">
              AUTOSTART VANCEA Manager
            </p>

            <h1 className="text-2xl font-semibold">
              Adaugă vehicul
            </h1>

            <p className="mt-2 max-w-2xl text-sm text-zinc-600">
              Creează un vehicul nou prin operația server-side controlată.
              Vehiculul este creat automat cu starea Activ.
            </p>
          </div>

          <div className="flex flex-wrap gap-2">
            <Link
              className="rounded-lg border border-zinc-300 bg-white px-4 py-2.5 text-sm font-medium text-zinc-800 transition-colors hover:bg-zinc-100"
              href="/cont/vehicule"
            >
              Lista vehiculelor
            </Link>

            <Link
              className="rounded-lg border border-zinc-300 bg-white px-4 py-2.5 text-sm font-medium text-zinc-800 transition-colors hover:bg-zinc-100"
              href={calePanou}
            >
              Panou
            </Link>
          </div>
        </div>

        {eroare && (
          <div
            className="mb-6 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800"
            role="alert"
          >
            {eroare}
          </div>
        )}

        <form
          action={creeazaVehicul}
          className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm"
        >
          <h2 className="text-lg font-semibold">Date vehicul</h2>

          <p className="mt-1 text-sm text-zinc-500">
            Câmpurile marcate cu * sunt obligatorii.
          </p>

          <div className="mt-5 grid gap-4 sm:grid-cols-2">
            <div>
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-700"
                htmlFor="numar_inmatriculare"
              >
                Număr înmatriculare *
              </label>

              <input
                autoCapitalize="characters"
                className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 text-sm uppercase outline-none transition focus:border-zinc-500"
                id="numar_inmatriculare"
                maxLength={20}
                name="numar_inmatriculare"
                pattern="[A-Za-z0-9]+"
                placeholder="MM35CTA"
                required
                type="text"
              />

              <p className="mt-1.5 text-xs text-zinc-500">
                Numai litere și cifre, fără spații sau cratime.
              </p>
            </div>

            <div>
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-700"
                htmlFor="an_fabricatie"
              >
                An fabricație
              </label>

              <input
                className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                id="an_fabricatie"
                max={32767}
                min={1900}
                name="an_fabricatie"
                step={1}
                type="number"
              />
            </div>

            <div>
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-700"
                htmlFor="marca"
              >
                Marcă *
              </label>

              <input
                className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                id="marca"
                maxLength={100}
                name="marca"
                required
                type="text"
              />
            </div>

            <div>
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-700"
                htmlFor="model"
              >
                Model *
              </label>

              <input
                className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                id="model"
                maxLength={100}
                name="model"
                required
                type="text"
              />
            </div>

            <div className="sm:col-span-2">
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-700"
                htmlFor="observatii"
              >
                Observații
              </label>

              <textarea
                className="min-h-32 w-full resize-y rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                id="observatii"
                maxLength={2000}
                name="observatii"
              />
            </div>
          </div>

          <div className="mt-6 flex flex-wrap gap-2">
            <button
              className="rounded-lg bg-zinc-900 px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-zinc-700"
              type="submit"
            >
              Creează vehiculul
            </button>

            <Link
              className="rounded-lg border border-zinc-300 bg-white px-5 py-2.5 text-sm font-medium text-zinc-700 transition-colors hover:bg-zinc-100"
              href="/cont/vehicule"
            >
              Renunță
            </Link>
          </div>
        </form>
      </section>
    </main>
  );
}