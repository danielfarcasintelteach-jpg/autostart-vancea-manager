import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import {
  actualizeazaInscriere,
  realocaInstructorInscriere,
} from "@/app/cont/inscrieri/actiuni";
import { cereRoluri } from "@/lib/acces/protectie-ruta";
import {
  citesteDetaliiInscriereAdministrativ,
  type StareInscriere,
} from "@/lib/date/inscrieri";
import { citesteListaInstructoriAdministrativ } from "@/lib/date/instructori";
import {
  formateazaDataRo,
  formateazaLei,
} from "@/lib/formatari/administrativ";

export const metadata: Metadata = {
  title: "Detalii înscriere | AUTOSTART VANCEA Manager",
};

const FORMAT_UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type Parametru = string | string[] | undefined;

function primaValoare(
  valoare: Parametru,
): string | undefined {
  return Array.isArray(valoare)
    ? valoare[0]
    : valoare;
}

function mesajSucces(
  cod: string | undefined,
): string | null {
  switch (cod) {
    case "inscriere_creata":
      return "Înscrierea a fost creată cu succes.";
    case "inscriere_actualizata":
      return "Tariful și observațiile înscrierii au fost actualizate.";
    case "instructor_realocat":
      return "Instructorul a fost realocat cu succes.";
    case "fara_modificari":
      return "Nu au existat modificări de salvat.";
    default:
      return null;
  }
}

function mesajEroare(
  cod: string | undefined,
): string | null {
  switch (cod) {
    case "date_invalide":
      return "Verifică tariful și observațiile introduse.";
    case "inscriere_inactiva":
      return "Înscrierea nu mai este activă și nu poate fi modificată.";
    case "modificare_refuzata":
      return "Modificarea a fost refuzată. Tariful nu mai poate fi schimbat după înregistrarea primei plăți.";
    case "instructor_invalid":
      return "Selectează un instructor valid.";
    case "resursa_inexistenta":
      return "Înscrierea, cursantul sau instructorul selectat nu mai există.";
    case "realocare_refuzata":
      return "Realocarea instructorului a fost refuzată. Verifică dacă înscrierea este activă, dacă noul instructor este diferit și activ și dacă nu există ședințe programate în desfășurare sau viitoare.";
    case "server":
      return "Operația nu a putut fi finalizată din cauza unei erori.";
    default:
      return null;
  }
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
        {valoare === null || valoare === ""
          ? "—"
          : valoare}
      </dd>
    </div>
  );
}

