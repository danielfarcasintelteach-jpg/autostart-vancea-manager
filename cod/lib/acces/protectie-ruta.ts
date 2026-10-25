import { redirect } from "next/navigation";

import { verificaRoluriServer } from "@/lib/acces/autorizare";
import { caleContPentruRol, type RolAplicatie } from "@/lib/acces/roluri";

export async function cereRoluri(...roluriPermise: RolAplicatie[]) {
  const acces = await verificaRoluriServer(...roluriPermise);

  if (acces.autorizat) {
    return {
      stare: "activ" as const,
      rol: acces.rol,
    };
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