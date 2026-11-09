"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { verificaRoluriServer } from "@/lib/acces/autorizare";
import { caleContPentruRol } from "@/lib/acces/roluri";
import { citesteDetaliiInstructorAdministrativ } from "@/lib/date/instructori";
import { creeazaClientServer } from "@/lib/supabase/server";

const FORMAT_UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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
  idInstructor: string,
  parametru?: string,
): string {
  const baza = `/cont/instructori/${idInstructor}`;

  return parametru ? `${baza}?${parametru}` : baza;
}

export async function creeazaInstructor(
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
  const dataAngajarii = citesteDataOptionala(
    formData,
    "data_angajarii",
  );
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
    dataAngajarii === undefined ||
    observatii === undefined
  ) {
    redirect("/cont/instructori/nou?eroare=date_invalide");
  }

  const supabase = await creeazaClientServer();

  let rezultat;

  try {
    rezultat = await supabase.rpc("creare_instructor", {
      p_nume: nume,
      p_prenume: prenume,
      p_telefon: telefon,
      p_email: email,
      p_data_nasterii: dataNasterii,
      p_adresa: adresa,
      p_data_angajarii: dataAngajarii,
      p_observatii: observatii,
    });
  } catch {
    redirect("/cont/instructori/nou?eroare=server");
  }

  if (rezultat.error) {
    if (rezultat.error.code === "PZ001") {
      redirect("/cont");
    }

    if (
      rezultat.error.code === "22023" ||
      rezultat.error.code === "23514"
    ) {
      redirect("/cont/instructori/nou?eroare=date_invalide");
    }

    redirect("/cont/instructori/nou?eroare=server");
  }

  const idInstructor =
    typeof rezultat.data === "string"
      ? rezultat.data
      : null;

  if (!idInstructor || !FORMAT_UUID.test(idInstructor)) {
    redirect("/cont/instructori/nou?eroare=server");
  }

  revalidatePath("/cont/instructori");

  redirect(
    caleDetalii(
      idInstructor,
      "mesaj=instructor_creat",
    ),
  );
}

export async function actualizeazaDatePersonaleInstructor(
  idInstructor: string,
  formData: FormData,
) {
  await cereAccesAdministrativ();

  if (!FORMAT_UUID.test(idInstructor)) {
    redirect("/cont/instructori");
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
        idInstructor,
        "eroare=date_personale_invalide",
      ),
    );
  }

  let instructor;

  try {
    instructor = await citesteDetaliiInstructorAdministrativ(
      idInstructor,
    );
  } catch {
    redirect(
      caleDetalii(
        idInstructor,
        "eroare=server",
      ),
    );
  }

  if (!instructor) {
    redirect("/cont/instructori?eroare=instructor_inexistent");
  }

  const supabase = await creeazaClientServer();

  let rezultat;

  try {
    rezultat = await supabase.rpc("modifica_persoana", {
      p_id_persoana: instructor.id_persoana,
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
        idInstructor,
        "eroare=server",
      ),
    );
  }

  if (rezultat.error) {
    if (rezultat.error.code === "PZ001") {
      redirect("/cont");
    }

    if (rezultat.error.code === "PZ002") {
      redirect("/cont/instructori?eroare=instructor_inexistent");
    }

    if (
      rezultat.error.code === "22023" ||
      rezultat.error.code === "23514"
    ) {
      redirect(
        caleDetalii(
          idInstructor,
          "eroare=date_personale_invalide",
        ),
      );
    }

    redirect(
      caleDetalii(
        idInstructor,
        "eroare=actualizare_esuata",
      ),
    );
  }

  revalidatePath("/cont/instructori");
  revalidatePath(`/cont/instructori/${idInstructor}`);

  redirect(
    caleDetalii(
      idInstructor,
      "mesaj=date_personale_actualizate",
    ),
  );
}

export async function actualizeazaDateProfesionaleInstructor(
  idInstructor: string,
  formData: FormData,
) {
  await cereAccesAdministrativ();

  if (!FORMAT_UUID.test(idInstructor)) {
    redirect("/cont/instructori");
  }

  const dataAngajarii = citesteDataOptionala(
    formData,
    "data_angajarii",
  );
  const observatii = citesteTextOptional(
    formData,
    "observatii",
    2000,
  );

  if (
    dataAngajarii === undefined ||
    observatii === undefined
  ) {
    redirect(
      caleDetalii(
        idInstructor,
        "eroare=date_profesionale_invalide",
      ),
    );
  }

  const supabase = await creeazaClientServer();

  let rezultat;

  try {
    rezultat = await supabase.rpc("modifica_instructor", {
      p_id_instructor: idInstructor,
      p_modificari: {
        data_angajarii: dataAngajarii,
        observatii,
      },
    });
  } catch {
    redirect(
      caleDetalii(
        idInstructor,
        "eroare=server",
      ),
    );
  }

  if (rezultat.error) {
    if (rezultat.error.code === "PZ001") {
      redirect("/cont");
    }

    if (rezultat.error.code === "PZ002") {
      redirect("/cont/instructori?eroare=instructor_inexistent");
    }

    if (
      rezultat.error.code === "22023" ||
      rezultat.error.code === "23514"
    ) {
      redirect(
        caleDetalii(
          idInstructor,
          "eroare=date_profesionale_invalide",
        ),
      );
    }

    redirect(
      caleDetalii(
        idInstructor,
        "eroare=actualizare_esuata",
      ),
    );
  }

  revalidatePath("/cont/instructori");
  revalidatePath(`/cont/instructori/${idInstructor}`);

  redirect(
    caleDetalii(
      idInstructor,
      "mesaj=date_profesionale_actualizate",
    ),
  );
}

export async function schimbaStareInstructor(
  idInstructor: string,
  stareNoua: "activ" | "inactiv",
) {
  await cereAccesAdministrativ();

  if (
    !FORMAT_UUID.test(idInstructor) ||
    !["activ", "inactiv"].includes(stareNoua)
  ) {
    redirect("/cont/instructori");
  }

  const supabase = await creeazaClientServer();

  let rezultat;

  try {
    rezultat = await supabase.rpc("schimba_stare_instructor", {
      p_id_instructor: idInstructor,
      p_stare: stareNoua,
    });
  } catch {
    redirect(caleDetalii(idInstructor, "eroare=server"));
  }

  if (rezultat.error) {
    if (rezultat.error.code === "PZ001") {
      redirect("/cont");
    }

    if (rezultat.error.code === "PZ002") {
      redirect("/cont/instructori?eroare=instructor_inexistent");
    }

    if (rezultat.error.code === "PZ003") {
      redirect(
        caleDetalii(
          idInstructor,
          "eroare=tranzitie_stare_refuzata",
        ),
      );
    }

    redirect(caleDetalii(idInstructor, "eroare=server"));
  }

  revalidatePath("/cont/instructori");
  revalidatePath(`/cont/instructori/${idInstructor}`);

  redirect(
    caleDetalii(
      idInstructor,
      stareNoua === "activ"
        ? "mesaj=instructor_activat"
        : "mesaj=instructor_dezactivat",
    ),
  );
}
