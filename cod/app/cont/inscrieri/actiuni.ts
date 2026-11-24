"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { verificaRoluriServer } from "@/lib/acces/autorizare";
import { caleContPentruRol } from "@/lib/acces/roluri";
import { citesteDetaliiInscriereAdministrativ } from "@/lib/date/inscrieri";
import { creeazaClientServer } from "@/lib/supabase/server";

const FORMAT_UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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

function citesteTarif(
  formData: FormData,
): number | undefined {
  const text = citesteText(formData, "tarif_curs");

  if (!text) {
    return undefined;
  }

  const normalizat = text.replace(",", ".");

  if (!/^\d+(\.\d{1,2})?$/.test(normalizat)) {
    return undefined;
  }

  const tarif = Number(normalizat);

  if (
    !Number.isFinite(tarif) ||
    tarif <= 0 ||
    tarif > 9999999999.99
  ) {
    return undefined;
  }

  return tarif;
}

export async function creeazaInscriere(
  formData: FormData,
) {
  await cereAccesAdministrativ();

  const idCursant = citesteText(
    formData,
    "id_cursant",
  );

  const idInstructor = citesteText(
    formData,
    "id_instructor",
  );

  const tarifCurs = citesteTarif(formData);

  const observatii = citesteTextOptional(
    formData,
    "observatii",
    2000,
  );

  if (
    !idCursant ||
    !FORMAT_UUID.test(idCursant) ||
    !idInstructor ||
    !FORMAT_UUID.test(idInstructor) ||
    tarifCurs === undefined ||
    observatii === undefined
  ) {
    redirect(
      "/cont/inscrieri/nou?eroare=date_invalide",
    );
  }

  const supabase = await creeazaClientServer();

  let rezultat;

  try {
    rezultat = await supabase.rpc(
      "creare_inscriere",
      {
        p_id_cursant: idCursant,
        p_id_instructor: idInstructor,
        p_tarif_curs: tarifCurs,
        p_observatii: observatii,
      },
    );
  } catch {
    redirect(
      "/cont/inscrieri/nou?eroare=server",
    );
  }

  if (rezultat.error) {
    if (rezultat.error.code === "PZ001") {
      redirect("/cont");
    }

    if (rezultat.error.code === "PZ002") {
      redirect(
        "/cont/inscrieri/nou?eroare=resursa_inexistenta",
      );
    }

    if (rezultat.error.code === "PZ003") {
      redirect(
        "/cont/inscrieri/nou?eroare=resursa_inactiva",
      );
    }

    if (rezultat.error.code === "23505") {
      redirect(
        "/cont/inscrieri/nou?eroare=inscriere_activa_existenta",
      );
    }

    if (
      rezultat.error.code === "23514" ||
      rezultat.error.code === "22003" ||
      rezultat.error.code === "22P02"
    ) {
      redirect(
        "/cont/inscrieri/nou?eroare=date_invalide",
      );
    }

    redirect(
      "/cont/inscrieri/nou?eroare=server",
    );
  }

  const idInscriere =
    typeof rezultat.data === "string"
      ? rezultat.data
      : null;

  if (
    !idInscriere ||
    !FORMAT_UUID.test(idInscriere)
  ) {
    redirect(
      "/cont/inscrieri/nou?eroare=server",
    );
  }

  revalidatePath("/cont/inscrieri");

  redirect(
    `/cont/inscrieri/${idInscriere}?mesaj=inscriere_creata`,
  );
}
export async function actualizeazaInscriere(
  idInscriere: string,
  formData: FormData,
) {
  await cereAccesAdministrativ();

  if (!FORMAT_UUID.test(idInscriere)) {
    redirect("/cont/inscrieri");
  }

  const tarifCurs = citesteTarif(formData);
  const observatii = citesteTextOptional(
    formData,
    "observatii",
    2000,
  );

  if (
    tarifCurs === undefined ||
    observatii === undefined
  ) {
    redirect(
      `/cont/inscrieri/${idInscriere}?eroare=date_invalide`,
    );
  }

  let inscriere;

  try {
    inscriere =
      await citesteDetaliiInscriereAdministrativ(
        idInscriere,
      );
  } catch {
    redirect(
      `/cont/inscrieri/${idInscriere}?eroare=server`,
    );
  }

  if (!inscriere) {
    redirect("/cont/inscrieri");
  }

  if (inscriere.stare !== "activa") {
    redirect(
      `/cont/inscrieri/${idInscriere}?eroare=inscriere_inactiva`,
    );
  }

  const modificari: {
    tarif_curs?: number;
    observatii?: string | null;
  } = {};

  if (
    tarifCurs !== Number(inscriere.tarif_curs)
  ) {
    modificari.tarif_curs = tarifCurs;
  }

  if (
    observatii !==
    (inscriere.observatii ?? null)
  ) {
    modificari.observatii = observatii;
  }

  if (Object.keys(modificari).length === 0) {
    redirect(
      `/cont/inscrieri/${idInscriere}?mesaj=fara_modificari`,
    );
  }

  const supabase = await creeazaClientServer();

  let rezultat;

  try {
    rezultat = await supabase.rpc(
      "modifica_inscriere",
      {
        p_id_inscriere: idInscriere,
        p_modificari: modificari,
      },
    );
  } catch {
    redirect(
      `/cont/inscrieri/${idInscriere}?eroare=server`,
    );
  }

  if (rezultat.error) {
    if (rezultat.error.code === "PZ001") {
      redirect("/cont");
    }

    if (rezultat.error.code === "PZ002") {
      redirect("/cont/inscrieri");
    }

    if (rezultat.error.code === "PZ003") {
      redirect(
        `/cont/inscrieri/${idInscriere}?eroare=modificare_refuzata`,
      );
    }

    if (
      rezultat.error.code === "22023" ||
      rezultat.error.code === "23514" ||
      rezultat.error.code === "22003" ||
      rezultat.error.code === "22P02"
    ) {
      redirect(
        `/cont/inscrieri/${idInscriere}?eroare=date_invalide`,
      );
    }

    redirect(
      `/cont/inscrieri/${idInscriere}?eroare=server`,
    );
  }

  revalidatePath("/cont/inscrieri");
  revalidatePath(
    `/cont/inscrieri/${idInscriere}`,
  );

  redirect(
    `/cont/inscrieri/${idInscriere}?mesaj=inscriere_actualizata`,
  );
}

