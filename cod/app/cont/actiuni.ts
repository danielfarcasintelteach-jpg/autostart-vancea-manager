"use server";

import { redirect } from "next/navigation";

import { creeazaClientServer } from "@/lib/supabase/server";

async function executaDeconectarea(caleEroare: string) {
  const supabase = await creeazaClientServer();
  const verificare = await supabase.auth.getClaims().catch(() => null);

  if (!verificare?.data?.claims?.sub || verificare.error) {
    redirect("/autentificare");
  }

  let reusit = false;

  try {
    const { error } = await supabase.auth.signOut({ scope: "local" });
    reusit = !error;
  } catch {
    // Pagina afișează un mesaj neutru dacă sesiunea nu a fost închisă.
  }

  redirect(reusit ? "/autentificare" : caleEroare);
}

export async function deconecteaza() {
  await executaDeconectarea("/cont?deconectare=eroare");
}

export async function deconecteazaDinAccesNeactivat() {
  await executaDeconectarea("/acces-neactivat?deconectare=eroare");
}