export default async function PaginaDetaliiInscriere({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{
    mesaj?: Parametru;
    eroare?: Parametru;
  }>;
}) {
  const profil = await cereRoluri(
    "administrator",
    "secretariat",
  );

  const { id } = await params;
  const parametri = await searchParams;

  if (!FORMAT_UUID.test(id)) {
    notFound();
  }

  const inscriere =
    await citesteDetaliiInscriereAdministrativ(id);

  if (!inscriere) {
    notFound();
  }

  const rezultatInstructori =
    inscriere.stare === "activa"
      ? await citesteListaInstructoriAdministrativ({
          stare: "activ",
          limita: 100,
          offset: 0,
        })
      : {
          instructori: [],
          total: 0,
        };

  const instructoriAlternativi =
    rezultatInstructori.instructori.filter(
      (instructor) =>
        instructor.id_instructor !==
        inscriere.id_instructor,
    );

  const calePanou =
    profil.rol === "administrator"
      ? "/cont/administrator"
      : "/cont/secretariat";

  const numeCursant =
    `${inscriere.cursant_nume} ${inscriere.cursant_prenume}`;

  const numeInstructor =
    `${inscriere.instructor_nume} ${inscriere.instructor_prenume}`;

  const succes = mesajSucces(
    primaValoare(parametri.mesaj),
  );

  const eroare = mesajEroare(
    primaValoare(parametri.eroare),
  );

  const actiuneActualizare =
    actualizeazaInscriere.bind(null, id);

  const actiuneRealocare =
    realocaInstructorInscriere.bind(null, id);

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
              {formateazaDataRo(
                inscriere.data_inscrierii,
              )}
            </p>

            <div className="mt-3">
              <span
                className={clasaStare(
                  inscriere.stare,
                )}
              >
                {etichetaStare(
                  inscriere.stare,
                )}
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
            <h2 className="text-lg font-semibold">
              Date înscriere
            </h2>

            <p className="mt-1 text-sm text-zinc-500">
              Date administrative citite prin
              operația controlată dedicată
              modulului Înscrieri.
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
                Number(
                  inscriere.tarif_curs,
                ),
              )}
            />

            <CampDetaliu
              eticheta="Stare"
              valoare={etichetaStare(
                inscriere.stare,
              )}
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

        {inscriere.stare === "activa" && (
          <div className="mt-6 grid gap-6 lg:grid-cols-2">
            <form
              action={actiuneActualizare}
              className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm"
            >
              <h2 className="text-lg font-semibold">
                Modifică înscrierea
              </h2>

              <p className="mt-1 text-sm leading-6 text-zinc-500">
                Poți modifica tariful și observațiile.
                Tariful nu mai poate fi schimbat după
                înregistrarea primei plăți.
              </p>

              <div className="mt-5">
                <label
                  className="mb-1.5 block text-sm font-medium text-zinc-700"
                  htmlFor="tarif_curs"
                >
                  Tarif curs *
                </label>

                <div className="relative">
                  <input
                    className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 pr-16 text-sm outline-none transition focus:border-zinc-500"
                    defaultValue={Number(
                      inscriere.tarif_curs,
                    ).toFixed(2)}
                    id="tarif_curs"
                    inputMode="decimal"
                    max="9999999999.99"
                    min="0.01"
                    name="tarif_curs"
                    required
                    step="0.01"
                    type="number"
                  />

                  <span className="pointer-events-none absolute inset-y-0 right-3 flex items-center text-sm text-zinc-500">
                    RON
                  </span>
                </div>
              </div>

              <div className="mt-5">
                <label
                  className="mb-1.5 block text-sm font-medium text-zinc-700"
                  htmlFor="observatii"
                >
                  Observații
                </label>

                <textarea
                  className="min-h-36 w-full resize-y rounded-lg border border-zinc-300 px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
                  defaultValue={
                    inscriere.observatii ?? ""
                  }
                  id="observatii"
                  maxLength={2000}
                  name="observatii"
                />
              </div>

              <button
                className="mt-5 rounded-lg bg-zinc-900 px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-zinc-700"
                type="submit"
              >
                Salvează modificările
              </button>
            </form>

            <form
              action={actiuneRealocare}
              className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm"
            >
              <h2 className="text-lg font-semibold">
                Realocare instructor
              </h2>

              <p className="mt-1 text-sm leading-6 text-zinc-500">
                Instructor curent:{" "}
                <strong>{numeInstructor}</strong>.
                Realocarea este permisă numai către
                un alt instructor activ și dacă nu
                există ședințe programate în
                desfășurare sau viitoare.
              </p>

              <div className="mt-5">
                <label
                  className="mb-1.5 block text-sm font-medium text-zinc-700"
                  htmlFor="id_instructor_nou"
                >
                  Instructor nou *
                </label>

                <select
                  className="w-full rounded-lg border border-zinc-300 bg-white px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500 disabled:bg-zinc-100"
                  disabled={
                    instructoriAlternativi.length ===
                    0
                  }
                  id="id_instructor_nou"
                  name="id_instructor_nou"
                  required
                >
                  <option value="">
                    Selectează instructorul
                  </option>

                  {instructoriAlternativi.map(
                    (instructor) => (
                      <option
                        key={
                          instructor.id_instructor
                        }
                        value={
                          instructor.id_instructor
                        }
                      >
                        {instructor.nume}{" "}
                        {instructor.prenume}
                      </option>
                    ),
                  )}
                </select>
              </div>

              {instructoriAlternativi.length ===
              0 ? (
                <p className="mt-3 text-sm text-amber-700">
                  Nu există un alt instructor activ
                  disponibil pentru realocare.
                </p>
              ) : (
                <button
                  className="mt-5 rounded-lg border border-zinc-300 bg-white px-5 py-2.5 text-sm font-semibold text-zinc-800 transition-colors hover:bg-zinc-100"
                  type="submit"
                >
                  Realocă instructorul
                </button>
              )}
            </form>
          </div>
        )}

        {inscriere.stare !== "activa" && (
          <div className="mt-6 rounded-xl border border-zinc-200 bg-zinc-100 px-4 py-3 text-sm text-zinc-700">
            Înscrierea nu mai este activă.
            Modificarea tarifului, observațiilor și
            realocarea instructorului sunt blocate.
          </div>
        )}

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
          În Etapa 5F3 citirea, crearea,
          modificarea și realocarea instructorului
          sunt disponibile prin operații
          controlate. Schimbarea stării înscrierii
          va fi conectată separat.
        </p>
      </section>
    </main>
  );
}