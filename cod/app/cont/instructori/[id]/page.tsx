import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { CampDataRo } from "@/app/cont/_componente/camp-data-ro";
import {
  actualizeazaDatePersonaleInstructor,
  actualizeazaDateProfesionaleInstructor,
  schimbaStareInstructor,
} from "@/app/cont/instructori/actiuni";
import { cereRoluri } from "@/lib/acces/protectie-ruta";
import { citesteDetaliiInstructorAdministrativ } from "@/lib/date/instructori";

export const metadata: Metadata = {
  title: "Detalii instructor | AUTOSTART VANCEA Manager",
};

const FORMAT_UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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

type Parametru = string | string[] | undefined;

function primaValoare(valoare: Parametru) {
  return Array.isArray(valoare) ? valoare[0] : valoare;
}

function mesajSucces(cod: string | undefined) {
  switch (cod) {
    case "instructor_creat":
      return "Instructorul a fost creat cu succes.";
    case "date_personale_actualizate":
      return "Datele personale ale instructorului au fost actualizate.";
    case "date_profesionale_actualizate":
      return "Datele profesionale ale instructorului au fost actualizate.";
    case "instructor_activat":
      return "Instructorul a fost activat cu succes.";
    case "instructor_dezactivat":
      return "Instructorul a fost dezactivat cu succes.";
    default:
      return null;
  }
}

function mesajEroare(cod: string | undefined) {
  switch (cod) {
    case "date_personale_invalide":
      return "Verifică datele personale introduse.";
    case "date_profesionale_invalide":
      return "Verifică data angajării și observațiile introduse.";
    case "actualizare_esuata":
      return "Actualizarea nu a putut fi efectuată.";
    case "tranzitie_stare_refuzata":
      return "Starea instructorului nu poate fi schimbată. Dezactivarea este refuzată dacă există o înscriere activă sau o ședință programată care nu s-a încheiat.";
    case "server":
      return "Operația nu a putut fi finalizată din cauza unei erori.";
    default:
      return null;
  }
}

