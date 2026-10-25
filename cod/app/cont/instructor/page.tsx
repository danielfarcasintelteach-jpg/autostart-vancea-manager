import type { Metadata } from "next";

import { PanouRol } from "@/app/cont/_componente/panou-rol";
import { cereRoluri } from "@/lib/acces/protectie-ruta";

export const metadata: Metadata = {
  title: "Instructor | AUTOSTART VANCEA Manager",
};

export default async function PaginaInstructor() {
  await cereRoluri("instructor");

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
    />
  );
}
