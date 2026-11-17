import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import {
  actualizeazaVehicul,
  schimbaStareVehicul,
} from "@/app/cont/vehicule/actiuni";
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

type Parametru = string | string[] | undefined;

function primaValoare(valoare: Parametru) {
  return Array.isArray(valoare) ? valoare[0] : valoare;
}

function mesajSucces(cod: string | undefined) {
  switch (cod) {
    case "vehicul_creat":
      return "Vehiculul a fost creat cu succes.";
    case "vehicul_actualizat":
      return "Datele vehiculului au fost actualizate cu succes.";
    case "stare_actualizata":
      return "Starea vehiculului a fost actualizată cu succes.";
    default:
      return null;
  }
}
function mesajEroare(cod: string | undefined) {
  switch (cod) {
    case "date_invalide":
      return "Verifică datele introduse. Numărul de înmatriculare, marca și modelul sunt obligatorii. Numărul poate conține numai litere și cifre, iar anul fabricației trebuie să fie minimum 1900.";
    case "numar_existent":
      return "Există deja un alt vehicul cu acest număr de înmatriculare.";
    case "actualizare_esuata":
      return "Actualizarea vehiculului nu a putut fi efectuată.";
    case "stare_invalida":
      return "Starea selectată nu este validă.";
    case "tranzitie_stare_nepermisa":
      return "Schimbarea stării nu este permisă. Vehiculul poate avea o ședință activă sau programată ori starea selectată poate fi deja cea curentă.";
    case "schimbare_stare_esuata":
      return "Starea vehiculului nu a putut fi actualizată.";
    case "server":
      return "Operația nu a putut fi finalizată din cauza unei erori.";
    default:
      return null;
  }
}

export default async function PaginaDetaliiVehicul({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{
    mesaj?: Parametru;
    eroare?: Parametru;
  }>;
}) {
  const profil = await cereRoluri("administrator", "secretariat");
  const { id } = await params;
  const parametri = await searchParams;

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

  const succes = mesajSucces(primaValoare(parametri.mesaj));
  const eroare = mesajEroare(primaValoare(parametri.eroare));
  const actiuneActualizare = actualizeazaVehicul.bind(null, id);
  const actiuneSchimbareStare = schimbaStareVehicul.bind(null, id);

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

        {succes && (
          <div
            className="mb-6 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800"
            role="status"
          >
            {succes}
          </div>
        )}

        {eroare && (
          <div
            className="mb-6 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800"
            role="alert"
          >
            {eroare}
          </div>
        )}

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

        <section className="mt-6 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
          <div>
            <h2 className="text-lg font-semibold">
              Schimbă starea vehiculului
            </h2>

            <p className="mt-1 text-sm text-zinc-500">
              Starea se modifică separat de datele vehiculului. Baza de date
              blochează trecerea la o stare diferită de Activ atunci când
              există ședințe active sau programate.
            </p>
          </div>

          <div className="mt-4 flex flex-wrap items-center gap-2">
            <span className="text-sm text-zinc-600">
              Starea curentă:
            </span>

            <span className={clasaStare(vehicul.stare)}>
              {etichetaStare(vehicul.stare)}
            </span>
          </div>

          <form
            action={actiuneSchimbareStare}
            className="mt-5 flex flex-wrap gap-2"
          >
            {(
              [
                ["activ", "Activ"],
                ["service", "Service"],
                ["indisponibil", "Indisponibil"],
                ["inactiv", "Inactiv"],
              ] as const
            )
              .filter(([stare]) => stare !== vehicul.stare)
              .map(([stare, eticheta]) => (
                <button
                  className="rounded-lg border border-zinc-300 bg-white px-4 py-2.5 text-sm font-medium text-zinc-800 transition-colors hover:bg-zinc-100"
                  key={stare}
                  name="stare"
                  type="submit"
                  value={stare}
                >
                  Marchează {eticheta.toLowerCase()}
                </button>
              ))}
          </form>
        </section>
        <form
          action={actiuneActualizare}
          className="mt-6 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm"
        >
          <div>
            <h2 className="text-lg font-semibold">
              Modifică datele vehiculului
            </h2>

            <p className="mt-1 text-sm text-zinc-500">
              Modificarea este realizată prin operația server-side controlată.
              Starea vehiculului se administrează separat.
            </p>
          </div>

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
                defaultValue={vehicul.numar_inmatriculare}
                id="numar_inmatriculare"
                maxLength={20}
                name="numar_inmatriculare"
                pattern="[A-Za-z0-9]+"
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
                defaultValue={vehicul.an_fabricatie ?? ""}
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
                defaultValue={vehicul.marca}
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
                defaultValue={vehicul.model}
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
                defaultValue={vehicul.observatii ?? ""}
                id="observatii"
                maxLength={2000}
                name="observatii"
              />
            </div>
          </div>

          <button
            className="mt-6 rounded-lg bg-zinc-900 px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-zinc-700"
            type="submit"
          >
            Salvează modificările
          </button>
        </form>

        <p className="mt-5 text-sm text-zinc-500">
          Citirea, crearea, modificarea și schimbarea stării vehiculelor
          folosesc operații server-side controlate.
        </p>
      </section>
    </main>
  );
}