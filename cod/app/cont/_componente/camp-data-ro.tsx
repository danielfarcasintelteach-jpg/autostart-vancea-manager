"use client";

import { useRef, useState } from "react";

type CampDataRoProps = {
  id: string;
  name: string;
  defaultValue?: string;
  required?: boolean;
};

function roDinIso(valoare: string): string {
  const potrivire = /^(\d{4})-(\d{2})-(\d{2})$/.exec(valoare);

  if (!potrivire) {
    return "";
  }

  return `${potrivire[3]}.${potrivire[2]}.${potrivire[1]}`;
}

function isoDinRo(valoare: string): string {
  const potrivire = /^(\d{2})\.(\d{2})\.(\d{4})$/.exec(valoare.trim());

  if (!potrivire) {
    return "";
  }

  const zi = Number(potrivire[1]);
  const luna = Number(potrivire[2]);
  const an = Number(potrivire[3]);
  const data = new Date(Date.UTC(an, luna - 1, zi));

  if (
    data.getUTCFullYear() !== an ||
    data.getUTCMonth() !== luna - 1 ||
    data.getUTCDate() !== zi
  ) {
    return "";
  }

  return `${String(an).padStart(4, "0")}-${String(luna).padStart(2, "0")}-${String(zi).padStart(2, "0")}`;
}

export function CampDataRo({
  id,
  name,
  defaultValue = "",
  required = false,
}: CampDataRoProps) {
  const [valoare, setValoare] = useState(defaultValue);
  const calendarRef = useRef<HTMLInputElement>(null);
  const valoareIso = isoDinRo(valoare);

  function deschideCalendarul() {
    const calendar = calendarRef.current;

    if (!calendar) {
      return;
    }

    if (typeof calendar.showPicker === "function") {
      calendar.showPicker();
      return;
    }

    calendar.focus();
    calendar.click();
  }

  return (
    <div className="relative">
      <input
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
        aria-label="Alege data din calendar"
        className="absolute right-2 top-1/2 inline-flex h-8 w-8 -translate-y-1/2 items-center justify-center rounded-md text-zinc-500 transition-colors hover:bg-zinc-100 hover:text-zinc-900 focus:outline-none focus:ring-2 focus:ring-zinc-300"
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

      <input
        aria-hidden="true"
        className="pointer-events-none absolute right-0 top-full h-px w-px opacity-0"
        onChange={(event) => {
          const dataRo = roDinIso(event.target.value);

          if (dataRo) {
            setValoare(dataRo);
          }
        }}
        ref={calendarRef}
        tabIndex={-1}
        type="date"
        value={valoareIso}
      />
    </div>
  );
}
