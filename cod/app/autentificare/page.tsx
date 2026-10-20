import type { Metadata } from "next";

import { FormularAutentificare } from "./formular";

export const metadata: Metadata = {
  title: "Autentificare | AUTOSTART VANCEA Manager",
};

export default function PaginaAutentificare() {
  return (
    <main className="flex flex-1 items-center justify-center bg-zinc-50 px-4 py-12 text-zinc-950">
      <section className="w-full max-w-md rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm sm:p-8">
        <p className="mb-2 text-sm font-semibold tracking-wide text-zinc-500">
          AUTOSTART VANCEA Manager
        </p>
        <h1 className="mb-2 text-2xl font-semibold">Autentificare</h1>
        <p className="mb-8 text-sm text-zinc-600">
          Introdu e-mailul și parola contului tău existent.
        </p>
        <FormularAutentificare />
      </section>
    </main>
  );
}
