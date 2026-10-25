import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";

import { cereRoluri } from "@/lib/acces/protectie-ruta";
import {
  citesteListaCursantiAdministrativ,
  type StareCursant,
} from "@/lib/date/cursanti";

export const metadata: Metadata = {
  title: "Cursanți | AUTOSTART VANCEA Manager",
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

function normalizeazaStare(valoare: ParametruCautare): StareCursant | null {
  const stare = primaValoare(valoare);

  if (stare === "activ" || stare === "inactiv") {
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

function construiesteUrlLista({
  cautare,
  stare,
  pagina,
}: {
  cautare: string;
  stare: StareCursant | null;
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

  return query ? `/cont/cursanti?${query}` : "/cont/cursanti";
}

export default async function PaginaCursanti({
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

  const { cursanti, total } = await citesteListaCursantiAdministrativ({
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
  const ultimulRezultat = Math.min(offset + cursanti.length, total);

  return (
    <main className="flex flex-1 justify-center bg-zinc-50 px-4 py-8 text-zinc-950 sm:px-6 sm:py-12">
      <section className="w-full max-w-6xl">
        <div className="mb-6 flex flex-col gap-4 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="mb-1 text-sm font-semibold tracking-wide text-zinc-500">
              AUTOSTART VANCEA Manager
            </p>

            <h1 className="text-2xl font-semibold">Cursanți</h1>

            <p className="mt-2 max-w-2xl text-sm text-zinc-600">
              Listă administrativă disponibilă pentru administrator și
              secretariat. CNP-ul nu este inclus în această citire.
            </p>
          </div>

          <div className="flex flex-wrap gap-2">
            <Link
              className="inline-flex w-fit rounded-lg bg-zinc-900 px-4 py-2.5 text-sm font-medium text-white transition-colors hover:bg-zinc-700"
              href="/cont/cursanti/nou"
            >
              Adaugă cursant
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
            action="/cont/cursanti"
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
                placeholder="Nume, prenume, telefon sau e-mail"
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
                <option value="activ">Activi</option>
                <option value="inactiv">Inactivi</option>
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
                  href="/cont/cursanti"
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
              <h2 className="font-semibold">Lista cursanților</h2>

              <p className="mt-1 text-sm text-zinc-500">
                {total === 0
                  ? "Nu există rezultate pentru filtrele selectate."
                  : `Afișate ${primulRezultat}-${ultimulRezultat} din ${total}.`}
              </p>
            </div>

            <span className="w-fit rounded-full bg-zinc-100 px-3 py-1 text-sm font-medium text-zinc-700">
              {total} {total === 1 ? "cursant" : "cursanți"}
            </span>
          </div>

          {cursanti.length === 0 ? (
            <div className="px-5 py-12 text-center">
              <p className="font-medium text-zinc-800">
                Niciun cursant găsit
              </p>
              <p className="mt-1 text-sm text-zinc-500">
                Modifică termenul de căutare sau filtrul de stare.
              </p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[760px] border-collapse text-left text-sm">
                <thead className="bg-zinc-50 text-zinc-600">
                  <tr>
                    <th className="px-5 py-3 font-medium">Cursant</th>
                    <th className="px-5 py-3 font-medium">Telefon</th>
                    <th className="px-5 py-3 font-medium">E-mail</th>
                    <th className="px-5 py-3 font-medium">Stare</th>
                  </tr>
                </thead>

                <tbody className="divide-y divide-zinc-100">
                  {cursanti.map((cursant) => (
                    <tr className="hover:bg-zinc-50" key={cursant.id_cursant}>
                      <td className="px-5 py-4">
                        <p className="font-medium text-zinc-950">
                          {cursant.nume} {cursant.prenume}
                        </p>
                        <p className="mt-0.5 text-xs text-zinc-500">
                          ID cursant: {cursant.id_cursant}
                        </p>

                        <Link
                          className="mt-2 inline-flex text-sm font-medium text-zinc-900 underline decoration-zinc-300 underline-offset-4 hover:decoration-zinc-900"
                          href={`/cont/cursanti/${cursant.id_cursant}`}
                        >
                          Vezi detalii
                        </Link>
                      </td>

                      <td className="px-5 py-4 text-zinc-700">
                        {cursant.telefon || "—"}
                      </td>

                      <td className="px-5 py-4 text-zinc-700">
                        {cursant.email || "—"}
                      </td>

                      <td className="px-5 py-4">
                        <span
                          className={
                            cursant.stare === "activ"
                              ? "inline-flex rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-semibold text-emerald-700"
                              : "inline-flex rounded-full bg-zinc-100 px-2.5 py-1 text-xs font-semibold text-zinc-600"
                          }
                        >
                          {cursant.stare === "activ" ? "Activ" : "Inactiv"}
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
          CNP-ul nu este transmis de RPC-ul acestei liste. Consultarea lui
          va folosi separat fluxul auditat validat în Etapa 3.4C.
        </p>
      </section>
    </main>
  );
}
