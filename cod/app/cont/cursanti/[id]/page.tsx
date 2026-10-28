import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { CampDataRo } from "@/app/cont/_componente/camp-data-ro";

import {
  actualizeazaDatePersonaleCursant,
  actualizeazaObservatiiCursant,
  schimbaStareCursant,
} from "@/app/cont/cursanti/actiuni";
import { CnpProtejat } from "@/app/cont/cursanti/_componente/cnp-protejat";
import { cereRoluri } from "@/lib/acces/protectie-ruta";
import { citesteDetaliiCursantAdministrativ } from "@/lib/date/cursanti";

export const metadata: Metadata = {
  title: "Detalii cursant | AUTOSTART VANCEA Manager",
};

const FORMAT_UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type Parametru = string | string[] | undefined;

function primaValoare(valoare: Parametru) {
  return Array.isArray(valoare) ? valoare[0] : valoare;
}

function afiseazaValoare(
  valoare: string | null,
  fallback = "Nespecificat",
) {
  const text = valoare?.trim();

  return text ? text : fallback;
}

function formateazaData(valoare: string | null) {
  if (!valoare) {
    return "Nespecificată";
  }

  const componente = valoare.split("-");

  if (componente.length !== 3) {
    return valoare;
  }

  const [an, luna, zi] = componente;

  return `${zi}.${luna}.${an}`;
}

function mesajSucces(cod: string | undefined) {
  switch (cod) {
    case "cursant_creat":
      return "Cursantul a fost creat cu succes.";
    case "date_actualizate":
      return "Datele personale au fost actualizate.";
    case "observatii_actualizate":
      return "Observațiile au fost actualizate.";
    case "stare_actualizata":
      return "Starea cursantului a fost actualizată.";
    case "cnp_corectat":
      return "CNP-ul a fost corectat prin fluxul auditat.";
    default:
      return null;
  }
}

function mesajEroare(cod: string | undefined) {
  switch (cod) {
    case "date_personale_invalide":
      return "Verifică datele personale introduse.";
    case "observatii_invalide":
      return "Observațiile introduse nu sunt valide.";
    case "actualizare_esuat":
      return "Actualizarea nu a putut fi efectuată.";
    case "tranzitie_blocata":
      return "Cursantul nu poate fi trecut în starea Inactiv cât timp are o înscriere activă sau o ședință viitoare programată.";
    case "server":
      return "Operația nu a putut fi finalizată din cauza unei erori.";
    case "cnp_invalid":
      return "CNP-ul nou trebuie să conțină exact 13 cifre.";
    case "cnp_neconfirmat":
      return "Cele două valori CNP introduse nu coincid.";
    case "cnp_existent":
      return "CNP-ul introdus este deja utilizat de alt cursant.";
    case "cnp_neschimbat":
      return "CNP-ul introdus este identic cu valoarea deja înregistrată.";
    case "cnp_corectare_esuat":
      return "CNP-ul nu a putut fi corectat.";
    default:
      return null;
  }
}

