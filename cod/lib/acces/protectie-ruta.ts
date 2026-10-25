import { redirect } from "next/navigation";

import { obtineProfilCurent } from "@/lib/acces/profil-curent";
import { caleContPentruRol, type RolAplicatie } from "@/lib/acces/roluri";

export async function cereRoluri(...roluriPermise: RolAplicatie[]) {
  const profil = await obtineProfilCurent();

  if (profil.stare === "neautentificat") {
    redirect("/autentificare");
  }

  if (profil.stare === "neactivat") {
    redirect("/acces-neactivat");
  }

  if (profil.stare === "eroare") {
    redirect("/cont");
  }

  if (!roluriPermise.includes(profil.rol)) {
    redirect(caleContPentruRol(profil.rol));
  }

  return profil;
}
