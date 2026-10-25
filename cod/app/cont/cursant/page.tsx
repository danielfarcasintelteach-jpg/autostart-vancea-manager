import type { Metadata } from "next";

import { PanouRol } from "@/app/cont/_componente/panou-rol";
import { cereRoluri } from "@/lib/acces/protectie-ruta";
import { citesteRezumatAcces } from "@/lib/date/rezumat-acces";

export const metadata: Metadata = {
  title: "Cursant | AUTOSTART VANCEA Manager",
};

export default async function PaginaCursant() {
  const profil = await cereRoluri("cursant");
  const dateVizibile = await citesteRezumatAcces(profil.rol);

  return (
    <PanouRol
      rol="cursant"
      titlu="Panou cursant"
      descriere="Vezi numai datele și istoricul care îți aparțin."
      sectiuni={[
        "Profilul meu",
        "Înscrierile mele",
        "Programările mele",
        "Plățile mele",
        "Examenele mele",
      ]}
      dateVizibile={dateVizibile}
    />
  );
}
