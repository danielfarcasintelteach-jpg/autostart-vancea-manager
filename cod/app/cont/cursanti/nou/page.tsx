import type { Metadata } from "next";
import Link from "next/link";

import { creeazaCursant } from "@/app/cont/cursanti/actiuni";
import { cereRoluri } from "@/lib/acces/protectie-ruta";

export const metadata: Metadata = {
  title: "Cursant nou | AUTOSTART VANCEA Manager",
};

type Parametru = string | string[] | undefined;

function primaValoare(valoare: Parametru) {
  return Array.isArray(valoare) ? valoare[0] : valoare;
}

function mesajEroare(cod: string | undefined) {
  switch (cod) {
    case "date_invalide":
      return "Verifică datele introduse. Numele, prenumele și CNP-ul sunt obligatorii, iar formatele trebuie să fie valide.";
    case "cnp_existent":
      return "Există deja un cursant cu acest CNP.";
    case "server":
      return "Cursantul nu a putut fi salvat. Încearcă din nou.";
    default:
      return null;
  }
}

export default async function PaginaCursantNou({
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
              Adaugă cursant
            </h1>

            <p className="mt-2 max-w-2xl text-sm text-zinc-600">
              Creează persoana și profilul de cursant. CNP-ul este trimis
              numai operației server-side și nu va fi afișat în lista
              administrativă.
            </p>
          </div>

          <div className="flex flex-wrap gap-2">
            <Link
              className="rounded-lg border border-zinc-300 bg-white px-4 py-2.5 text-sm font-medium text-zinc-800 transition-colors hover:bg-zinc-100"
              href="/cont/cursanti"
            >
              Lista cursanților
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
          action={creeazaCursant}
          className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm"
        >
          <div className="grid gap-5 sm:grid-cols-2">
            <div>
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-800"
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
                className="mb-1.5 block text-sm font-medium text-zinc-800"
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
                className="mb-1.5 block text-sm font-medium text-zinc-800"
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
                className="mb-1.5 block text-sm font-medium text-zinc-800"
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
                className="mb-1.5 block text-sm font-medium text-zinc-800"
                htmlFor="data_nasterii"
              >
                Data nașterii
              </label>

              <input
                className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                id="data_nasterii"
                name="data_nasterii"
                type="date"
              />
            </div>

            <div>
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-800"
                htmlFor="cnp"
              >
                CNP *
              </label>

              <input
                autoComplete="off"
                className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 font-mono text-sm outline-none transition focus:border-zinc-500"
                id="cnp"
                inputMode="numeric"
                maxLength={13}
                minLength={13}
                name="cnp"
                pattern="[0-9]{13}"
                required
                type="text"
              />

              <p className="mt-1.5 text-xs text-zinc-500">
                Exact 13 cifre. CNP-ul nu va fi afișat în lista obișnuită.
              </p>
            </div>
          </div>

          <div className="mt-5">
            <label
              className="mb-1.5 block text-sm font-medium text-zinc-800"
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

          <div className="mt-5">
            <label
              className="mb-1.5 block text-sm font-medium text-zinc-800"
              htmlFor="observatii"
            >
              Observații
            </label>

            <textarea
              className="min-h-28 w-full resize-y rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
              id="observatii"
              maxLength={2000}
              name="observatii"
            />
          </div>

          <div className="mt-6 flex flex-wrap items-center gap-3 border-t border-zinc-200 pt-5">
            <button
              className="rounded-lg bg-zinc-900 px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-zinc-700"
              type="submit"
            >
              Salvează cursant
            </button>

            <Link
              className="rounded-lg border border-zinc-300 bg-white px-5 py-2.5 text-sm font-medium text-zinc-700 transition-colors hover:bg-zinc-100"
              href="/cont/cursanti"
            >
              Renunță
            </Link>
          </div>
        </form>
      </section>
    </main>
  );
}
