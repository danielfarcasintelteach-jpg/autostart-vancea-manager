import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { cereRoluri } from "@/lib/acces/protectie-ruta";
import {
  citesteListaVehiculeAdministrativ,
  type StareVehicul,
} from "@/lib/date/vehicule";

export const metadata: Metadata = {
  title: "Vehicule | AUTOSTART VANCEA Manager",
};

const LIMITA_PAGINA = 25;

type ParametruCautare = string | string[] | undefined;

type ParametriPagina = {
  q?: ParametruCautare;
  stare?: ParametruCautare;
  pagina?: ParametruCautare;
};

function primaValoare(valoare: ParametruCautare): string | undefined {
  return Array.isArray(valoare) ? valoare[0] : valoare;
}

function normalizeazaCautare(valoare: ParametruCautare): string {
  return (primaValoare(valoare) ?? "").trim().slice(0, 100);
}

function normalizeazaStare(
  valoare: ParametruCautare,
): StareVehicul | null {
  const stare = primaValoare(valoare);

  if (
    stare === "activ" ||
    stare === "service" ||
    stare === "indisponibil" ||
    stare === "inactiv"
  ) {
    return stare;
  }

  return null;
}

function normalizeazaPagina(valoare: ParametruCautare): number {
  const text = primaValoare(valoare);

  if (!text) {
    return 1;
  }

  const pagina = Number.parseInt(text, 10);

  if (!Number.isSafeInteger(pagina) || pagina < 1) {
    return 1;
  }

  return pagina;
}

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

function construiesteUrlLista({
  cautare,
  stare,
  pagina,
}: {
  cautare: string;
  stare: StareVehicul | null;
  pagina: number;
}) {
  const parametri = new URLSearchParams();

  if (cautare) {
    parametri.set("q", cautare);
  }

  if (stare) {
    parametri.set("stare", stare);
  }

  if (pagina > 1) {
    parametri.set("pagina", String(pagina));
  }

  const query = parametri.toString();

  return query ? `/cont/vehicule?${query}` : "/cont/vehicule";
}

