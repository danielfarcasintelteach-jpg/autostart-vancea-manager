import type { Metadata } from "next";
import Link from "next/link";
import { CampDataRo } from "@/app/cont/_componente/camp-data-ro";

import { creeazaInstructor } from "@/app/cont/instructori/actiuni";
import { cereRoluri } from "@/lib/acces/protectie-ruta";

export const metadata: Metadata = {
  title: "Adaugă instructor | AUTOSTART VANCEA Manager",
};

type Parametru = string | string[] | undefined;

function primaValoare(valoare: Parametru) {
  return Array.isArray(valoare) ? valoare[0] : valoare;
}

function mesajEroare(cod: string | undefined) {
  switch (cod) {
    case "date_invalide":
      return "Verifică datele introduse. Numele și prenumele sunt obligatorii, iar celelalte câmpuri trebuie să respecte formatul solicitat.";
    case "server":
      return "Instructorul nu a putut fi creat din cauza unei erori.";
    default:
      return null;
  }
}

export default async function PaginaInstructorNou({
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
              Adaugă instructor
            </h1>

            <p className="mt-2 max-w-2xl text-sm text-zinc-600">
              Creează persoana și profilul profesional al instructorului
              prin operația server-side controlată.
            </p>
          </div>

          <div className="flex flex-wrap gap-2">
            <Link
              className="rounded-lg border border-zinc-300 bg-white px-4 py-2.5 text-sm font-medium text-zinc-800 transition-colors hover:bg-zinc-100"
              href="/cont/instructori"
            >
              Lista instructorilor
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
          action={creeazaInstructor}
          className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm"
        >
          <h2 className="text-lg font-semibold">Date instructor</h2>

          <p className="mt-1 text-sm text-zinc-500">
            Câmpurile marcate cu * sunt obligatorii.
          </p>

          <div className="mt-5 grid gap-4 sm:grid-cols-2">
            <div>
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-700"
                htmlFor="nume"
              >
                Nume *
              </label>

              <input
                autoComplete="family-name"
                className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                id="nume"
                maxLength={100}
                name="nume"
                required
                type="text"
              />
            </div>

            <div>
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-700"
                htmlFor="prenume"
              >
                Prenume *
              </label>

              <input
                autoComplete="given-name"
                className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                id="prenume"
                maxLength={100}
                name="prenume"
                required
                type="text"
              />
            </div>

            <div>
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-700"
                htmlFor="telefon"
              >
                Telefon
              </label>

              <input
                autoComplete="tel"
                className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                id="telefon"
                maxLength={30}
                name="telefon"
                type="tel"
              />
            </div>

            <div>
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-700"
                htmlFor="email"
              >
                E-mail
              </label>

              <input
                autoComplete="email"
                className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                id="email"
                maxLength={254}
                name="email"
                type="email"
              />
            </div>

            <div>
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-700"
                htmlFor="data_nasterii"
              >
                Data nașterii
              </label>

                            <CampDataRo id="data_nasterii" name="data_nasterii" />
            </div>

            <div>
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-700"
                htmlFor="data_angajarii"
              >
                Data angajării
              </label>

                            <CampDataRo id="data_angajarii" name="data_angajarii" />
            </div>

            <div className="sm:col-span-2">
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-700"
                htmlFor="adresa"
              >
                Adresă
              </label>

              <textarea
                className="min-h-24 w-full resize-y rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                id="adresa"
                maxLength={1000}
                name="adresa"
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
              Creează instructorul
            </button>

            <Link
              className="rounded-lg border border-zinc-300 bg-white px-5 py-2.5 text-sm font-medium text-zinc-700 transition-colors hover:bg-zinc-100"
              href="/cont/instructori"
            >
              Renunță
            </Link>
          </div>
        </form>
      </section>
    </main>
  );
}
