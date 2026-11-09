import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { cereRoluri } from "@/lib/acces/protectie-ruta";
import {
  citesteDetaliiVehiculAdministrativ,
  type StareVehicul,
} from "@/lib/date/vehicule";

export const metadata: Metadata = {
  title: "Detalii vehicul | AUTOSTART VANCEA Manager",
};

const FORMAT_UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function etichetaStare(stare: StareVehicul): string {
  switch (stare) {
    case "activ":
      return "Activ";
    case "service":
      return "Service";
    case "indisponibil":
      return "Indisponibil";
    case "inactiv":
      return "Inactiv";
  }
}

function clasaStare(stare: StareVehicul): string {
  switch (stare) {
    case "activ":
      return "inline-flex rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-semibold text-emerald-700";
    case "service":
      return "inline-flex rounded-full bg-amber-50 px-2.5 py-1 text-xs font-semibold text-amber-700";
    case "indisponibil":
      return "inline-flex rounded-full bg-red-50 px-2.5 py-1 text-xs font-semibold text-red-700";
    case "inactiv":
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

export default async function PaginaDetaliiVehicul({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const profil = await cereRoluri("administrator", "secretariat");
  const { id } = await params;

  if (!FORMAT_UUID.test(id)) {
    notFound();
  }

  const vehicul = await citesteDetaliiVehiculAdministrativ(id);

  if (!vehicul) {
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
              {vehicul.numar_inmatriculare}
            </h1>

            <p className="mt-1 text-sm text-zinc-600">
              {vehicul.marca} {vehicul.model}
            </p>

            <div className="mt-3">
              <span className={clasaStare(vehicul.stare)}>
                {etichetaStare(vehicul.stare)}
              </span>
            </div>
          </div>

          <div className="flex flex-wrap gap-2">
            <Link
              className="inline-flex w-fit rounded-lg border border-zinc-300 bg-white px-4 py-2.5 text-sm font-medium text-zinc-800 transition-colors hover:bg-zinc-100"
              href="/cont/vehicule"
            >
              Înapoi la vehicule
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
            <h2 className="text-lg font-semibold">Date vehicul</h2>
            <p className="mt-1 text-sm text-zinc-500">
              Date administrative citite exclusiv prin operația controlată
              dedicată modulului Vehicule.
            </p>
          </div>

          <dl className="mt-5 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <CampDetaliu
              eticheta="Număr înmatriculare"
              valoare={vehicul.numar_inmatriculare}
            />
            <CampDetaliu eticheta="Marcă" valoare={vehicul.marca} />
            <CampDetaliu eticheta="Model" valoare={vehicul.model} />
            <CampDetaliu
              eticheta="An fabricație"
              valoare={vehicul.an_fabricatie}
            />
            <CampDetaliu
              eticheta="Stare"
              valoare={etichetaStare(vehicul.stare)}
            />
            <CampDetaliu eticheta="ID vehicul" valoare={vehicul.id_vehicul} />
          </dl>

          <div className="mt-4 rounded-xl border border-zinc-200 bg-zinc-50 p-4">
            <h3 className="text-xs font-semibold uppercase tracking-wide text-zinc-500">
              Observații
            </h3>
            <p className="mt-2 whitespace-pre-wrap text-sm leading-6 text-zinc-800">
              {vehicul.observatii || "—"}
            </p>
          </div>
        </section>

        <p className="mt-5 text-sm text-zinc-500">
          Modificarea datelor și schimbarea stării vehiculului vor fi
          conectate în etapele următoare.
        </p>
      </section>
    </main>
  );
}