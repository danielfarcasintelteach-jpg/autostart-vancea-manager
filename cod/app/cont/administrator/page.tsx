import type { Metadata } from "next";

import { PanouRol } from "@/app/cont/_componente/panou-rol";
import { cereRoluri } from "@/lib/acces/protectie-ruta";

export const metadata: Metadata = {
  title: "Administrator | AUTOSTART VANCEA Manager",
};

export default async function PaginaAdministrator() {
  await cereRoluri("administrator");

  return (
    <PanouRol
      rol="administrator"
      titlu="Panou administrator"
      descriere="Ai acces la administrarea completă a aplicației, în limitele operațiilor controlate și auditate."
      sectiuni={[
        "Conturi și roluri",
        "Cursanți și instructori",
        "Vehicule",
        "Înscrieri și programări",
        "Plăți și examene",
      ]}
    />
  );
}
