import Link from "next/link";

export default function CursantNegasit() {
  return (
    <main className="flex flex-1 items-center justify-center bg-zinc-50 px-4 py-12 text-zinc-950">
      <section className="w-full max-w-lg rounded-2xl border border-zinc-200 bg-white p-8 text-center shadow-sm">
        <p className="text-sm font-semibold tracking-wide text-zinc-500">
          AUTOSTART VANCEA Manager
        </p>

        <h1 className="mt-2 text-2xl font-semibold">
          Cursant negăsit
        </h1>

        <p className="mt-3 text-sm leading-6 text-zinc-600">
          Identificatorul nu corespunde unui cursant disponibil.
        </p>

        <Link
          className="mt-6 inline-flex rounded-lg bg-zinc-900 px-4 py-2.5 text-sm font-medium text-white transition-colors hover:bg-zinc-700"
          href="/cont/cursanti"
        >
          Înapoi la lista cursanților
        </Link>
      </section>
    </main>
  );
}