export default async function PaginaVehicule({
  searchParams,
}: {
  searchParams: Promise<ParametriPagina>;
}) {
  const profil = await cereRoluri("administrator", "secretariat");
  const parametri = await searchParams;

  const cautare = normalizeazaCautare(parametri.q);
  const stare = normalizeazaStare(parametri.stare);
  const paginaCeruta = normalizeazaPagina(parametri.pagina);
  const offset = (paginaCeruta - 1) * LIMITA_PAGINA;

  const { vehicule, total } =
    await citesteListaVehiculeAdministrativ({
      cautare: cautare || null,
      stare,
      limita: LIMITA_PAGINA,
      offset,
    });

  const totalPagini = Math.max(1, Math.ceil(total / LIMITA_PAGINA));

  if (paginaCeruta > totalPagini) {
    redirect(
      construiesteUrlLista({
        cautare,
        stare,
        pagina: totalPagini,
      }),
    );
  }

  const calePanou =
    profil.rol === "administrator"
      ? "/cont/administrator"
      : "/cont/secretariat";

  const primulRezultat = total === 0 ? 0 : offset + 1;
  const ultimulRezultat = Math.min(offset + vehicule.length, total);

  return (
    <main className="flex flex-1 justify-center bg-zinc-50 px-4 py-8 text-zinc-950 sm:px-6 sm:py-12">
      <section className="w-full max-w-6xl">
        <div className="mb-6 flex flex-col gap-4 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="mb-1 text-sm font-semibold tracking-wide text-zinc-500">
              AUTOSTART VANCEA Manager
            </p>

            <h1 className="text-2xl font-semibold">Vehicule</h1>

            <p className="mt-2 max-w-2xl text-sm text-zinc-600">
              Listă administrativă disponibilă pentru administrator și
              secretariat, prin citirea controlată dedicată.
            </p>
          </div>

          <Link
            className="inline-flex w-fit rounded-lg border border-zinc-300 bg-white px-4 py-2.5 text-sm font-medium text-zinc-800 transition-colors hover:bg-zinc-100"
            href={calePanou}
          >
            Înapoi la panou
          </Link>
        </div>

        <div className="mb-6 rounded-2xl border border-zinc-200 bg-white p-5 shadow-sm">
          <form
            action="/cont/vehicule"
            className="grid gap-4 md:grid-cols-[minmax(0,1fr)_220px_auto]"
            method="get"
          >
            <div>
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-800"
                htmlFor="q"
              >
                Caută
              </label>

              <input
                className="w-full rounded-lg border border-zinc-300 bg-white px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                defaultValue={cautare}
                id="q"
                maxLength={100}
                name="q"
                placeholder="Număr, marcă sau model"
                type="search"
              />
            </div>

            <div>
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-800"
                htmlFor="stare"
              >
                Stare
              </label>

              <select
                className="w-full rounded-lg border border-zinc-300 bg-white px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                defaultValue={stare ?? ""}
                id="stare"
                name="stare"
              >
                <option value="">Toate</option>
                <option value="activ">Active</option>
                <option value="service">Service</option>
                <option value="indisponibil">Indisponibile</option>
                <option value="inactiv">Inactive</option>
              </select>
            </div>

            <div className="flex items-end gap-2">
              <button
                className="rounded-lg bg-zinc-900 px-4 py-2.5 text-sm font-medium text-white transition-colors hover:bg-zinc-700"
                type="submit"
              >
                Filtrează
              </button>

              {(cautare || stare) && (
                <Link
                  className="rounded-lg border border-zinc-300 bg-white px-4 py-2.5 text-sm font-medium text-zinc-700 transition-colors hover:bg-zinc-100"
                  href="/cont/vehicule"
                >
                  Resetează
                </Link>
              )}
            </div>
          </form>
        </div>

        <div className="overflow-hidden rounded-2xl border border-zinc-200 bg-white shadow-sm">
          <div className="flex flex-col gap-2 border-b border-zinc-200 px-5 py-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h2 className="font-semibold">Lista vehiculelor</h2>

              <p className="mt-1 text-sm text-zinc-500">
                {total === 0
                  ? "Nu există rezultate pentru filtrele selectate."
                  : `Afișate ${primulRezultat}-${ultimulRezultat} din ${total}.`}
              </p>
            </div>

            <span className="w-fit rounded-full bg-zinc-100 px-3 py-1 text-sm font-medium text-zinc-700">
              {total} {total === 1 ? "vehicul" : "vehicule"}
            </span>
          </div>

          {vehicule.length === 0 ? (
            <div className="px-5 py-12 text-center">
              <p className="font-medium text-zinc-800">
                Niciun vehicul găsit
              </p>
              <p className="mt-1 text-sm text-zinc-500">
                Modifică termenul de căutare sau filtrul de stare.
              </p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[800px] border-collapse text-left text-sm">
                <thead className="bg-zinc-50 text-zinc-600">
                  <tr>
                    <th className="px-5 py-3 font-medium">
                      Număr înmatriculare
                    </th>
                    <th className="px-5 py-3 font-medium">Marcă</th>
                    <th className="px-5 py-3 font-medium">Model</th>
                    <th className="px-5 py-3 font-medium">An</th>
                    <th className="px-5 py-3 font-medium">Stare</th>
                  </tr>
                </thead>

                <tbody className="divide-y divide-zinc-100">
                  {vehicule.map((vehicul) => (
                    <tr
                      className="hover:bg-zinc-50"
                      key={vehicul.id_vehicul}
                    >
                      <td className="px-5 py-4">
                        <p className="font-semibold text-zinc-950">
                          {vehicul.numar_inmatriculare}
                        </p>

                        <Link
                          className="mt-2 inline-flex text-sm font-medium text-zinc-900 underline decoration-zinc-300 underline-offset-4 hover:decoration-zinc-900"
                          href={`/cont/vehicule/${vehicul.id_vehicul}`}
                        >
                          Vezi detalii
                        </Link>
                      </td>

                      <td className="px-5 py-4 text-zinc-700">
                        {vehicul.marca}
                      </td>

                      <td className="px-5 py-4 text-zinc-700">
                        {vehicul.model}
                      </td>

                      <td className="px-5 py-4 text-zinc-700">
                        {vehicul.an_fabricatie ?? "—"}
                      </td>

                      <td className="px-5 py-4">
                        <span className={clasaStare(vehicul.stare)}>
                          {etichetaStare(vehicul.stare)}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {totalPagini > 1 && (
            <div className="flex items-center justify-between border-t border-zinc-200 px-5 py-4">
              <p className="text-sm text-zinc-500">
                Pagina {paginaCeruta} din {totalPagini}
              </p>

              <div className="flex gap-2">
                {paginaCeruta > 1 && (
                  <Link
                    className="rounded-lg border border-zinc-300 px-3 py-2 text-sm font-medium text-zinc-700 hover:bg-zinc-100"
                    href={construiesteUrlLista({
                      cautare,
                      stare,
                      pagina: paginaCeruta - 1,
                    })}
                  >
                    Anterioară
                  </Link>
                )}

                {paginaCeruta < totalPagini && (
                  <Link
                    className="rounded-lg border border-zinc-300 px-3 py-2 text-sm font-medium text-zinc-700 hover:bg-zinc-100"
                    href={construiesteUrlLista({
                      cautare,
                      stare,
                      pagina: paginaCeruta + 1,
                    })}
                  >
                    Următoarea
                  </Link>
                )}
              </div>
            </div>
          )}
        </div>

        <p className="mt-5 text-sm text-zinc-500">
          În Etapa 5E1 modulul oferă citire administrativă controlată.
          Crearea, modificarea și schimbarea stării vor fi conectate separat.
        </p>
      </section>
    </main>
  );
}