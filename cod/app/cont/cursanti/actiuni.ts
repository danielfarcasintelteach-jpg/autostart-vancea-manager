"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { verificaRoluriServer } from "@/lib/acces/autorizare";
import { caleContPentruRol } from "@/lib/acces/roluri";
import { citesteDetaliiCursantAdministrativ } from "@/lib/date/cursanti";
import { creeazaClientServer } from "@/lib/supabase/server";

const FORMAT_UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const FORMAT_CNP = /^[0-9]{13}$/;

function citesteText(
  formData: FormData,
  numeCamp: string,
): string | null {
  const valoare = formData.get(numeCamp);

  if (typeof valoare !== "string") {
    return null;
  }

  return valoare.trim();
}

function citesteTextOptional(
  formData: FormData,
  numeCamp: string,
  limita: number,
): string | null | undefined {
  const valoare = formData.get(numeCamp);

  if (typeof valoare !== "string") {
    return undefined;
  }

  const text = valoare.trim();

  if (!text) {
    return null;
  }

  if (text.length > limita) {
    return undefined;
  }

  return text;
}

function citesteDataOptionala(
  formData: FormData,
  numeCamp: string,
): string | null | undefined {
  const valoare = citesteText(formData, numeCamp);

  if (valoare === null) {
    return undefined;
  }

  if (!valoare) {
    return null;
  }

  const potrivire = /^(\d{2})\.(\d{2})\.(\d{4})$/.exec(valoare);

  if (!potrivire) {
    return undefined;
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
    return undefined;
  }

  const anIso = String(an).padStart(4, "0");
  const lunaIso = String(luna).padStart(2, "0");
  const ziIso = String(zi).padStart(2, "0");

  return `${anIso}-${lunaIso}-${ziIso}`;
}

