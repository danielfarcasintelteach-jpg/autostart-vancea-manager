import { obtineProfilCurent } from "@/lib/acces/profil-curent";
import type { RolAplicatie } from "@/lib/acces/roluri";

export type RezultatAutorizareRoluri =
  | { autorizat: true; rol: RolAplicatie }
  | {
      autorizat: false;
      motiv: "neautentificat" | "neactivat" | "eroare";
    }
  | {
      autorizat: false;
      motiv: "interzis";
      rol: RolAplicatie;
    };

// Poate fi reutilizata atat de rute, cat si de viitoarele Server Actions.
// Rolul este citit din profilul controlat de aplicatie, nu din formular/browser.
export async function verificaRoluriServer(
  ...roluriPermise: RolAplicatie[]
): Promise<RezultatAutorizareRoluri> {
  const profil = await obtineProfilCurent();

  if (profil.stare !== "activ") {
    return {
      autorizat: false,
      motiv: profil.stare,
    };
  }

  if (!roluriPermise.includes(profil.rol)) {
    return {
      autorizat: false,
      motiv: "interzis",
      rol: profil.rol,
    };
  }

  return {
    autorizat: true,
    rol: profil.rol,
  };
}