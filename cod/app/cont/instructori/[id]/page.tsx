import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { cereRoluri } from "@/lib/acces/protectie-ruta";
import { citesteDetaliiInstructorAdministrativ } from "@/lib/date/instructori";

export const metadata: Metadata = {
  title: "Detalii instructor | AUTOSTART VANCEA Manager",
};

const FORMAT_UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function afiseazaValoare(
  valoare: string | null,
  fallback = "Nespecificat",
) {
  const text = valoare?.trim();

  return text ? text : fallback;
}

function formateazaData(
  valoare: string | null,
  fallback = "Nespecificată",
) {
  if (!valoare) {
    return fallback;
  }

  const componente = valoare.split("-");

  if (componente.length !== 3) {
    return valoare;
  }

  const [an, luna, zi] = componente;

  return `${zi}.${luna}.${an}`;
}

export default async function PaginaDetaliiInstructor({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const profil = await cereRoluri("administrator", "secretariat");
  const { id } = await params;

  if (!FORMAT_UUID.test(id)) {
    notFound();
  }

  const instructor = await citesteDetaliiInstructorAdministrativ(id);

  if (!instructor) {
    notFound();
  }

  const calePanou =
    profil.rol === "administrator"
      ? "/cont/administrator"
      : "/cont/secretariat";

  return (
    <main className="flex flex-1 justify-center bg-zinc-50 px-4 py-8 text-zinc-950 sm:px-6 sm:py-12">
      <section className="w-full max-w-5xl">
        <div className="mb-6 flex flex-col gap-4 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="mb-1 text-sm font-semibold tracking-wide text-zinc-500">
              AUTOSTART VANCEA Manager
            </p>

            <h1 className="text-2xl font-semibold">
              {instructor.nume} {instructor.prenume}
            </h1>

            <div className="mt-3 flex flex-wrap items-center gap-2">
              <span
                className={
                  instructor.stare === "activ"
                    ? "inline-flex rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-semibold text-emerald-700"
                    : "inline-flex rounded-full bg-zinc-100 px-2.5 py-1 text-xs font-semibold text-zinc-600"
                }
              >
                {instructor.stare === "activ" ? "Activ" : "Inactiv"}
              </span>

              <span className="text-xs text-zinc-500">
                ID instructor: {instructor.id_instructor}
              </span>
            </div>
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

        <div className="grid gap-6 lg:grid-cols-2">
          <section className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
            <h2 className="text-lg font-semibold">Date personale</h2>

            <dl className="mt-5 divide-y divide-zinc-100">
              <div className="grid gap-1 py-3 sm:grid-cols-[160px_1fr]">
                <dt className="text-sm font-medium text-zinc-500">
                  Nume
                </dt>
                <dd className="text-sm text-zinc-900">
                  {instructor.nume}
                </dd>
              </div>

              <div className="grid gap-1 py-3 sm:grid-cols-[160px_1fr]">
                <dt className="text-sm font-medium text-zinc-500">
                  Prenume
                </dt>
                <dd className="text-sm text-zinc-900">
                  {instructor.prenume}
                </dd>
              </div>

              <div className="grid gap-1 py-3 sm:grid-cols-[160px_1fr]">
                <dt className="text-sm font-medium text-zinc-500">
                  Telefon
                </dt>
                <dd className="text-sm text-zinc-900">
                  {afiseazaValoare(instructor.telefon)}
                </dd>
              </div>

              <div className="grid gap-1 py-3 sm:grid-cols-[160px_1fr]">
                <dt className="text-sm font-medium text-zinc-500">
                  E-mail
                </dt>
                <dd className="break-all text-sm text-zinc-900">
                  {afiseazaValoare(instructor.email)}
                </dd>
              </div>

              <div className="grid gap-1 py-3 sm:grid-cols-[160px_1fr]">
                <dt className="text-sm font-medium text-zinc-500">
                  Data nașterii
                </dt>
                <dd className="text-sm text-zinc-900">
                  {formateazaData(instructor.data_nasterii)}
                </dd>
              </div>

              <div className="grid gap-1 py-3 sm:grid-cols-[160px_1fr]">
                <dt className="text-sm font-medium text-zinc-500">
                  Adresă
                </dt>
                <dd className="whitespace-pre-wrap text-sm text-zinc-900">
                  {afiseazaValoare(instructor.adresa)}
                </dd>
              </div>
            </dl>
          </section>

          <section className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
            <h2 className="text-lg font-semibold">
              Date profesionale
            </h2>

            <dl className="mt-5 divide-y divide-zinc-100">
              <div className="grid gap-1 py-3 sm:grid-cols-[160px_1fr]">
                <dt className="text-sm font-medium text-zinc-500">
                  Data angajării
                </dt>
                <dd className="text-sm text-zinc-900">
                  {formateazaData(instructor.data_angajarii)}
                </dd>
              </div>

              <div className="grid gap-1 py-3 sm:grid-cols-[160px_1fr]">
                <dt className="text-sm font-medium text-zinc-500">
                  Stare instructor
                </dt>
                <dd className="text-sm text-zinc-900">
                  {instructor.stare === "activ" ? "Activ" : "Inactiv"}
                </dd>
              </div>

              <div className="grid gap-1 py-3 sm:grid-cols-[160px_1fr]">
                <dt className="text-sm font-medium text-zinc-500">
                  ID persoană
                </dt>
                <dd className="break-all text-sm text-zinc-900">
                  {instructor.id_persoana}
                </dd>
              </div>
            </dl>

            <div className="mt-5 border-t border-zinc-200 pt-5">
              <p className="text-sm leading-6 text-zinc-600">
                În 5D1 această fișă este numai pentru citire. Operațiile
                de creare, modificare și activare/dezactivare vor fi
                conectate în subetapele următoare.
              </p>
            </div>
          </section>
        </div>

        <section className="mt-6 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
          <h2 className="text-lg font-semibold">Observații</h2>

          <p className="mt-4 whitespace-pre-wrap text-sm leading-6 text-zinc-700">
            {afiseazaValoare(
              instructor.observatii,
              "Nu sunt observații înregistrate.",
            )}
          </p>
        </section>
      </section>
    </main>
  );
}