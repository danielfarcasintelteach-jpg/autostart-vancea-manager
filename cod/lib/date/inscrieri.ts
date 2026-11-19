import { creeazaClientServer } from "@/lib/supabase/server";

export type StareInscriere =
  | "activa"
  | "finalizata"
  | "anulata";

export type InscriereListaAdministrativa = {
  id_inscriere: string;
  id_cursant: string;
  cursant_nume: string;
  cursant_prenume: string;
  id_instructor: string;
  instructor_nume: string;
  instructor_prenume: string;
  categorie: "B";
  data_inscrierii: string;
  tarif_curs: number;
  stare: StareInscriere;
  data_finalizarii: string | null;
  total_inregistrari: number;
};

export type DetaliiInscriereAdministrativa = {
  id_inscriere: string;
  id_cursant: string;
  cursant_nume: string;
  cursant_prenume: string;
  id_instructor: string;
  instructor_nume: string;
  instructor_prenume: string;
  categorie: "B";
  data_inscrierii: string;
  tarif_curs: number;
  stare: StareInscriere;
  data_finalizarii: string | null;
  observatii: string | null;
};

export type FiltreListaInscrieri = {
  cautare?: string | null;
  stare?: StareInscriere | null;
  limita?: number;
  offset?: number;
};

export type RezultatListaInscrieri = {
  inscrieri: InscriereListaAdministrativa[];
  total: number;
};

export async function citesteListaInscrieriAdministrativ(
  filtre: FiltreListaInscrieri = {},
): Promise<RezultatListaInscrieri> {
  const supabase = await creeazaClientServer();

  const limita = filtre.limita ?? 25;
  const offset = filtre.offset ?? 0;

  async function citestePagina(
    limitaPagina: number,
    offsetPagina: number,
  ): Promise<InscriereListaAdministrativa[]> {
    const { data, error } = await supabase.rpc(
      "lista_inscrieri_administrativ",
      {
        p_cautare: filtre.cautare ?? null,
        p_stare: filtre.stare ?? null,
        p_limita: limitaPagina,
        p_offset: offsetPagina,
      },
    );

    if (error) {
      throw new Error(
        `Citirea listei de inscrieri a esuat: ${error.code ?? "EROARE_RPC"}`,
      );
    }

    return (data ?? []) as InscriereListaAdministrativa[];
  }

  const inscrieri = await citestePagina(limita, offset);

  if (inscrieri.length > 0) {
    return {
      inscrieri,
      total: Number(inscrieri[0].total_inregistrari) || 0,
    };
  }

  if (offset > 0) {
    const verificareTotal = await citestePagina(1, 0);

    return {
      inscrieri,
      total: Number(verificareTotal[0]?.total_inregistrari ?? 0),
    };
  }

  return {
    inscrieri: [],
    total: 0,
  };
}

export async function citesteDetaliiInscriereAdministrativ(
  idInscriere: string,
): Promise<DetaliiInscriereAdministrativa | null> {
  const supabase = await creeazaClientServer();

  const { data, error } = await supabase.rpc(
    "detalii_inscriere_administrativ",
    {
      p_id_inscriere: idInscriere,
    },
  );

  if (error) {
    if (error.code === "PZ002") {
      return null;
    }

    throw new Error(
      `Citirea detaliilor inscrierii a esuat: ${error.code ?? "EROARE_RPC"}`,
    );
  }

  const randuri =
    (data ?? []) as DetaliiInscriereAdministrativa[];

  return randuri[0] ?? null;
}