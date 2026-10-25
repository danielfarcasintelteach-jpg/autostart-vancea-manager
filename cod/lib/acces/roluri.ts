export const ROLURI_APLICATIE = [
  "administrator",
  "secretariat",
  "instructor",
  "cursant",
] as const;

export type RolAplicatie = (typeof ROLURI_APLICATIE)[number];

const CAI_CONT: Record<RolAplicatie, string> = {
  administrator: "/cont/administrator",
  secretariat: "/cont/secretariat",
  instructor: "/cont/instructor",
  cursant: "/cont/cursant",
};

const ETICHETE_ROL: Record<RolAplicatie, string> = {
  administrator: "Administrator",
  secretariat: "Secretariat",
  instructor: "Instructor",
  cursant: "Cursant",
};

export function esteRolAplicatie(rol: unknown): rol is RolAplicatie {
  return typeof rol === "string" &&
    (ROLURI_APLICATIE as readonly string[]).includes(rol);
}

export function caleContPentruRol(rol: RolAplicatie) {
  return CAI_CONT[rol];
}

export function etichetaRol(rol: RolAplicatie) {
  return ETICHETE_ROL[rol];
}