export default async function PaginaDetaliiCursant({
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

  const cursant = await citesteDetaliiCursantAdministrativ(id);

  if (!cursant) {
    notFound();
  }

  const succes = mesajSucces(primaValoare(parametri.mesaj));
  const eroare = mesajEroare(primaValoare(parametri.eroare));

  const calePanou =
    profil.rol === "administrator"
      ? "/cont/administrator"
      : "/cont/secretariat";

  const actiuneDatePersonale =
    actualizeazaDatePersonaleCursant.bind(null, id);

  const actiuneObservatii =
    actualizeazaObservatiiCursant.bind(null, id);

  const stareNoua =
    cursant.stare === "activ" ? "inactiv" : "activ";

  const actiuneStare =
    schimbaStareCursant.bind(null, id, stareNoua);

  return (
    <main className="flex flex-1 justify-center bg-zinc-50 px-4 py-8 text-zinc-950 sm:px-6 sm:py-12">
      <section className="w-full max-w-5xl">
        <div className="mb-6 flex flex-col gap-4 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="mb-1 text-sm font-semibold tracking-wide text-zinc-500">
              AUTOSTART VANCEA Manager
            </p>

            <h1 className="text-2xl font-semibold">
              {cursant.nume} {cursant.prenume}
            </h1>

            <div className="mt-3 flex flex-wrap items-center gap-2">
              <span
                className={
                  cursant.stare === "activ"
                    ? "inline-flex rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-semibold text-emerald-700"
                    : "inline-flex rounded-full bg-zinc-100 px-2.5 py-1 text-xs font-semibold text-zinc-600"
                }
              >
                {cursant.stare === "activ" ? "Activ" : "Inactiv"}
              </span>

              <span className="text-xs text-zinc-500">
                ID cursant: {cursant.id_cursant}
              </span>
            </div>
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

        <div className="grid gap-6 lg:grid-cols-2">
          <form
            action={actiuneDatePersonale}
            className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm"
          >
            <div className="flex items-start justify-between gap-4">
              <div>
                <h2 className="text-lg font-semibold">
                  Date personale
                </h2>

                <p className="mt-1 text-sm text-zinc-500">
                  Modificările sunt salvate prin operația server-side
                  controlată.
                </p>
              </div>
            </div>

            <div className="mt-5 grid gap-4 sm:grid-cols-2">
              <div>
                <label
                  className="mb-1.5 block text-sm font-medium text-zinc-700"
                  htmlFor="nume"
                >
                  Nume *
                </label>

                <input
                  autoComplete="family-name"
                  className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                  defaultValue={cursant.nume}
                  id="nume"
                  maxLength={100}
                  name="nume"
                  required
                  type="text"
                />
              </div>

              <div>
                <label
                  className="mb-1.5 block text-sm font-medium text-zinc-700"
                  htmlFor="prenume"
                >
                  Prenume *
                </label>

                <input
                  autoComplete="given-name"
                  className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                  defaultValue={cursant.prenume}
                  id="prenume"
                  maxLength={100}
                  name="prenume"
                  required
                  type="text"
                />
              </div>

              <div>
                <label
                  className="mb-1.5 block text-sm font-medium text-zinc-700"
                  htmlFor="telefon"
                >
                  Telefon
                </label>

                <input
                  autoComplete="tel"
                  className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                  defaultValue={cursant.telefon ?? ""}
                  id="telefon"
                  maxLength={30}
                  name="telefon"
                  type="tel"
                />
              </div>

              <div>
                <label
                  className="mb-1.5 block text-sm font-medium text-zinc-700"
                  htmlFor="email"
                >
                  E-mail
                </label>

                <input
                  autoComplete="email"
                  className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                  defaultValue={cursant.email ?? ""}
                  id="email"
                  maxLength={254}
                  name="email"
                  type="email"
                />
              </div>

              <div className="sm:col-span-2">
                <label
                  className="mb-1.5 block text-sm font-medium text-zinc-700"
                  htmlFor="data_nasterii"
                >
                  Data nașterii
                </label>

                              <CampDataRo
                defaultValue={
                  cursant.data_nasterii
                    ? formateazaData(cursant.data_nasterii)
                    : ""
                }
                id="data_nasterii"
                name="data_nasterii"
              />
              </div>

              <div className="sm:col-span-2">
                <label
                  className="mb-1.5 block text-sm font-medium text-zinc-700"
                  htmlFor="adresa"
                >
                  Adresă
                </label>

                <textarea
                  className="min-h-24 w-full resize-y rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                  defaultValue={cursant.adresa ?? ""}
                  id="adresa"
                  maxLength={1000}
                  name="adresa"
                />
              </div>
            </div>

            <button
              className="mt-5 rounded-lg bg-zinc-900 px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-zinc-700"
              type="submit"
            >
              Salvează datele personale
            </button>
          </form>

          <section className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
            <h2 className="text-lg font-semibold">
              Contact și stare
            </h2>

            <dl className="mt-5 divide-y divide-zinc-100">
              <div className="grid gap-1 py-3 sm:grid-cols-[160px_1fr]">
                <dt className="text-sm font-medium text-zinc-500">
                  Telefon
                </dt>
                <dd className="text-sm text-zinc-900">
                  {afiseazaValoare(cursant.telefon)}
                </dd>
              </div>

              <div className="grid gap-1 py-3 sm:grid-cols-[160px_1fr]">
                <dt className="text-sm font-medium text-zinc-500">
                  E-mail
                </dt>
                <dd className="break-all text-sm text-zinc-900">
                  {afiseazaValoare(cursant.email)}
                </dd>
              </div>

              <div className="grid gap-1 py-3 sm:grid-cols-[160px_1fr]">
                <dt className="text-sm font-medium text-zinc-500">
                  Data nașterii
                </dt>
                <dd className="text-sm text-zinc-900">
                  {formateazaData(cursant.data_nasterii)}
                </dd>
              </div>

              <div className="grid gap-1 py-3 sm:grid-cols-[160px_1fr]">
                <dt className="text-sm font-medium text-zinc-500">
                  Stare cursant
                </dt>
                <dd className="text-sm text-zinc-900">
                  {cursant.stare === "activ" ? "Activ" : "Inactiv"}
                </dd>
              </div>

              <div className="grid gap-1 py-3 sm:grid-cols-[160px_1fr]">
                <dt className="text-sm font-medium text-zinc-500">
                  ID persoană
                </dt>
                <dd className="break-all text-sm text-zinc-900">
                  {cursant.id_persoana}
                </dd>
              </div>
            </dl>

            <div className="mt-5 border-t border-zinc-200 pt-5">
              <h3 className="text-sm font-semibold text-zinc-900">
                Administrare stare
              </h3>

              <p className="mt-2 text-sm leading-6 text-zinc-600">
                {cursant.stare === "activ"
                  ? "Dezactivarea este permisă numai dacă acest cursant nu are o înscriere activă și nici o ședință viitoare programată."
                  : "Reactivarea readuce cursantul în starea Activ."}
              </p>

              <form action={actiuneStare} className="mt-4">
                <button
                  className={
                    cursant.stare === "activ"
                      ? "rounded-lg border border-red-300 bg-red-50 px-5 py-2.5 text-sm font-semibold text-red-700 transition-colors hover:bg-red-100"
                      : "rounded-lg border border-emerald-300 bg-emerald-50 px-5 py-2.5 text-sm font-semibold text-emerald-700 transition-colors hover:bg-emerald-100"
                  }
                  type="submit"
                >
                  {cursant.stare === "activ"
                    ? "Trece în Inactiv"
                    : "Reactivează cursantul"}
                </button>
              </form>
            </div>
          </section>
        </div>

        <form
          action={actiuneObservatii}
          className="mt-6 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm"
        >
          <h2 className="text-lg font-semibold">
            Observații
          </h2>

          <p className="mt-1 text-sm text-zinc-500">
            Observațiile sunt administrate separat de datele personale.
          </p>

          <textarea
            className="mt-4 min-h-32 w-full resize-y rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
            defaultValue={cursant.observatii ?? ""}
            maxLength={2000}
            name="observatii"
          />

          <button
            className="mt-4 rounded-lg bg-zinc-900 px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-zinc-700"
            type="submit"
          >
            Salvează observațiile
          </button>
        </form>

        <CnpProtejat idCursant={id} />
      </section>
    </main>
  );
}
