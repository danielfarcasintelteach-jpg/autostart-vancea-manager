import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { cereRoluri } from "@/lib/acces/protectie-ruta";
import {
  citesteListaProgramariAdministrativ,
  type StareProgramare,
} from "@/lib/date/programari";

export const metadata: Metadata = {
  title: "Programări | AUTOSTART VANCEA Manager",
};

const LIMITA_PAGINA = 25;

type Parametru = string | string[] | undefined;

type ParametriPagina = {
  q?: Parametru;
  stare?: Parametru;
  data?: Parametru;
  pagina?: Parametru;
};

function primaValoare(
  valoare: Parametru,
): string | undefined {
  return Array.isArray(valoare)
    ? valoare[0]
    : valoare;
}

function normalizeazaCautare(
  valoare: Parametru,
): string {
  return (primaValoare(valoare) ?? "")
    .trim()
    .slice(0, 100);
}

function normalizeazaStare(
  valoare: Parametru,
): StareProgramare | null {
  const stare = primaValoare(valoare);

  if (
    stare === "programata" ||
    stare === "finalizata" ||
    stare === "anulata" ||
    stare === "absent"
  ) {
    return stare;
  }

  return null;
}

function normalizeazaData(
  valoare: Parametru,
): string {
  const data = (primaValoare(valoare) ?? "").trim();

  return /^\d{2}\/\d{2}\/\d{4}$/.test(data)
    ? data
    : "";
}

function transformaDataRoInIso(
  valoare: string,
): string | null {
  const potrivire =
    /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(valoare);

  if (!potrivire) {
    return null;
  }

  const zi = Number(potrivire[1]);
  const luna = Number(potrivire[2]);
  const an = Number(potrivire[3]);

  const verificare = new Date(
    Date.UTC(an, luna - 1, zi),
  );

  if (
    verificare.getUTCFullYear() !== an ||
    verificare.getUTCMonth() !== luna - 1 ||
    verificare.getUTCDate() !== zi
  ) {
    return null;
  }

  return `${potrivire[3]}-${potrivire[2]}-${potrivire[1]}`;
}

