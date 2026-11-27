import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { cereRoluri } from "@/lib/acces/protectie-ruta";
import {
  citesteDetaliiProgramareAdministrativ,
  type StareProgramare,
} from "@/lib/date/programari";

export const metadata: Metadata = {
  title: "Detalii programare | AUTOSTART VANCEA Manager",
};

const FORMAT_UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function etichetaStare(
  stare: StareProgramare,
): string {
  switch (stare) {
    case "programata":
      return "Programată";
    case "finalizata":
      return "Finalizată";
    case "anulata":
      return "Anulată";
    case "absent":
      return "Absent";
  }
}

function clasaStare(
  stare: StareProgramare,
): string {
  switch (stare) {
    case "programata":
      return "inline-flex rounded-full bg-amber-50 px-2.5 py-1 text-xs font-semibold text-amber-700";
    case "finalizata":
      return "inline-flex rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-semibold text-emerald-700";
    case "anulata":
      return "inline-flex rounded-full bg-zinc-100 px-2.5 py-1 text-xs font-semibold text-zinc-600";
    case "absent":
      return "inline-flex rounded-full bg-red-50 px-2.5 py-1 text-xs font-semibold text-red-700";
  }
}

function formateazaDataOraRo(
  valoare: string,
): string {
  const data = new Date(valoare);

  if (Number.isNaN(data.getTime())) {
    return valoare;
  }

  const parti = new Intl.DateTimeFormat("ro-RO", {
    timeZone: "Europe/Bucharest",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).formatToParts(data);

  const obtine = (tip: Intl.DateTimeFormatPartTypes) =>
    parti.find((parte) => parte.type === tip)?.value ?? "";

  return `${obtine("day")}/${obtine("month")}/${obtine("year")}, ${obtine("hour")}:${obtine("minute")}`;
}

function CampDetaliu({
  eticheta,
  valoare,
}: {
  eticheta: string;
  valoare: string | null;
}) {
  return (
    <div className="rounded-xl border border-zinc-200 bg-zinc-50 p-4">
      <dt className="text-xs font-semibold uppercase tracking-wide text-zinc-500">
        {eticheta}
      </dt>

      <dd className="mt-1.5 text-sm font-medium text-zinc-900">
        {valoare === null || valoare === ""
          ? "—"
          : valoare}
      </dd>
    </div>
  );
}

export default async function PaginaDetaliiProgramare({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const profil = await cereRoluri(
    "administrator",
    "secretariat",
  );

  const { id } = await params;

  if (!FORMAT_UUID.test(id)) {
    notFound();
  }

  const programare =
    await citesteDetaliiProgramareAdministrativ(id);

  if (!programare) {
    notFound();
  }

  const calePanou =
    profil.rol === "administrator"
      ? "/cont/administrator"
      : "/cont/secretariat";

  const numeCursant =
    `${programare.cursant_nume} ${programare.cursant_prenume}`;

  const numeInstructor =
    `${programare.instructor_nume} ${programare.instructor_prenume}`;

  const vehicul =
    `${programare.numar_inmatriculare} · ${programare.marca} ${programare.model}`;

  return (
    <main className="flex flex-1 justify-center bg-zinc-50 px-4 py-8 text-zinc-950 sm:px-6 sm:py-12">
      <section className="w-full max-w-5xl">
        <div className="mb-6 flex flex-col gap-4 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="mb-1 text-sm font-semibold tracking-wide text-zinc-500">
              AUTOSTART VANCEA Manager
            </p>

            <h1 className="text-2xl font-semibold">
              Programare — {numeCursant}
            </h1>

            <p className="mt-1 text-sm text-zinc-600">
              {formateazaDataOraRo(
                programare.inceput,
              )}{" "}
              –{" "}
              {formateazaDataOraRo(
                programare.sfarsit,
              )}
            </p>

            <div className="mt-3">
              <span
                className={clasaStare(
                  programare.stare,
                )}
              >
                {etichetaStare(
                  programare.stare,
                )}
              </span>
            </div>
          </div>

          <div className="flex flex-wrap gap-2">
            <Link
              className="inline-flex w-fit rounded-lg border border-zinc-300 bg-white px-4 py-2.5 text-sm font-medium text-zinc-800 transition-colors hover:bg-zinc-100"
              href="/cont/programari"
            >
              Înapoi la programări
            </Link>

            <Link
              className="inline-flex w-fit rounded-lg border border-zinc-300 bg-white px-4 py-2.5 text-sm font-medium text-zinc-800 transition-colors hover:bg-zinc-100"
              href={calePanou}
            >
              Panou
            </Link>
          </div>
        </div>

        <section className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
          <div>
            <h2 className="text-lg font-semibold">
              Date programare
            </h2>

            <p className="mt-1 text-sm text-zinc-500">
              Date administrative citite prin
              operația controlată dedicată
              modulului Programări.
            </p>
          </div>

          <dl className="mt-5 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <CampDetaliu
              eticheta="Cursant"
              valoare={numeCursant}
            />

            <CampDetaliu
              eticheta="Instructor"
              valoare={numeInstructor}
            />

            <CampDetaliu
              eticheta="Vehicul"
              valoare={vehicul}
            />

            <CampDetaliu
              eticheta="Început"
              valoare={formateazaDataOraRo(
                programare.inceput,
              )}
            />

            <CampDetaliu
              eticheta="Sfârșit"
              valoare={formateazaDataOraRo(
                programare.sfarsit,
              )}
            />

            <CampDetaliu
              eticheta="Durată"
              valoare="90 minute"
            />

            <CampDetaliu
              eticheta="Stare"
              valoare={etichetaStare(
                programare.stare,
              )}
            />

            <CampDetaliu
              eticheta="ID programare"
              valoare={programare.id_programare}
            />
          </dl>

          <div className="mt-4 rounded-xl border border-zinc-200 bg-zinc-50 p-4">
            <h3 className="text-xs font-semibold uppercase tracking-wide text-zinc-500">
              Observații
            </h3>

            <p className="mt-2 whitespace-pre-wrap text-sm leading-6 text-zinc-800">
              {programare.observatii || "—"}
            </p>
          </div>
        </section>

        <section className="mt-6 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
          <h2 className="text-lg font-semibold">
            Legături administrative
          </h2>

          <div className="mt-4 flex flex-wrap gap-2">
            <Link
              className="rounded-lg border border-zinc-300 bg-white px-4 py-2.5 text-sm font-medium text-zinc-800 transition-colors hover:bg-zinc-100"
              href={`/cont/inscrieri/${programare.id_inscriere}`}
            >
              Vezi înscrierea
            </Link>

            <Link
              className="rounded-lg border border-zinc-300 bg-white px-4 py-2.5 text-sm font-medium text-zinc-800 transition-colors hover:bg-zinc-100"
              href={`/cont/cursanti/${programare.id_cursant}`}
            >
              Vezi cursantul
            </Link>

            <Link
              className="rounded-lg border border-zinc-300 bg-white px-4 py-2.5 text-sm font-medium text-zinc-800 transition-colors hover:bg-zinc-100"
              href={`/cont/instructori/${programare.id_instructor}`}
            >
              Vezi instructorul
            </Link>

            <Link
              className="rounded-lg border border-zinc-300 bg-white px-4 py-2.5 text-sm font-medium text-zinc-800 transition-colors hover:bg-zinc-100"
              href={`/cont/vehicule/${programare.id_vehicul}`}
            >
              Vezi vehiculul
            </Link>
          </div>
        </section>

        <p className="mt-5 text-sm text-zinc-500">
          În Etapa 5G1 este disponibilă citirea
          administrativă controlată a detaliilor
          programării.
        </p>
      </section>
    </main>
  );
}