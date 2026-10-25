import type { Metadata } from "next";

import { PanouRol } from "@/app/cont/_componente/panou-rol";
import { cereRoluri } from "@/lib/acces/protectie-ruta";
import { citesteRezumatAcces } from "@/lib/date/rezumat-acces";

export const metadata: Metadata = {
  title: "Secretariat | AUTOSTART VANCEA Manager",
};

export default async function PaginaSecretariat() {
  const profil = await cereRoluri("secretariat");
  const dateVizibile = await citesteRezumatAcces(profil.rol);

  return (
    <PanouRol
      rol="secretariat"
      titlu="Panou secretariat"
      descriere="Ai acces la activitățile administrative ale școlii, fără administrarea conturilor și rolurilor."
      sectiuni={[
        { eticheta: "Cursanți", href: "/cont/cursanti" },
        { eticheta: "Instructori", href: "/cont/instructori" },
        "Vehicule",
        "Înscrieri și programări",
        "Plăți și examene",
      ]}
      dateVizibile={dateVizibile}
    />
  );
}
