"use client";

import { useEffect, useRef, useState } from "react";

type CampDataRoProps = {
  id: string;
  name: string;
  defaultValue?: string;
  required?: boolean;
};

const ZILE_SAPTAMANA = ["Lu", "Ma", "Mi", "Jo", "Vi", "Sâ", "Du"];

function dataDinRo(valoare: string): Date | null {
  const potrivire = /^(\d{2})\.(\d{2})\.(\d{4})$/.exec(
    valoare.trim(),
  );

  if (!potrivire) {
    return null;
  }

  const zi = Number(potrivire[1]);
  const luna = Number(potrivire[2]);
  const an = Number(potrivire[3]);
  const data = new Date(an, luna - 1, zi);

  if (
    data.getFullYear() !== an ||
    data.getMonth() !== luna - 1 ||
    data.getDate() !== zi
  ) {
    return null;
  }

  return data;
}

function roDinData(data: Date): string {
  const zi = String(data.getDate()).padStart(2, "0");
  const luna = String(data.getMonth() + 1).padStart(2, "0");
  const an = String(data.getFullYear()).padStart(4, "0");

  return `${zi}.${luna}.${an}`;
}

function aceeasiZi(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

function titluLuna(data: Date): string {
  const text = new Intl.DateTimeFormat("ro-RO", {
    month: "long",
    year: "numeric",
  }).format(data);

  return text.charAt(0).toUpperCase() + text.slice(1);
}

export function CampDataRo({
  id,
  name,
  defaultValue = "",
  required = false,
}: CampDataRoProps) {
  const [valoare, setValoare] = useState(defaultValue);
  const [calendarDeschis, setCalendarDeschis] = useState(false);
  const [lunaAfisata, setLunaAfisata] = useState(() => {
    const initiala = dataDinRo(defaultValue) ?? new Date();

    return new Date(initiala.getFullYear(), initiala.getMonth(), 1);
  });
  const containerRef = useRef<HTMLDivElement>(null);

  const dataSelectata = dataDinRo(valoare);
  const azi = new Date();

  const an = lunaAfisata.getFullYear();
  const luna = lunaAfisata.getMonth();
  const primaZi = new Date(an, luna, 1);
  const numarZile = new Date(an, luna + 1, 0).getDate();

  // getDay(): 0 = duminică. Convertim la 0 = luni ... 6 = duminică.
  const decalajLuni = (primaZi.getDay() + 6) % 7;

  useEffect(() => {
    function inchideLaClickExterior(event: MouseEvent) {
      const tinta = event.target;

      if (
        tinta instanceof Node &&
        containerRef.current &&
        !containerRef.current.contains(tinta)
      ) {
        setCalendarDeschis(false);
      }
    }

    function inchideLaEscape(event: KeyboardEvent) {
      if (event.key === "Escape") {
        setCalendarDeschis(false);
      }
    }

    document.addEventListener("mousedown", inchideLaClickExterior);
    document.addEventListener("keydown", inchideLaEscape);

    return () => {
      document.removeEventListener("mousedown", inchideLaClickExterior);
      document.removeEventListener("keydown", inchideLaEscape);
    };
  }, []);

  function deschideCalendarul() {
    const dinCamp = dataDinRo(valoare);
    const baza = dinCamp ?? new Date();

    setLunaAfisata(
      new Date(baza.getFullYear(), baza.getMonth(), 1),
    );
    setCalendarDeschis((deschis) => !deschis);
  }

  function schimbaLuna(delta: number) {
    setLunaAfisata(
      (curenta) =>
        new Date(
          curenta.getFullYear(),
          curenta.getMonth() + delta,
          1,
        ),
    );
  }

  function selecteazaZi(zi: number) {
    const data = new Date(an, luna, zi);

    setValoare(roDinData(data));
    setCalendarDeschis(false);
  }

  function selecteazaAzi() {
    const data = new Date();

    setValoare(roDinData(data));
    setLunaAfisata(
      new Date(data.getFullYear(), data.getMonth(), 1),
    );
    setCalendarDeschis(false);
  }

  return (
    <div className="relative" ref={containerRef}>
      <input
        aria-haspopup="dialog"
        className="w-full rounded-lg border border-zinc-300 px-3 py-2.5 pr-11 text-sm outline-none transition focus:border-zinc-500"
        id={id}
        inputMode="numeric"
        name={name}
        onChange={(event) => setValoare(event.target.value)}
        pattern="[0-9]{2}\.[0-9]{2}\.[0-9]{4}"
        placeholder="zz.ll.aaaa"
        required={required}
        title="Folosește formatul zz.ll.aaaa"
        type="text"
        value={valoare}
      />

      <button
        aria-expanded={calendarDeschis}
        aria-haspopup="dialog"
        aria-label="Alege data din calendar"
        className="absolute right-2 top-[21px] inline-flex h-8 w-8 -translate-y-1/2 items-center justify-center rounded-md text-zinc-500 transition-colors hover:bg-zinc-100 hover:text-zinc-900 focus:outline-none focus:ring-2 focus:ring-zinc-300"
        onClick={deschideCalendarul}
        title="Alege data"
        type="button"
      >
        <svg
          aria-hidden="true"
          className="h-4 w-4"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth="1.8"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="M6.75 3v2.25M17.25 3v2.25M3.75 9h16.5M5.25 5.25h13.5A1.5 1.5 0 0 1 20.25 6.75v12A1.5 1.5 0 0 1 18.75 20.25H5.25a1.5 1.5 0 0 1-1.5-1.5v-12a1.5 1.5 0 0 1 1.5-1.5Z"
          />
        </svg>
      </button>

      {calendarDeschis && (
        <div
          aria-label="Calendar"
          className="absolute right-0 z-50 mt-2 w-[292px] rounded-xl border border-zinc-200 bg-white p-3 shadow-xl"
          role="dialog"
        >
          <div className="flex items-center justify-between gap-2">
            <button
              aria-label="Luna anterioară"
              className="inline-flex h-9 w-9 items-center justify-center rounded-lg text-lg text-zinc-600 transition-colors hover:bg-zinc-100 hover:text-zinc-950"
              onClick={() => schimbaLuna(-1)}
              type="button"
            >
              ‹
            </button>

            <div className="text-sm font-semibold text-zinc-900">
              {titluLuna(lunaAfisata)}
            </div>

            <button
              aria-label="Luna următoare"
              className="inline-flex h-9 w-9 items-center justify-center rounded-lg text-lg text-zinc-600 transition-colors hover:bg-zinc-100 hover:text-zinc-950"
              onClick={() => schimbaLuna(1)}
              type="button"
            >
              ›
            </button>
          </div>

          <div className="mt-2 grid grid-cols-7 gap-1">
            {ZILE_SAPTAMANA.map((zi) => (
              <div
                className="flex h-8 items-center justify-center text-xs font-semibold text-zinc-500"
                key={zi}
              >
                {zi}
              </div>
            ))}

            {Array.from({ length: decalajLuni }, (_, index) => (
              <div
                aria-hidden="true"
                className="h-9"
                key={`gol-${index}`}
              />
            ))}

            {Array.from({ length: numarZile }, (_, index) => {
              const zi = index + 1;
              const data = new Date(an, luna, zi);
              const selectata =
                dataSelectata !== null &&
                aceeasiZi(data, dataSelectata);
              const esteAzi = aceeasiZi(data, azi);

              return (
                <button
                  aria-current={esteAzi ? "date" : undefined}
                  aria-label={new Intl.DateTimeFormat("ro-RO", {
                    day: "numeric",
                    month: "long",
                    year: "numeric",
                  }).format(data)}
                  className={
                    selectata
                      ? "flex h-9 items-center justify-center rounded-lg bg-zinc-900 text-sm font-semibold text-white"
                      : esteAzi
                        ? "flex h-9 items-center justify-center rounded-lg border border-zinc-400 text-sm font-semibold text-zinc-900 hover:bg-zinc-100"
                        : "flex h-9 items-center justify-center rounded-lg text-sm text-zinc-800 transition-colors hover:bg-zinc-100"
                  }
                  key={zi}
                  onClick={() => selecteazaZi(zi)}
                  type="button"
                >
                  {zi}
                </button>
              );
            })}
          </div>

          <div className="mt-3 flex items-center justify-between border-t border-zinc-100 pt-3">
            <span className="text-xs text-zinc-500">
              Săptămâna începe luni
            </span>

            <button
              className="rounded-lg px-3 py-1.5 text-xs font-semibold text-zinc-700 transition-colors hover:bg-zinc-100"
              onClick={selecteazaAzi}
              type="button"
            >
              Astăzi
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
