"use client";

import { useActionState } from "react";

import {
  consultaCnpCursant,
  corecteazaCnpCursant,
  type StareConsultareCnp,
} from "@/app/cont/cursanti/actiuni";

const STARE_INITIALA: StareConsultareCnp = {
  cnp: null,
  eroare: null,
};

export function CnpProtejat({
  idCursant,
}: {
  idCursant: string;
}) {
  const actiuneConsultare =
    consultaCnpCursant.bind(null, idCursant);

  const actiuneCorectare =
    corecteazaCnpCursant.bind(null, idCursant);

  const [stare, formAction, inCurs] = useActionState(
    actiuneConsultare,
    STARE_INITIALA,
  );

  return (
    <section className="mt-6 rounded-2xl border border-amber-200 bg-amber-50 p-6">
      <h2 className="text-lg font-semibold text-amber-950">
        CNP protejat
      </h2>

      <p className="mt-2 max-w-3xl text-sm leading-6 text-amber-900">
        CNP-ul nu face parte din citirea administrativă obișnuită.
        Consultarea și corectarea sunt operații separate și auditate.
      </p>

      <div className="mt-6 grid gap-6 lg:grid-cols-2">
        <div className="rounded-xl border border-amber-200 bg-white p-5">
          <h3 className="font-semibold text-zinc-950">
            Consultare CNP
          </h3>

          <p className="mt-2 text-sm leading-6 text-zinc-600">
            Selectează motivul consultării. Fiecare consultare este
            înregistrată automat în jurnalul de audit.
          </p>

          <form action={formAction} className="mt-4">
            <label
              className="mb-1.5 block text-sm font-medium text-zinc-700"
              htmlFor="motiv-consultare-cnp"
            >
              Motivul consultării
            </label>

            <select
              className="w-full rounded-lg border border-zinc-300 bg-white px-3 py-2.5 text-sm outline-none transition focus:border-zinc-500"
              defaultValue="verificare_documente"
              id="motiv-consultare-cnp"
              name="motiv"
            >
              <option value="verificare_documente">
                Verificare documente
              </option>

              <option value="pregatire_dosar">
                Pregătire dosar
              </option>

              <option value="corectare_date_identificare">
                Corectare date de identificare
              </option>
            </select>

            <button
              className="mt-4 rounded-lg bg-amber-900 px-5 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-amber-800 disabled:cursor-not-allowed disabled:opacity-60"
              disabled={inCurs}
              type="submit"
            >
              {inCurs ? "Se consultă..." : "Consultă CNP"}
            </button>
          </form>

          {stare.eroare && (
            <div
              className="mt-4 rounded-lg border border-red-200 bg-red-50 px-3 py-2.5 text-sm text-red-800"
              role="alert"
            >
              {stare.eroare}
            </div>
          )}

          {stare.cnp && (
            <div
              className="mt-4 rounded-lg border border-amber-300 bg-amber-100 p-4"
              role="status"
            >
              <p className="text-xs font-semibold uppercase tracking-wide text-amber-800">
                CNP consultat
              </p>

              <p className="mt-2 font-mono text-xl font-semibold tracking-wider text-zinc-950">
                {stare.cnp}
              </p>

              <p className="mt-2 text-xs leading-5 text-amber-800">
                Valoarea este afișată numai ca rezultat al acestei
                consultări deliberate. La reîncărcarea sau părăsirea
                paginii nu rămâne afișată.
              </p>
            </div>
          )}
        </div>

        <div className="rounded-xl border border-red-200 bg-white p-5">
          <h3 className="font-semibold text-zinc-950">
            Corectare CNP
          </h3>

          <p className="mt-2 text-sm leading-6 text-zinc-600">
            Folosește această operație numai pentru corectarea unei
            valori greșite. CNP-ul vechi și cel nou nu sunt stocate
            în jurnalul de audit.
          </p>

          <form action={actiuneCorectare} className="mt-4">
            <div>
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-700"
                htmlFor="cnp-nou"
              >
                CNP nou
              </label>

              <input
                autoComplete="off"
                className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 font-mono text-sm outline-none transition focus:border-zinc-500"
                id="cnp-nou"
                inputMode="numeric"
                maxLength={13}
                minLength={13}
                name="cnp_nou"
                pattern="[0-9]{13}"
                required
                type="text"
              />
            </div>

            <div className="mt-4">
              <label
                className="mb-1.5 block text-sm font-medium text-zinc-700"
                htmlFor="confirmare-cnp"
              >
                Confirmă CNP-ul nou
              </label>

              <input
                autoComplete="off"
                className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 font-mono text-sm outline-none transition focus:border-zinc-500"
                id="confirmare-cnp"
                inputMode="numeric"
                maxLength={13}
                minLength={13}
                name="confirmare_cnp"
                pattern="[0-9]{13}"
                required
                type="text"
              />
            </div>

            <p className="mt-3 text-xs leading-5 text-zinc-500">
              Motivul auditat al acestei operații este
              „corectare_date_identificare”.
            </p>

            <button
              className="mt-4 rounded-lg border border-red-300 bg-red-50 px-5 py-2.5 text-sm font-semibold text-red-700 transition-colors hover:bg-red-100"
              type="submit"
            >
              Corectează CNP
            </button>
          </form>
        </div>
      </div>
    </section>
  );
}
