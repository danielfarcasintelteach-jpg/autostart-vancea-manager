"use server";

import { redirect } from "next/navigation";

import { creeazaClientServer } from "@/lib/supabase/server";

export async function deconecteaza() {
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

  redirect(reusit ? "/autentificare" : "/cont?deconectare=eroare");
}