function emailValid(email: string | null): boolean {
  if (email === null) {
    return true;
  }

  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

async function cereAccesAdministrativ() {
  const acces = await verificaRoluriServer(
    "administrator",
    "secretariat",
  );

  if (acces.autorizat) {
    return;
  }

  if (acces.motiv === "neautentificat") {
    redirect("/autentificare");
  }

  if (acces.motiv === "neactivat") {
    redirect("/acces-neactivat");
  }

  if (acces.motiv === "interzis") {
    redirect(caleContPentruRol(acces.rol));
  }

  redirect("/cont");
}

function caleDetalii(
  idCursant: string,
  parametru?: string,
): string {
  const baza = `/cont/cursanti/${idCursant}`;

  return parametru ? `${baza}?${parametru}` : baza;
}

export async function creeazaCursant(
  formData: FormData,
) {
  await cereAccesAdministrativ();

  const nume = citesteText(formData, "nume");
  const prenume = citesteText(formData, "prenume");
  const telefon = citesteTextOptional(formData, "telefon", 30);
  const email = citesteTextOptional(formData, "email", 254);
  const dataNasterii = citesteDataOptionala(
    formData,
    "data_nasterii",
  );
  const adresa = citesteTextOptional(formData, "adresa", 1000);
  const cnp = citesteText(formData, "cnp");
  const observatii = citesteTextOptional(
    formData,
    "observatii",
    2000,
  );

  if (
    !nume ||
    nume.length > 100 ||
    !prenume ||
    prenume.length > 100 ||
    telefon === undefined ||
    email === undefined ||
    !emailValid(email) ||
    dataNasterii === undefined ||
    adresa === undefined ||
    !cnp ||
    !FORMAT_CNP.test(cnp) ||
    observatii === undefined
  ) {
    redirect("/cont/cursanti/nou?eroare=date_invalide");
  }

  const supabase = await creeazaClientServer();

  let rezultat;

  try {
    rezultat = await supabase.rpc("creare_cursant", {
      p_nume: nume,
      p_prenume: prenume,
      p_telefon: telefon,
      p_email: email,
      p_data_nasterii: dataNasterii,
      p_adresa: adresa,
      p_cnp: cnp,
      p_observatii: observatii,
    });
  } catch {
    redirect("/cont/cursanti/nou?eroare=server");
  }

  if (rezultat.error) {
    if (rezultat.error.code === "23505") {
      redirect("/cont/cursanti/nou?eroare=cnp_existent");
    }

    if (rezultat.error.code === "PZ001") {
      redirect("/cont");
    }

    redirect("/cont/cursanti/nou?eroare=server");
  }

  const idCursant =
    typeof rezultat.data === "string"
      ? rezultat.data
      : null;

  if (!idCursant || !FORMAT_UUID.test(idCursant)) {
    redirect("/cont/cursanti/nou?eroare=server");
  }

  revalidatePath("/cont/cursanti");

  redirect(
    caleDetalii(
      idCursant,
      "mesaj=cursant_creat",
    ),
  );
}

export async function actualizeazaDatePersonaleCursant(
  idCursant: string,
  formData: FormData,
) {
  await cereAccesAdministrativ();

  if (!FORMAT_UUID.test(idCursant)) {
    redirect("/cont/cursanti");
  }

  const nume = citesteText(formData, "nume");
  const prenume = citesteText(formData, "prenume");
  const telefon = citesteTextOptional(formData, "telefon", 30);
  const email = citesteTextOptional(formData, "email", 254);
  const dataNasterii = citesteDataOptionala(
    formData,
    "data_nasterii",
  );
  const adresa = citesteTextOptional(formData, "adresa", 1000);

  if (
    !nume ||
    nume.length > 100 ||
    !prenume ||
    prenume.length > 100 ||
    telefon === undefined ||
    email === undefined ||
    !emailValid(email) ||
    dataNasterii === undefined ||
    adresa === undefined
  ) {
    redirect(
      caleDetalii(
        idCursant,
        "eroare=date_personale_invalide",
      ),
    );
  }

  let cursant;

  try {
    cursant = await citesteDetaliiCursantAdministrativ(
      idCursant,
    );
  } catch {
    redirect(
      caleDetalii(
        idCursant,
        "eroare=server",
      ),
    );
  }

  if (!cursant) {
    redirect("/cont/cursanti?eroare=cursant_inexistent");
  }

  const supabase = await creeazaClientServer();

  let rezultat;

  try {
    rezultat = await supabase.rpc("modifica_persoana", {
      p_id_persoana: cursant.id_persoana,
      p_modificari: {
        nume,
        prenume,
        telefon,
        email,
        data_nasterii: dataNasterii,
        adresa,
      },
    });
  } catch {
    redirect(
      caleDetalii(
        idCursant,
        "eroare=server",
      ),
    );
  }

  if (rezultat.error) {
    if (rezultat.error.code === "PZ001") {
      redirect("/cont");
    }

    if (rezultat.error.code === "PZ002") {
      redirect("/cont/cursanti?eroare=cursant_inexistent");
    }

    redirect(
      caleDetalii(
        idCursant,
        "eroare=actualizare_esuat",
      ),
    );
  }

  revalidatePath("/cont/cursanti");
  revalidatePath(`/cont/cursanti/${idCursant}`);

  redirect(
    caleDetalii(
      idCursant,
      "mesaj=date_actualizate",
    ),
  );
}

export async function actualizeazaObservatiiCursant(
  idCursant: string,
  formData: FormData,
) {
  await cereAccesAdministrativ();

  if (!FORMAT_UUID.test(idCursant)) {
    redirect("/cont/cursanti");
  }

  const observatii = citesteTextOptional(
    formData,
    "observatii",
    2000,
  );

  if (observatii === undefined) {
    redirect(
      caleDetalii(
        idCursant,
        "eroare=observatii_invalide",
      ),
    );
  }

  const supabase = await creeazaClientServer();

  let rezultat;

  try {
    rezultat = await supabase.rpc("modifica_cursant", {
      p_id_cursant: idCursant,
      p_modificari: {
        observatii,
      },
    });
  } catch {
    redirect(
      caleDetalii(
        idCursant,
        "eroare=server",
      ),
    );
  }

  if (rezultat.error) {
    if (rezultat.error.code === "PZ001") {
      redirect("/cont");
    }

    if (rezultat.error.code === "PZ002") {
      redirect("/cont/cursanti?eroare=cursant_inexistent");
    }

    redirect(
      caleDetalii(
        idCursant,
        "eroare=actualizare_esuat",
      ),
    );
  }

  revalidatePath(`/cont/cursanti/${idCursant}`);

  redirect(
    caleDetalii(
      idCursant,
      "mesaj=observatii_actualizate",
    ),
  );
}

export async function schimbaStareCursant(
  idCursant: string,
  stareNoua: "activ" | "inactiv",
) {
  await cereAccesAdministrativ();

  if (
    !FORMAT_UUID.test(idCursant) ||
    !["activ", "inactiv"].includes(stareNoua)
  ) {
    redirect("/cont/cursanti");
  }

  const supabase = await creeazaClientServer();

  let rezultat;

  try {
    rezultat = await supabase.rpc("schimba_stare_cursant", {
      p_id_cursant: idCursant,
      p_stare: stareNoua,
    });
  } catch {
    redirect(
      caleDetalii(
        idCursant,
        "eroare=server",
      ),
    );
  }

  if (rezultat.error) {
    if (rezultat.error.code === "PZ001") {
      redirect("/cont");
    }

    if (rezultat.error.code === "PZ002") {
      redirect("/cont/cursanti?eroare=cursant_inexistent");
    }

    if (rezultat.error.code === "PZ003") {
      redirect(
        caleDetalii(
          idCursant,
          "eroare=tranzitie_blocata",
        ),
      );
    }

    redirect(
      caleDetalii(
        idCursant,
        "eroare=actualizare_esuat",
      ),
    );
  }

  revalidatePath("/cont/cursanti");
  revalidatePath(`/cont/cursanti/${idCursant}`);

  redirect(
    caleDetalii(
      idCursant,
      "mesaj=stare_actualizata",
    ),
  );
}
export type StareConsultareCnp = {
  cnp: string | null;
  eroare: string | null;
};

const MOTIVE_CONSULTARE_CNP = new Set([
  "verificare_documente",
  "pregatire_dosar",
  "corectare_date_identificare",
]);

export async function consultaCnpCursant(
  idCursant: string,
  _stareAnterioara: StareConsultareCnp,
  formData: FormData,
): Promise<StareConsultareCnp> {
  await cereAccesAdministrativ();

  if (!FORMAT_UUID.test(idCursant)) {
    return {
      cnp: null,
      eroare: "Cursant invalid.",
    };
  }

  const motiv = citesteText(formData, "motiv");

  if (!motiv || !MOTIVE_CONSULTARE_CNP.has(motiv)) {
    return {
      cnp: null,
      eroare: "Selectează un motiv valid pentru consultare.",
    };
  }

  const supabase = await creeazaClientServer();

  let rezultat;

  try {
    rezultat = await supabase.rpc("consulta_cnp", {
      p_id_cursant: idCursant,
      p_motiv: motiv,
    });
  } catch {
    return {
      cnp: null,
      eroare: "CNP-ul nu a putut fi consultat.",
    };
  }

  if (rezultat.error) {
    if (rezultat.error.code === "PZ002") {
      return {
        cnp: null,
        eroare: "Cursantul nu mai există.",
      };
    }

    if (rezultat.error.code === "PZ003") {
      return {
        cnp: null,
        eroare: "Motivul consultării nu este valid.",
      };
    }

    return {
      cnp: null,
      eroare: "CNP-ul nu a putut fi consultat.",
    };
  }

  const cnp =
    typeof rezultat.data === "string"
      ? rezultat.data
      : null;

  if (!cnp || !FORMAT_CNP.test(cnp)) {
    return {
      cnp: null,
      eroare: "Valoarea CNP returnată nu este validă.",
    };
  }

  return {
    cnp,
    eroare: null,
  };
}

export async function corecteazaCnpCursant(
  idCursant: string,
  formData: FormData,
): Promise<void> {
  await cereAccesAdministrativ();

  if (!FORMAT_UUID.test(idCursant)) {
    redirect("/cont/cursanti");
  }

  const cnpNou = citesteText(formData, "cnp_nou");
  const confirmareCnp = citesteText(
    formData,
    "confirmare_cnp",
  );

  if (!cnpNou || !FORMAT_CNP.test(cnpNou)) {
    redirect(
      caleDetalii(
        idCursant,
        "eroare=cnp_invalid",
      ),
    );
  }

  if (confirmareCnp !== cnpNou) {
    redirect(
      caleDetalii(
        idCursant,
        "eroare=cnp_neconfirmat",
      ),
    );
  }

  const supabase = await creeazaClientServer();

  let rezultat;

  try {
    rezultat = await supabase.rpc("corecteaza_cnp", {
      p_id_cursant: idCursant,
      p_cnp_nou: cnpNou,
      p_motiv: "corectare_date_identificare",
    });
  } catch {
    redirect(
      caleDetalii(
        idCursant,
        "eroare=cnp_corectare_esuat",
      ),
    );
  }

  if (rezultat.error) {
    if (rezultat.error.code === "PZ001") {
      redirect("/cont");
    }

    if (rezultat.error.code === "PZ002") {
      redirect(
        "/cont/cursanti?eroare=cursant_inexistent",
      );
    }

    if (rezultat.error.code === "23505") {
      redirect(
        caleDetalii(
          idCursant,
          "eroare=cnp_existent",
        ),
      );
    }

    if (rezultat.error.code === "PZ003") {
      redirect(
        caleDetalii(
          idCursant,
          "eroare=cnp_neschimbat",
        ),
      );
    }

    redirect(
      caleDetalii(
        idCursant,
        "eroare=cnp_corectare_esuat",
      ),
    );
  }

  revalidatePath(`/cont/cursanti/${idCursant}`);

  redirect(
    caleDetalii(
      idCursant,
      "mesaj=cnp_corectat",
    ),
  );
}