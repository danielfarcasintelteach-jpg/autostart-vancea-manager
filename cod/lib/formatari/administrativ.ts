export function formateazaDataRo(
  valoare: string | null,
): string {
  if (!valoare) {
    return "—";
  }

  const potrivire = /^(\d{4})-(\d{2})-(\d{2})$/.exec(valoare);

  if (!potrivire) {
    return valoare;
  }

  return `${potrivire[3]}.${potrivire[2]}.${potrivire[1]}`;
}

export function formateazaLei(
  valoare: number,
): string {
  return new Intl.NumberFormat("ro-RO", {
    style: "currency",
    currency: "RON",
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(valoare);
}