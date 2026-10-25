import type { Metadata } from "next";

import { PanouRol } from "@/app/cont/_componente/panou-rol";
import { cereRoluri } from "@/lib/acces/protectie-ruta";
import { citesteRezumatAcces } from "@/lib/date/rezumat-acces";

export const metadata: Metadata = {
  title: "Instructor | AUTOSTART VANCEA Manager",
};

export default async function PaginaInstructor() {
  const profil = await cereRoluri("instructor");
  const dateVizibile = await citesteRezumatAcces(profil.rol);

  return (
    <PanouRol
      rol="instructor"
      titlu="Panou instructor"
      descriere="Vezi numai informațiile legate de activitatea ta și de cursanții care îți sunt relevanți."
      sectiuni={[
        "Cursanții repartizați",
        "Programările mele",
        "Examenele cursanților repartizați",
      ]}
      dateVizibile={dateVizibile}
    />
  );
}
