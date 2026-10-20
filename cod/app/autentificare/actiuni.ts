"use server";

import { redirect } from "next/navigation";

import { creeazaClientServer } from "@/lib/supabase/server";

export type StareAutentificare = { eroare: string | null };

const mesajEroare = "Autentificarea nu a reușit. Verifică e-mailul și parola sau încearcă din nou.";

export async function autentifica(
  _stare: StareAutentificare,
  dateFormular: FormData,
): Promise<StareAutentificare> {
  const email = dateFormular.get("email");
  const parola = dateFormular.get("parola");

  if (
    typeof email !== "string" ||
    !email.trim() ||
    typeof parola !== "string" ||
    !parola
  ) {
    return { eroare: mesajEroare };
  }

  try {
    const supabase = await creeazaClientServer();
    const { error } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password: parola,
    });

    if (error) {
      return { eroare: mesajEroare };
    }
  } catch {
    return { eroare: mesajEroare };
  }

  redirect("/cont");
}
