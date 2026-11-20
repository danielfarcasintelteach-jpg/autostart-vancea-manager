import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { cereRoluri } from "@/lib/acces/protectie-ruta";
import {
  citesteListaInscrieriAdministrativ,
  type StareInscriere,
} from "@/lib/date/inscrieri";
import {
  formateazaDataRo,
  formateazaLei,
} from "@/lib/formatari/administrativ";

export const metadata: Metadata = {
  title: "Înscrieri | AUTOSTART VANCEA Manager",
};

const LIMITA_PAGINA = 25;

type ParametruCautare = string | string[] | undefined;

type ParametriPagina = {
  q?: ParametruCautare;
  stare?: ParametruCautare;
  pagina?: ParametruCautare;
};

function primaValoare(
  valoare: ParametruCautare,
): string | undefined {
  return Array.isArray(valoare) ? valoare[0] : valoare;
}

function normalizeazaCautare(
  valoare: ParametruCautare,
): string {
  return (primaValoare(valoare) ?? "")
    .trim()
    .slice(0, 100);
}

function normalizeazaStare(
  valoare: ParametruCautare,
): StareInscriere | null {
  const stare = primaValoare(valoare);

  if (
    stare === "activa" ||
    stare === "finalizata" ||
    stare === "anulata"
  ) {
    return stare;
  }

  return null;
}

function normalizeazaPagina(
  valoare: ParametruCautare,
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
  stare: StareInscriere,
): string {
  switch (stare) {
    case "activa":
      return "Activă";
    case "finalizata":
      return "Finalizată";
    case "anulata":
      return "Anulată";
  }
}

function clasaStare(
  stare: StareInscriere,
): string {
  switch (stare) {
    case "activa":
      return "inline-flex rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-semibold text-emerald-700";
    case "finalizata":
      return "inline-flex rounded-full bg-blue-50 px-2.5 py-1 text-xs font-semibold text-blue-700";
    case "anulata":
      return "inline-flex rounded-full bg-zinc-100 px-2.5 py-1 text-xs font-semibold text-zinc-600";
  }
}

function construiesteUrlLista({
  cautare,
  stare,
  pagina,
}: {
  cautare: string;
  stare: StareInscriere | null;
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

  return query
    ? `/cont/inscrieri?${query}`
    : "/cont/inscrieri";
}

export default async function PaginaInscrieri({
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
  const paginaCeruta = normalizeazaPagina(
    parametri.pagina,
  );

  const offset =
    (paginaCeruta - 1) * LIMITA_PAGINA;

  const { inscrieri, total } =
    await citesteListaInscrieriAdministrativ({
      cautare: cautare || null,
      stare,
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
    offset + inscrieri.length,
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
              Înscrieri
            </h1>

            <p className="mt-2 max-w-2xl text-sm text-zinc-600">
              Evidența administrativă a înscrierilor la
              categoria B, disponibilă pentru administrator
              și secretariat prin citire controlată.
            </p>
          </div>

          <div className="flex flex-wrap gap-2">
            <Link
              className="inline-flex w-fit rounded-lg bg-zinc-900 px-4 py-2.5 text-sm font-medium text-white transition-colors hover:bg-zinc-700"
              href="/cont/inscrieri/nou"
            >
              Înscriere nouă
            </Link>

            <Link
              className="inline-flex w-fit rounded-lg border border-zinc-300 bg-white px-4 py-2.5 text-sm font-medium text-zinc-800 transition-colors hover:bg-zinc-100"
              href={calePanou}
            >
              Înapoi la panou
            </Link>
          </div>
        </div>

        <div className="mb-6 rounded-2xl border border-zinc-200 bg-white p-5 shadow-sm">
          <form
            action="/cont/inscrieri"
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
                placeholder="Nume cursant sau instructor"
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
                <option value="activa">Active</option>
                <option value="finalizata">
                  Finalizate
                </option>
                <option value="anulata">
                  Anulate
                </option>
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
                  href="/cont/inscrieri"
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
                Lista înscrierilor
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
                ? "înscriere"
                : "înscrieri"}
            </span>
          </div>

          {inscrieri.length === 0 ? (
            <div className="px-5 py-12 text-center">
              <p className="font-medium text-zinc-800">
                Nicio înscriere găsită
              </p>

              <p className="mt-1 text-sm text-zinc-500">
                Modifică termenul de căutare sau
                filtrul de stare.
              </p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[1000px] border-collapse text-left text-sm">
                <thead className="bg-zinc-50 text-zinc-600">
                  <tr>
                    <th className="px-5 py-3 font-medium">
                      Cursant
                    </th>
                    <th className="px-5 py-3 font-medium">
                      Instructor
                    </th>
                    <th className="px-5 py-3 font-medium">
                      Categoria
                    </th>
                    <th className="px-5 py-3 font-medium">
                      Data înscrierii
                    </th>
                    <th className="px-5 py-3 font-medium">
                      Tarif
                    </th>
                    <th className="px-5 py-3 font-medium">
                      Stare
                    </th>
                  </tr>
                </thead>

                <tbody className="divide-y divide-zinc-100">
                  {inscrieri.map((inscriere) => (
                    <tr
                      className="hover:bg-zinc-50"
                      key={inscriere.id_inscriere}
                    >
                      <td className="px-5 py-4">
                        <p className="font-semibold text-zinc-950">
                          {inscriere.cursant_nume}{" "}
                          {inscriere.cursant_prenume}
                        </p>

                        <Link
                          className="mt-2 inline-flex text-sm font-medium text-zinc-900 underline decoration-zinc-300 underline-offset-4 hover:decoration-zinc-900"
                          href={`/cont/inscrieri/${inscriere.id_inscriere}`}
                        >
                          Vezi detalii
                        </Link>
                      </td>

                      <td className="px-5 py-4 text-zinc-700">
                        {inscriere.instructor_nume}{" "}
                        {inscriere.instructor_prenume}
                      </td>

                      <td className="px-5 py-4 text-zinc-700">
                        {inscriere.categorie}
                      </td>

                      <td className="px-5 py-4 text-zinc-700">
                        {formateazaDataRo(
                          inscriere.data_inscrierii,
                        )}
                      </td>

                      <td className="px-5 py-4 font-medium text-zinc-800">
                        {formateazaLei(
                          Number(inscriere.tarif_curs),
                        )}
                      </td>

                      <td className="px-5 py-4">
                        <span
                          className={clasaStare(
                            inscriere.stare,
                          )}
                        >
                          {etichetaStare(
                            inscriere.stare,
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
          În Etapa 5F2 citirea și crearea înscrierilor sunt
          disponibile prin operații controlate. Modificarea
          și schimbarea stării vor fi conectate separat.
        </p>
      </section>
    </main>
  );
}