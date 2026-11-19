import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { cereRoluri } from "@/lib/acces/protectie-ruta";
import {
  citesteDetaliiInscriereAdministrativ,
  type StareInscriere,
} from "@/lib/date/inscrieri";
import {
  formateazaDataRo,
  formateazaLei,
} from "@/lib/formatari/administrativ";

export const metadata: Metadata = {
  title: "Detalii înscriere | AUTOSTART VANCEA Manager",
};

const FORMAT_UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function etichetaStare(stare: StareInscriere): string {
  switch (stare) {
    case "activa":
      return "Activă";
    case "finalizata":
      return "Finalizată";
    case "anulata":
      return "Anulată";
  }
}

function clasaStare(stare: StareInscriere): string {
  switch (stare) {
    case "activa":
      return "inline-flex rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-semibold text-emerald-700";
    case "finalizata":
      return "inline-flex rounded-full bg-blue-50 px-2.5 py-1 text-xs font-semibold text-blue-700";
    case "anulata":
      return "inline-flex rounded-full bg-zinc-100 px-2.5 py-1 text-xs font-semibold text-zinc-600";
  }
}

function CampDetaliu({
  eticheta,
  valoare,
}: {
  eticheta: string;
  valoare: string | number | null;
}) {
  return (
    <div className="rounded-xl border border-zinc-200 bg-zinc-50 p-4">
      <dt className="text-xs font-semibold uppercase tracking-wide text-zinc-500">
        {eticheta}
      </dt>

      <dd className="mt-1.5 text-sm font-medium text-zinc-900">
        {valoare === null || valoare === "" ? "—" : valoare}
      </dd>
    </div>
  );
}

export default async function PaginaDetaliiInscriere({
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

  const inscriere =
    await citesteDetaliiInscriereAdministrativ(id);

  if (!inscriere) {
    notFound();
  }

  const calePanou =
    profil.rol === "administrator"
      ? "/cont/administrator"
      : "/cont/secretariat";

  const numeCursant =
    `${inscriere.cursant_nume} ${inscriere.cursant_prenume}`;

  const numeInstructor =
    `${inscriere.instructor_nume} ${inscriere.instructor_prenume}`;

  return (
    <main className="flex flex-1 justify-center bg-zinc-50 px-4 py-8 text-zinc-950 sm:px-6 sm:py-12">
      <section className="w-full max-w-5xl">
        <div className="mb-6 flex flex-col gap-4 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="mb-1 text-sm font-semibold tracking-wide text-zinc-500">
              AUTOSTART VANCEA Manager
            </p>

            <h1 className="text-2xl font-semibold">
              Înscriere — {numeCursant}
            </h1>

            <p className="mt-1 text-sm text-zinc-600">
              Categoria {inscriere.categorie} ·{" "}
              {formateazaDataRo(inscriere.data_inscrierii)}
            </p>

            <div className="mt-3">
              <span className={clasaStare(inscriere.stare)}>
                {etichetaStare(inscriere.stare)}
              </span>
            </div>
          </div>

          <div className="flex flex-wrap gap-2">
            <Link
              className="inline-flex w-fit rounded-lg border border-zinc-300 bg-white px-4 py-2.5 text-sm font-medium text-zinc-800 transition-colors hover:bg-zinc-100"
              href="/cont/inscrieri"
            >
              Înapoi la înscrieri
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
              Date înscriere
            </h2>

            <p className="mt-1 text-sm text-zinc-500">
              Date administrative citite exclusiv prin operația controlată
              dedicată modulului Înscrieri.
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
              eticheta="Categoria"
              valoare={inscriere.categorie}
            />

            <CampDetaliu
              eticheta="Data înscrierii"
              valoare={formateazaDataRo(
                inscriere.data_inscrierii,
              )}
            />

            <CampDetaliu
              eticheta="Tarif curs"
              valoare={formateazaLei(
                Number(inscriere.tarif_curs),
              )}
            />

            <CampDetaliu
              eticheta="Stare"
              valoare={etichetaStare(inscriere.stare)}
            />

            <CampDetaliu
              eticheta="Data finalizării"
              valoare={formateazaDataRo(
                inscriere.data_finalizarii,
              )}
            />

            <CampDetaliu
              eticheta="ID înscriere"
              valoare={inscriere.id_inscriere}
            />
          </dl>

          <div className="mt-4 rounded-xl border border-zinc-200 bg-zinc-50 p-4">
            <h3 className="text-xs font-semibold uppercase tracking-wide text-zinc-500">
              Observații
            </h3>

            <p className="mt-2 whitespace-pre-wrap text-sm leading-6 text-zinc-800">
              {inscriere.observatii || "—"}
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
              href={`/cont/cursanti/${inscriere.id_cursant}`}
            >
              Vezi cursantul
            </Link>

            <Link
              className="rounded-lg border border-zinc-300 bg-white px-4 py-2.5 text-sm font-medium text-zinc-800 transition-colors hover:bg-zinc-100"
              href={`/cont/instructori/${inscriere.id_instructor}`}
            >
              Vezi instructorul
            </Link>
          </div>
        </section>

        <p className="mt-5 text-sm text-zinc-500">
          În Etapa 5F1 această pagină este exclusiv pentru citire.
          Operațiile de creare, modificare și schimbare a stării vor fi
          implementate separat.
        </p>
      </section>
    </main>
  );
}