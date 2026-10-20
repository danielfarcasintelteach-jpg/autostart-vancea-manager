"use client";

import { useActionState } from "react";

import { autentifica, type StareAutentificare } from "./actiuni";

const stareInitiala: StareAutentificare = { eroare: null };

export function FormularAutentificare() {
  const [stare, actiune, inCurs] = useActionState(autentifica, stareInitiala);

  return (
    <form action={actiune} className="flex flex-col gap-5">
      <div className="flex flex-col gap-2">
        <label className="text-sm font-medium" htmlFor="email">
          E-mail
        </label>
        <input
          autoComplete="email"
          className="rounded-lg border border-zinc-300 bg-white px-3 py-2.5 text-zinc-950 outline-none focus:border-zinc-700 focus:ring-2 focus:ring-zinc-200"
          id="email"
          maxLength={254}
          name="email"
          required
          type="email"
        />
      </div>

      <div className="flex flex-col gap-2">
        <label className="text-sm font-medium" htmlFor="parola">
          Parolă
        </label>
        <input
          autoComplete="current-password"
          className="rounded-lg border border-zinc-300 bg-white px-3 py-2.5 text-zinc-950 outline-none focus:border-zinc-700 focus:ring-2 focus:ring-zinc-200"
          id="parola"
          name="parola"
          required
          type="password"
        />
      </div>

      {stare.eroare && (
        <p aria-live="polite" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-800" role="alert">
          {stare.eroare}
        </p>
      )}

      <button
        className="rounded-lg bg-zinc-900 px-4 py-2.5 font-medium text-white transition-colors hover:bg-zinc-700 disabled:cursor-wait disabled:opacity-60"
        disabled={inCurs}
        type="submit"
      >
        {inCurs ? "Se autentifică…" : "Autentifică-te"}
      </button>
    </form>
  );
}
