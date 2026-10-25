import type { Metadata } from "next";

import { PanouRol } from "@/app/cont/_componente/panou-rol";
import { cereRoluri } from "@/lib/acces/protectie-ruta";
import { citesteRezumatAcces } from "@/lib/date/rezumat-acces";

export const metadata: Metadata = {
  title: "Administrator | AUTOSTART VANCEA Manager",
};

export default async function PaginaAdministrator() {
  const profil = await cereRoluri("administrator");
  const dateVizibile = await citesteRezumatAcces(profil.rol);

  return (
    <PanouRol
      rol="administrator"
      titlu="Panou administrator"
      descriere="Ai acces la administrarea completă a aplicației, în limitele operațiilor controlate și auditate."
      sectiuni={[
        "Conturi și roluri",
        { eticheta: "Cursanți", href: "/cont/cursanti" },
        "Instructori",
        "Vehicule",
        "Înscrieri și programări",
        "Plăți și examene",
      ]}
      dateVizibile={dateVizibile}
    />
  );
}
