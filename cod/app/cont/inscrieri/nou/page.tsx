import type { Metadata } from "next";
import Link from "next/link";

import { creeazaInscriere } from "@/app/cont/inscrieri/actiuni";
import { cereRoluri } from "@/lib/acces/protectie-ruta";
import { citesteListaCursantiAdministrativ } from "@/lib/date/cursanti";
import { citesteListaInstructoriAdministrativ } from "@/lib/date/instructori";

export const metadata: Metadata = {
  title: "Înscriere nouă | AUTOSTART VANCEA Manager",
};

type Parametru = string | string[] | undefined;

function primaValoare(
  valoare: Parametru,
): string | undefined {
  return Array.isArray(valoare)
    ? valoare[0]
    : valoare;
}

function mesajEroare(
  cod: string | undefined,
): string | null {
  switch (cod) {
    case "date_invalide":
      return "Verifică datele introduse. Cursantul, instructorul și tariful cursului sunt obligatorii.";
    case "resursa_inexistenta":
      return "Cursantul sau instructorul selectat nu mai există.";
    case "resursa_inactiva":
      return "Cursantul sau instructorul selectat nu mai este activ.";
    case "inscriere_activa_existenta":
      return "Cursantul selectat are deja o înscriere activă.";
    case "server":
      return "Înscrierea nu a putut fi creată din cauza unei erori.";
    default:
      return null;
  }
}

export default async function PaginaInscriereNoua({
  searchParams,
}: {
  searchParams: Promise<{
    eroare?: Parametru;
  }>;
}) {
  const profil = await cereRoluri(
    "administrator",
    "secretariat",
  );

  const parametri = await searchParams;

  const eroare = mesajEroare(
    primaValoare(parametri.eroare),
  );

  const [
    rezultatCursanti,
    rezultatInstructori,
  ] = await Promise.all([
    citesteListaCursantiAdministrativ({
      stare: "activ",
      limita: 100,
      offset: 0,
    }),
    citesteListaInstructoriAdministrativ({
      stare: "activ",
      limita: 100,
      offset: 0,
    }),
  ]);

  const cursanti = rezultatCursanti.cursanti;
  const instructori =
    rezultatInstructori.instructori;

  const poateCrea =
    cursanti.length > 0 &&
    instructori.length > 0;

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
              Creează înscriere
            </h1>

            <p className="mt-2 max-w-2xl text-sm text-zinc-600">
              Înregistrează un cursant activ la
              categoria B și îi atribuie un
              instructor activ.
            </p>
          </div>

          <div className="flex flex-wrap gap-2">
            <Link
              className="rounded-lg border border-zinc-300 bg-white px-4 py-2.5 text-sm font-medium text-zinc-800 transition-colors hover:bg-zinc-100"
              href="/cont/inscrieri"
            >
              Lista înscrierilor
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

        {!poateCrea && (
          <div
            className="mb-6 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900"
            role="alert"
          >
            Pentru a crea o înscriere trebuie să
            existe cel puțin un cursant activ și
            un instructor activ.
          </div>
        )}

        <form
          action={creeazaInscriere}
          className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm"
        >
          <h2 className="text-lg font-semibold">
            Date înscriere
          </h2>

          <p className="mt-1 text-sm text-zinc-500">
            Categoria, data și starea inițială
            sunt stabilite automat de sistem.
          </p>

          <div className="mt-5 grid gap-5 sm:grid-cols-2">
            <div>
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-800"
                htmlFor="id_cursant"
              >
                Cursant *
              </label>

              <select
                className="w-full rounded-lg border border-zinc-300 bg-white px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500 disabled:bg-zinc-100"
                disabled={cursanti.length === 0}
                id="id_cursant"
                name="id_cursant"
                required
              >
                <option value="">
                  Selectează cursantul
                </option>

                {cursanti.map((cursant) => (
                  <option
                    key={cursant.id_cursant}
                    value={cursant.id_cursant}
                  >
                    {cursant.nume}{" "}
                    {cursant.prenume}
                  </option>
                ))}
              </select>

              <p className="mt-1.5 text-xs text-zinc-500">
                Sunt afișați numai cursanții activi.
              </p>
            </div>

            <div>
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-800"
                htmlFor="id_instructor"
              >
                Instructor *
              </label>

              <select
                className="w-full rounded-lg border border-zinc-300 bg-white px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500 disabled:bg-zinc-100"
                disabled={instructori.length === 0}
                id="id_instructor"
                name="id_instructor"
                required
              >
                <option value="">
                  Selectează instructorul
                </option>

                {instructori.map(
                  (instructor) => (
                    <option
                      key={
                        instructor.id_instructor
                      }
                      value={
                        instructor.id_instructor
                      }
                    >
                      {instructor.nume}{" "}
                      {instructor.prenume}
                    </option>
                  ),
                )}
              </select>

              <p className="mt-1.5 text-xs text-zinc-500">
                Sunt afișați numai instructorii activi.
              </p>
            </div>

            <div>
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-800"
                htmlFor="categorie"
              >
                Categoria
              </label>

              <input
                className="w-full rounded-lg border border-zinc-200 bg-zinc-100 px-3 py-2.5 text-sm font-medium text-zinc-700"
                id="categorie"
                readOnly
                type="text"
                value="B"
              />

              <p className="mt-1.5 text-xs text-zinc-500">
                AUTOSTART VANCEA Manager gestionează
                exclusiv categoria B.
              </p>
            </div>

            <div>
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-800"
                htmlFor="tarif_curs"
              >
                Tarif curs *
              </label>

              <div className="relative">
                <input
                  className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 pr-16 text-sm outline-none transition focus:border-zinc-500"
                  id="tarif_curs"
                  inputMode="decimal"
                  max="9999999999.99"
                  min="0.01"
                  name="tarif_curs"
                  placeholder="3000.00"
                  required
                  step="0.01"
                  type="number"
                />

                <span className="pointer-events-none absolute inset-y-0 right-3 flex items-center text-sm text-zinc-500">
                  RON
                </span>
              </div>

              <p className="mt-1.5 text-xs text-zinc-500">
                Valoare pozitivă, cu maximum două
                zecimale.
              </p>
            </div>
          </div>

          <div className="mt-5">
            <label
              className="mb-1.5 block text-sm font-medium text-zinc-800"
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

          <div className="mt-6 rounded-xl border border-zinc-200 bg-zinc-50 p-4 text-sm text-zinc-600">
            Data înscrierii va fi data curentă din
            România, iar starea inițială va fi{" "}
            <strong>Activă</strong>. Sistemul nu
            permite două înscrieri active pentru
            același cursant.
          </div>

          <div className="mt-6 flex flex-wrap gap-3 border-t border-zinc-200 pt-5">
            <button
              className="rounded-lg bg-zinc-900 px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-zinc-700 disabled:cursor-not-allowed disabled:bg-zinc-400"
              disabled={!poateCrea}
              type="submit"
            >
              Creează înscrierea
            </button>

            <Link
              className="rounded-lg border border-zinc-300 bg-white px-5 py-2.5 text-sm font-medium text-zinc-700 transition-colors hover:bg-zinc-100"
              href="/cont/inscrieri"
            >
              Renunță
            </Link>
          </div>
        </form>
      </section>
    </main>
  );
}