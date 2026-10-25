import type { RolAplicatie } from "@/lib/acces/roluri";
import { creeazaClientServer } from "@/lib/supabase/server";

type TabelaCitibila =
  | "utilizatori"
  | "persoane"
  | "cursanti"
  | "instructori"
  | "vehicule"
  | "inscrieri"
  | "programari"
  | "plati"
  | "examene";

type DefinitieResursa = {
  cheie: string;
  eticheta: string;
  tabela: TabelaCitibila;
  coloana: string;
};

export type ElementRezumatAcces = {
  cheie: string;
  eticheta: string;
  numar: number | null;
};

const RESURSE_PE_ROL: Record<RolAplicatie, readonly DefinitieResursa[]> = {
  administrator: [
    { cheie: "utilizatori", eticheta: "Conturi", tabela: "utilizatori", coloana: "id_utilizator" },
    { cheie: "persoane", eticheta: "Persoane", tabela: "persoane", coloana: "id_persoana" },
    { cheie: "cursanti", eticheta: "Cursanți", tabela: "cursanti", coloana: "id_cursant" },
    { cheie: "instructori", eticheta: "Instructori", tabela: "instructori", coloana: "id_instructor" },
    { cheie: "vehicule", eticheta: "Vehicule", tabela: "vehicule", coloana: "id_vehicul" },
    { cheie: "inscrieri", eticheta: "Înscrieri", tabela: "inscrieri", coloana: "id_inscriere" },
    { cheie: "programari", eticheta: "Programări", tabela: "programari", coloana: "id_programare" },
    { cheie: "plati", eticheta: "Plăți", tabela: "plati", coloana: "id_plata" },
    { cheie: "examene", eticheta: "Examene", tabela: "examene", coloana: "id_examen" },
  ],
  secretariat: [
    { cheie: "persoane", eticheta: "Persoane", tabela: "persoane", coloana: "id_persoana" },
    { cheie: "cursanti", eticheta: "Cursanți", tabela: "cursanti", coloana: "id_cursant" },
    { cheie: "instructori", eticheta: "Instructori", tabela: "instructori", coloana: "id_instructor" },
    { cheie: "vehicule", eticheta: "Vehicule", tabela: "vehicule", coloana: "id_vehicul" },
    { cheie: "inscrieri", eticheta: "Înscrieri", tabela: "inscrieri", coloana: "id_inscriere" },
    { cheie: "programari", eticheta: "Programări", tabela: "programari", coloana: "id_programare" },
    { cheie: "plati", eticheta: "Plăți", tabela: "plati", coloana: "id_plata" },
    { cheie: "examene", eticheta: "Examene", tabela: "examene", coloana: "id_examen" },
  ],
  instructor: [
    {
      cheie: "profil-instructor",
      eticheta: "Profil instructor",
      tabela: "instructori",
      coloana: "id_instructor",
    },
    {
      cheie: "cursanti-relevanti",
      eticheta: "Cursanți relevanți",
      tabela: "cursanti",
      coloana: "id_cursant",
    },
    {
      cheie: "vehicule-relevante",
      eticheta: "Vehicule relevante",
      tabela: "vehicule",
      coloana: "id_vehicul",
    },
    {
      cheie: "inscrieri-repartizate",
      eticheta: "Înscrieri repartizate",
      tabela: "inscrieri",
      coloana: "id_inscriere",
    },
    {
      cheie: "programari-proprii",
      eticheta: "Programările mele",
      tabela: "programari",
      coloana: "id_programare",
    },
    {
      cheie: "examene-relevante",
      eticheta: "Examene relevante",
      tabela: "examene",
      coloana: "id_examen",
    },
  ],
  cursant: [
    {
      cheie: "profil-cursant",
      eticheta: "Profil cursant",
      tabela: "cursanti",
      coloana: "id_cursant",
    },
    {
      cheie: "inscrieri-proprii",
      eticheta: "Înscrierile mele",
      tabela: "inscrieri",
      coloana: "id_inscriere",
    },
    {
      cheie: "programari-proprii",
      eticheta: "Programările mele",
      tabela: "programari",
      coloana: "id_programare",
    },
    {
      cheie: "plati-proprii",
      eticheta: "Plățile mele",
      tabela: "plati",
      coloana: "id_plata",
    },
    {
      cheie: "examene-proprii",
      eticheta: "Examenele mele",
      tabela: "examene",
      coloana: "id_examen",
    },
    {
      cheie: "vehicule-relevante",
      eticheta: "Vehicule din programările mele",
      tabela: "vehicule",
      coloana: "id_vehicul",
    },
  ],
};

// Citirea foloseste clientul SSR al utilizatorului autentificat.
// Nu foloseste service_role si nu ocoleste RLS.
export async function citesteRezumatAcces(
  rol: RolAplicatie,
): Promise<ElementRezumatAcces[]> {
  const resurse = RESURSE_PE_ROL[rol];

  try {
    const supabase = await creeazaClientServer();

    return await Promise.all(
      resurse.map(async ({ cheie, eticheta, tabela, coloana }) => {
        try {
          const { count, error } = await supabase
            .from(tabela)
            .select(coloana, { count: "exact", head: true });

          return {
            cheie,
            eticheta,
            numar: error ? null : (count ?? 0),
          };
        } catch {
          return {
            cheie,
            eticheta,
            numar: null,
          };
        }
      }),
    );
  } catch {
    return resurse.map(({ cheie, eticheta }) => ({
      cheie,
      eticheta,
      numar: null,
    }));
  }
}