function normalizeazaPagina(
  valoare: Parametru,
): number {
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

function construiesteUrlLista({
  cautare,
  stare,
  data,
  pagina,
}: {
  cautare: string;
  stare: StareProgramare | null;
  data: string | null;
  pagina: number;
}) {
  const parametri = new URLSearchParams();

  if (cautare) {
    parametri.set("q", cautare);
  }

  if (stare) {
    parametri.set("stare", stare);
  }

  if (data) {
    parametri.set("data", data);
  }

  if (pagina > 1) {
    parametri.set("pagina", String(pagina));
  }

  const query = parametri.toString();

  return query
    ? `/cont/programari?${query}`
    : "/cont/programari";
}

export default async function PaginaProgramari({
  searchParams,
}: {
  searchParams: Promise<ParametriPagina>;
}) {
  const profil = await cereRoluri(
    "administrator",
    "secretariat",
  );

  const parametri = await searchParams;

  const cautare = normalizeazaCautare(parametri.q);
  const stare = normalizeazaStare(parametri.stare);
  const data = normalizeazaData(parametri.data);
  const dataPentruRpc = transformaDataRoInIso(data);
  const paginaCeruta = normalizeazaPagina(
    parametri.pagina,
  );

  const offset =
    (paginaCeruta - 1) * LIMITA_PAGINA;

  const { programari, total } =
    await citesteListaProgramariAdministrativ({
      cautare: cautare || null,
      stare,
      data: dataPentruRpc,
      limita: LIMITA_PAGINA,
      offset,
    });

  const totalPagini = Math.max(
    1,
    Math.ceil(total / LIMITA_PAGINA),
  );

  if (paginaCeruta > totalPagini) {
    redirect(
      construiesteUrlLista({
        cautare,
        stare,
        data,
        pagina: totalPagini,
      }),
    );
  }

  const calePanou =
    profil.rol === "administrator"
      ? "/cont/administrator"
      : "/cont/secretariat";

  const primulRezultat =
    total === 0 ? 0 : offset + 1;

  const ultimulRezultat = Math.min(
    offset + programari.length,
    total,
  );

  return (
    <main className="flex flex-1 justify-center bg-zinc-50 px-4 py-8 text-zinc-950 sm:px-6 sm:py-12">
      <section className="w-full max-w-7xl">
        <div className="mb-6 flex flex-col gap-4 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="mb-1 text-sm font-semibold tracking-wide text-zinc-500">
              AUTOSTART VANCEA Manager
            </p>

            <h1 className="text-2xl font-semibold">
              Programări
            </h1>

            <p className="mt-2 max-w-2xl text-sm text-zinc-600">
              Evidența administrativă a ședințelor practice de 90 de minute.
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
            action="/cont/programari"
            className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_200px_180px_auto]"
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
                placeholder="Cursant, instructor sau vehicul"
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
                <option value="programata">
                  Programate
                </option>
                <option value="finalizata">
                  Finalizate
                </option>
                <option value="anulata">
                  Anulate
                </option>
                <option value="absent">
                  Absent
                </option>
              </select>
            </div>

            <div>
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-800"
                htmlFor="data"
              >
                Data
              </label>

              <input
                className="w-full rounded-lg border border-zinc-300 bg-white px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                autoComplete="off"
                defaultValue={data}
                id="data"
                inputMode="numeric"
                maxLength={10}
                name="data"
                pattern="\d{2}/\d{2}/\d{4}"
                placeholder="dd/mm/yyyy"
                type="text"
              />
            </div>

            <div className="flex items-end gap-2">
              <button
                className="rounded-lg bg-zinc-900 px-4 py-2.5 text-sm font-medium text-white transition-colors hover:bg-zinc-700"
                type="submit"
              >
                Filtrează
              </button>

              {(cautare || stare || data) && (
                <Link
                  className="rounded-lg border border-zinc-300 bg-white px-4 py-2.5 text-sm font-medium text-zinc-700 transition-colors hover:bg-zinc-100"
                  href="/cont/programari"
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
              <h2 className="font-semibold">
                Lista programărilor
              </h2>

              <p className="mt-1 text-sm text-zinc-500">
                {total === 0
                  ? "Nu există rezultate pentru filtrele selectate."
                  : `Afișate ${primulRezultat}-${ultimulRezultat} din ${total}.`}
              </p>
            </div>

            <span className="w-fit rounded-full bg-zinc-100 px-3 py-1 text-sm font-medium text-zinc-700">
              {total}{" "}
              {total === 1
                ? "programare"
                : "programări"}
            </span>
          </div>

          {programari.length === 0 ? (
            <div className="px-5 py-12 text-center">
              <p className="font-medium text-zinc-800">
                Nicio programare găsită
              </p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[1150px] border-collapse text-left text-sm">
                <thead className="bg-zinc-50 text-zinc-600">
                  <tr>
                    <th className="px-5 py-3 font-medium">
                      Cursant
                    </th>
                    <th className="px-5 py-3 font-medium">
                      Instructor
                    </th>
                    <th className="px-5 py-3 font-medium">
                      Vehicul
                    </th>
                    <th className="px-5 py-3 font-medium">
                      Început
                    </th>
                    <th className="px-5 py-3 font-medium">
                      Sfârșit
                    </th>
                    <th className="px-5 py-3 font-medium">
                      Stare
                    </th>
                  </tr>
                </thead>

                <tbody className="divide-y divide-zinc-100">
                  {programari.map((programare) => (
                    <tr
                      className="hover:bg-zinc-50"
                      key={programare.id_programare}
                    >
                      <td className="px-5 py-4">
                        <p className="font-semibold text-zinc-950">
                          {programare.cursant_nume}{" "}
                          {programare.cursant_prenume}
                        </p>

                        <Link
                          className="mt-2 inline-flex text-sm font-medium text-zinc-900 underline decoration-zinc-300 underline-offset-4 hover:decoration-zinc-900"
                          href={`/cont/programari/${programare.id_programare}`}
                        >
                          Vezi detalii
                        </Link>
                      </td>

                      <td className="px-5 py-4 text-zinc-700">
                        {programare.instructor_nume}{" "}
                        {programare.instructor_prenume}
                      </td>

                      <td className="px-5 py-4 text-zinc-700">
                        <p className="font-medium text-zinc-900">
                          {programare.numar_inmatriculare}
                        </p>
                        <p className="mt-1 text-xs text-zinc-500">
                          {programare.marca}{" "}
                          {programare.model}
                        </p>
                      </td>

                      <td className="px-5 py-4 text-zinc-700">
                        {formateazaDataOraRo(
                          programare.inceput,
                        )}
                      </td>

                      <td className="px-5 py-4 text-zinc-700">
                        {formateazaDataOraRo(
                          programare.sfarsit,
                        )}
                      </td>

                      <td className="px-5 py-4">
                        <span
                          className={clasaStare(
                            programare.stare,
                          )}
                        >
                          {etichetaStare(
                            programare.stare,
                          )}
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
                Pagina {paginaCeruta} din{" "}
                {totalPagini}
              </p>

              <div className="flex gap-2">
                {paginaCeruta > 1 && (
                  <Link
                    className="rounded-lg border border-zinc-300 px-3 py-2 text-sm font-medium text-zinc-700 hover:bg-zinc-100"
                    href={construiesteUrlLista({
                      cautare,
                      stare,
                      data,
                      pagina:
                        paginaCeruta - 1,
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
                      data,
                      pagina:
                        paginaCeruta + 1,
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
          În Etapa 5G1 este disponibilă citirea administrativă
          controlată a programărilor.
        </p>
      </section>
    </main>
  );
}