export async function realocaInstructorInscriere(
  idInscriere: string,
  formData: FormData,
) {
  await cereAccesAdministrativ();

  if (!FORMAT_UUID.test(idInscriere)) {
    redirect("/cont/inscrieri");
  }

  const idInstructorNou = citesteText(
    formData,
    "id_instructor_nou",
  );

  if (
    !idInstructorNou ||
    !FORMAT_UUID.test(idInstructorNou)
  ) {
    redirect(
      `/cont/inscrieri/${idInscriere}?eroare=instructor_invalid`,
    );
  }

  const supabase = await creeazaClientServer();

  let rezultat;

  try {
    rezultat = await supabase.rpc(
      "realoca_instructor",
      {
        p_id_inscriere: idInscriere,
        p_id_instructor_nou: idInstructorNou,
      },
    );
  } catch {
    redirect(
      `/cont/inscrieri/${idInscriere}?eroare=server`,
    );
  }

  if (rezultat.error) {
    if (rezultat.error.code === "PZ001") {
      redirect("/cont");
    }

    if (rezultat.error.code === "PZ002") {
      redirect(
        `/cont/inscrieri/${idInscriere}?eroare=resursa_inexistenta`,
      );
    }

    if (rezultat.error.code === "PZ003") {
      redirect(
        `/cont/inscrieri/${idInscriere}?eroare=realocare_refuzata`,
      );
    }

    if (
      rezultat.error.code === "23514" ||
      rezultat.error.code === "22P02"
    ) {
      redirect(
        `/cont/inscrieri/${idInscriere}?eroare=instructor_invalid`,
      );
    }

    redirect(
      `/cont/inscrieri/${idInscriere}?eroare=server`,
    );
  }

  revalidatePath("/cont/inscrieri");
  revalidatePath(
    `/cont/inscrieri/${idInscriere}`,
  );

  redirect(
    `/cont/inscrieri/${idInscriere}?mesaj=instructor_realocat`,
  );
}