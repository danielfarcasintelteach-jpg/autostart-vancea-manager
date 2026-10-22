import { isAuthSessionMissingError } from "@supabase/supabase-js";

import { creeazaClientServer } from "@/lib/supabase/server";

type RolAplicatie = "administrator" | "secretariat" | "instructor" | "cursant";

export type StareProfilCurent =
  | { stare: "neautentificat" }
  | { stare: "neactivat" }
  | { stare: "eroare" }
  | { stare: "activ"; rol: RolAplicatie };

function esteRolAplicatie(rol: unknown): rol is RolAplicatie {
  return rol === "administrator" || rol === "secretariat" ||
    rol === "instructor" || rol === "cursant";
}

// creeazaClientServer depinde de next/headers; acest modul poate fi folosit doar pe server.
export async function obtineProfilCurent(): Promise<StareProfilCurent> {
  try {
    const supabase = await creeazaClientServer();
    const { data: identitate, error: eroareAutentificare } = await supabase.auth.getClaims();

    if (eroareAutentificare) {
      return { stare: isAuthSessionMissingError(eroareAutentificare) ? "neautentificat" : "eroare" };
    }

    const idUtilizator = identitate?.claims?.sub;
    if (!idUtilizator) {
      return { stare: "neautentificat" };
    }

    const { data: profil, error: eroareProfil } = await supabase
      .from("utilizatori")
      .select("id_utilizator, rol, activ")
      .eq("id_utilizator", idUtilizator)
      .maybeSingle();

    if (eroareProfil) {
      return { stare: "eroare" };
    }

    // RLS ascunde și profilul inactiv; ambele situații au aceeași stare externă.
    if (!profil || profil.activ === false) {
      return { stare: "neactivat" };
    }

    if (profil.id_utilizator !== idUtilizator || profil.activ !== true || !esteRolAplicatie(profil.rol)) {
      return { stare: "eroare" };
    }

    return { stare: "activ", rol: profil.rol };
  } catch {
    return { stare: "eroare" };
  }
}