export default async function PaginaDetaliiInstructor({
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

  const instructor = await citesteDetaliiInstructorAdministrativ(id);

  if (!instructor) {
    notFound();
  }

  const calePanou =
    profil.rol === "administrator"
      ? "/cont/administrator"
      : "/cont/secretariat";

  const succes = mesajSucces(primaValoare(parametri.mesaj));
  const eroare = mesajEroare(primaValoare(parametri.eroare));

  const actiuneDatePersonale =
    actualizeazaDatePersonaleInstructor.bind(null, id);

  const actiuneDateProfesionale =
    actualizeazaDateProfesionaleInstructor.bind(null, id);

  const stareNoua =
    instructor.stare === "activ" ? "inactiv" : "activ";

  const actiuneStare = schimbaStareInstructor.bind(
    null,
    id,
    stareNoua,
  );

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
            <h2 className="text-lg font-semibold">Date personale</h2>

            <p className="mt-1 text-sm text-zinc-500">
              Numele și prenumele sunt obligatorii.
            </p>

            <div className="mt-5 grid gap-4 sm:grid-cols-2">
              <div>
                <label className="mb-1.5 block text-sm font-medium text-zinc-700" htmlFor="nume">
                  Nume *
                </label>
                <input
                  autoComplete="family-name"
                  className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                  defaultValue={instructor.nume}
                  id="nume"
                  maxLength={100}
                  name="nume"
                  required
                  type="text"
                />
              </div>

              <div>
                <label className="mb-1.5 block text-sm font-medium text-zinc-700" htmlFor="prenume">
                  Prenume *
                </label>
                <input
                  autoComplete="given-name"
                  className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                  defaultValue={instructor.prenume}
                  id="prenume"
                  maxLength={100}
                  name="prenume"
                  required
                  type="text"
                />
              </div>

              <div>
                <label className="mb-1.5 block text-sm font-medium text-zinc-700" htmlFor="telefon">
                  Telefon
                </label>
                <input
                  autoComplete="tel"
                  className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                  defaultValue={instructor.telefon ?? ""}
                  id="telefon"
                  maxLength={30}
                  name="telefon"
                  type="tel"
                />
              </div>

              <div>
                <label className="mb-1.5 block text-sm font-medium text-zinc-700" htmlFor="email">
                  E-mail
                </label>
                <input
                  autoComplete="email"
                  className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                  defaultValue={instructor.email ?? ""}
                  id="email"
                  maxLength={254}
                  name="email"
                  type="email"
                />
              </div>

              <div className="sm:col-span-2">
                <label className="mb-1.5 block text-sm font-medium text-zinc-700" htmlFor="data_nasterii">
                  Data nașterii
                </label>
                <CampDataRo
                  defaultValue={
                    instructor.data_nasterii
                      ? formateazaData(instructor.data_nasterii)
                      : ""
                  }
                  id="data_nasterii"
                  name="data_nasterii"
                />
              </div>

              <div className="sm:col-span-2">
                <label className="mb-1.5 block text-sm font-medium text-zinc-700" htmlFor="adresa">
                  Adresă
                </label>
                <textarea
                  className="min-h-24 w-full resize-y rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                  defaultValue={instructor.adresa ?? ""}
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

          <form
            action={actiuneDateProfesionale}
            className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm"
          >
            <h2 className="text-lg font-semibold">Date profesionale</h2>

            <p className="mt-1 text-sm text-zinc-500">
              Datele profesionale sunt administrate separat de datele personale.
            </p>

            <div className="mt-5">
              <label className="mb-1.5 block text-sm font-medium text-zinc-700" htmlFor="data_angajarii">
                Data angajării
              </label>
              <CampDataRo
                defaultValue={
                  instructor.data_angajarii
                    ? formateazaData(instructor.data_angajarii)
                    : ""
                }
                id="data_angajarii"
                name="data_angajarii"
              />
            </div>

            <div className="mt-5">
              <label className="mb-1.5 block text-sm font-medium text-zinc-700" htmlFor="observatii">
                Observații
              </label>
              <textarea
                className="min-h-40 w-full resize-y rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                defaultValue={instructor.observatii ?? ""}
                id="observatii"
                maxLength={2000}
                name="observatii"
              />
            </div>

            <button
              className="mt-5 rounded-lg bg-zinc-900 px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-zinc-700"
              type="submit"
            >
              Salvează datele profesionale
            </button>
          </form>
        </div>
        <section className="mt-6 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h2 className="text-lg font-semibold">
                Stare instructor
              </h2>

              <p className="mt-1 text-sm leading-6 text-zinc-600">
                Stare curentă:{" "}
                <strong>
                  {instructor.stare === "activ" ? "Activ" : "Inactiv"}
                </strong>
                .
              </p>

              {instructor.stare === "activ" ? (
                <p className="mt-2 max-w-2xl text-sm leading-6 text-zinc-500">
                  Dezactivarea este permisă numai dacă instructorul nu are
                  înscrieri active și nu are ședințe programate care nu s-au
                  încheiat.
                </p>
              ) : (
                <p className="mt-2 max-w-2xl text-sm leading-6 text-zinc-500">
                  Activarea face instructorul din nou disponibil pentru
                  operațiile administrative permise de aplicație.
                </p>
              )}
            </div>

            <form action={actiuneStare}>
              <button
                className={
                  instructor.stare === "activ"
                    ? "rounded-lg border border-red-300 bg-white px-5 py-2.5 text-sm font-semibold text-red-700 transition-colors hover:bg-red-50"
                    : "rounded-lg bg-emerald-700 px-5 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-emerald-600"
                }
                type="submit"
              >
                {instructor.stare === "activ"
                  ? "Dezactivează instructorul"
                  : "Activează instructorul"}
              </button>
            </form>
          </div>
        </section>
      </section>
    </main>
  );
}