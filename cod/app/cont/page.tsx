import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { creeazaClientServer } from "@/lib/supabase/server";

import { deconecteaza } from "./actiuni";

export const metadata: Metadata = {
  title: "Cont | AUTOSTART VANCEA Manager",
};

export default async function PaginaCont({
  searchParams,
}: {
  searchParams: Promise<{ deconectare?: string }>;
}) {
  const supabase = await creeazaClientServer();
  const verificare = await supabase.auth.getClaims().catch(() => null);

  if (!verificare?.data?.claims?.sub || verificare.error) {
    redirect("/autentificare");
  }

  const { deconectare } = await searchParams;

  return (
    <main className="flex flex-1 items-center justify-center bg-zinc-50 px-4 py-12 text-zinc-950">
      <section className="w-full max-w-md rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm sm:p-8">
        <p className="mb-2 text-sm font-semibold tracking-wide text-zinc-500">
          AUTOSTART VANCEA Manager
        </p>
        <h1 className="mb-3 text-2xl font-semibold">Cont</h1>
        <p className="mb-6 text-sm text-zinc-600">
          Sesiunea ta Supabase Auth este verificată. Funcțiile contului vor fi adăugate în etapele următoare.
        </p>

        {deconectare === "eroare" && (
          <p className="mb-5 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-800" role="alert">
            Deconectarea nu a reușit. Încearcă din nou.
          </p>
        )}

        <form action={deconecteaza}>
          <button
            className="rounded-lg bg-zinc-900 px-4 py-2.5 font-medium text-white transition-colors hover:bg-zinc-700"
            type="submit"
          >
            Deconectează-te
          </button>
        </form>
      </section>
    </main>
  );
}
