import type { Metadata } from "next";

import { PanouRol } from "@/app/cont/_componente/panou-rol";
import { cereRoluri } from "@/lib/acces/protectie-ruta";

export const metadata: Metadata = {
  title: "Secretariat | AUTOSTART VANCEA Manager",
};

export default async function PaginaSecretariat() {
  await cereRoluri("secretariat");

  return (
    <PanouRol
      rol="secretariat"
      titlu="Panou secretariat"
      descriere="Ai acces la activitățile administrative ale școlii, fără administrarea conturilor și rolurilor."
      sectiuni={[
        "Cursanți și instructori",
        "Vehicule",
        "Înscrieri și programări",
        "Plăți și examene",
      ]}
    />
  );
}
