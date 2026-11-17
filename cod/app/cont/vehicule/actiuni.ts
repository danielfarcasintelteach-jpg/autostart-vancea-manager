"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { verificaRoluriServer } from "@/lib/acces/autorizare";
import { caleContPentruRol } from "@/lib/acces/roluri";
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

function citesteAnFabricatie(
  formData: FormData,
): number | null | undefined {
  const valoare = citesteText(formData, "an_fabricatie");

  if (valoare === null) {
    return undefined;
  }

  if (!valoare) {
    return null;
  }

  if (!/^\d{4,5}$/.test(valoare)) {
    return undefined;
  }

  const an = Number(valoare);

  if (
    !Number.isSafeInteger(an) ||
    an < 1900 ||
    an > 32767
  ) {
    return undefined;
  }

  return an;
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
  idVehicul: string,
  parametru?: string,
): string {
  const baza = `/cont/vehicule/${idVehicul}`;

  return parametru ? `${baza}?${parametru}` : baza;
}

export async function creeazaVehicul(
  formData: FormData,
) {
  await cereAccesAdministrativ();

  const numarBrut = citesteText(formData, "numar_inmatriculare");
  const numarInmatriculare = numarBrut?.toUpperCase() ?? null;
  const marca = citesteText(formData, "marca");
  const model = citesteText(formData, "model");
  const anFabricatie = citesteAnFabricatie(formData);
  const observatii = citesteTextOptional(
    formData,
    "observatii",
    2000,
  );

  if (
    !numarInmatriculare ||
    numarInmatriculare.length > 20 ||
    !/^[A-Z0-9]+$/.test(numarInmatriculare) ||
    !marca ||
    marca.length > 100 ||
    !model ||
    model.length > 100 ||
    anFabricatie === undefined ||
    observatii === undefined
  ) {
    redirect("/cont/vehicule/nou?eroare=date_invalide");
  }

  const supabase = await creeazaClientServer();

  let rezultat;

  try {
    rezultat = await supabase.rpc("creare_vehicul", {
      p_numar_inmatriculare: numarInmatriculare,
      p_marca: marca,
      p_model: model,
      p_an_fabricatie: anFabricatie,
      p_observatii: observatii,
    });
  } catch {
    redirect("/cont/vehicule/nou?eroare=server");
  }

  if (rezultat.error) {
    if (rezultat.error.code === "PZ001") {
      redirect("/cont");
    }

    if (rezultat.error.code === "23505") {
      redirect("/cont/vehicule/nou?eroare=numar_existent");
    }

    if (
      rezultat.error.code === "23514" ||
      rezultat.error.code === "22003" ||
      rezultat.error.code === "22P02"
    ) {
      redirect("/cont/vehicule/nou?eroare=date_invalide");
    }

    redirect("/cont/vehicule/nou?eroare=server");
  }

  const idVehicul =
    typeof rezultat.data === "string"
      ? rezultat.data
      : null;

  if (!idVehicul || !FORMAT_UUID.test(idVehicul)) {
    redirect("/cont/vehicule/nou?eroare=server");
  }

  revalidatePath("/cont/vehicule");

  redirect(
    caleDetalii(
      idVehicul,
      "mesaj=vehicul_creat",
    ),
  );
}
export async function actualizeazaVehicul(
  idVehicul: string,
  formData: FormData,
) {
  await cereAccesAdministrativ();

  if (!FORMAT_UUID.test(idVehicul)) {
    redirect("/cont/vehicule");
  }

  const numarBrut = citesteText(formData, "numar_inmatriculare");
  const numarInmatriculare = numarBrut?.toUpperCase() ?? null;
  const marca = citesteText(formData, "marca");
  const model = citesteText(formData, "model");
  const anFabricatie = citesteAnFabricatie(formData);
  const observatii = citesteTextOptional(
    formData,
    "observatii",
    2000,
  );

  if (
    !numarInmatriculare ||
    numarInmatriculare.length > 20 ||
    !/^[A-Z0-9]+$/.test(numarInmatriculare) ||
    !marca ||
    marca.length > 100 ||
    !model ||
    model.length > 100 ||
    anFabricatie === undefined ||
    observatii === undefined
  ) {
    redirect(
      caleDetalii(
        idVehicul,
        "eroare=date_invalide",
      ),
    );
  }

  const supabase = await creeazaClientServer();

  let rezultat;

  try {
    rezultat = await supabase.rpc("modifica_vehicul", {
      p_id_vehicul: idVehicul,
      p_modificari: {
        numar_inmatriculare: numarInmatriculare,
        marca,
        model,
        an_fabricatie: anFabricatie,
        observatii,
      },
    });
  } catch {
    redirect(caleDetalii(idVehicul, "eroare=server"));
  }

  if (rezultat.error) {
    if (rezultat.error.code === "PZ001") {
      redirect("/cont");
    }

    if (rezultat.error.code === "PZ002") {
      redirect("/cont/vehicule");
    }

    if (rezultat.error.code === "23505") {
      redirect(
        caleDetalii(
          idVehicul,
          "eroare=numar_existent",
        ),
      );
    }

    if (
      rezultat.error.code === "22023" ||
      rezultat.error.code === "23514" ||
      rezultat.error.code === "22003" ||
      rezultat.error.code === "22P02"
    ) {
      redirect(
        caleDetalii(
          idVehicul,
          "eroare=date_invalide",
        ),
      );
    }

    redirect(
      caleDetalii(
        idVehicul,
        "eroare=actualizare_esuata",
      ),
    );
  }

  revalidatePath("/cont/vehicule");
  revalidatePath(`/cont/vehicule/${idVehicul}`);

  redirect(
    caleDetalii(
      idVehicul,
      "mesaj=vehicul_actualizat",
    ),
  );
}
export async function schimbaStareVehicul(
  idVehicul: string,
  formData: FormData,
) {
  await cereAccesAdministrativ();

  if (!FORMAT_UUID.test(idVehicul)) {
    redirect("/cont/vehicule");
  }

  const stare = citesteText(formData, "stare");

  if (
    !stare ||
    !["activ", "service", "indisponibil", "inactiv"].includes(stare)
  ) {
    redirect(
      caleDetalii(
        idVehicul,
        "eroare=stare_invalida",
      ),
    );
  }

  const supabase = await creeazaClientServer();

  let rezultat;

  try {
    rezultat = await supabase.rpc("schimba_stare_vehicul", {
      p_id_vehicul: idVehicul,
      p_stare: stare,
    });
  } catch {
    redirect(caleDetalii(idVehicul, "eroare=server"));
  }

  if (rezultat.error) {
    if (rezultat.error.code === "PZ001") {
      redirect("/cont");
    }

    if (rezultat.error.code === "PZ002") {
      redirect("/cont/vehicule");
    }

    if (
      rezultat.error.code === "PZ003" ||
      rezultat.error.code === "23514"
    ) {
      redirect(
        caleDetalii(
          idVehicul,
          "eroare=tranzitie_stare_nepermisa",
        ),
      );
    }

    redirect(
      caleDetalii(
        idVehicul,
        "eroare=schimbare_stare_esuata",
      ),
    );
  }

  revalidatePath("/cont/vehicule");
  revalidatePath(`/cont/vehicule/${idVehicul}`);

  redirect(
    caleDetalii(
      idVehicul,
      "mesaj=stare_actualizata",
    ),
  );
}
