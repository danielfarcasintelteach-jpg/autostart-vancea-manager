import { creeazaClientServer } from "@/lib/supabase/server";

export type StareProgramare =
  | "programata"
  | "finalizata"
  | "anulata"
  | "absent";

export type ProgramareListaAdministrativa = {
  id_programare: string;
  id_inscriere: string;
  id_cursant: string;
  cursant_nume: string;
  cursant_prenume: string;
  id_instructor: string;
  instructor_nume: string;
  instructor_prenume: string;
  id_vehicul: string;
  numar_inmatriculare: string;
  marca: string;
  model: string;
  inceput: string;
  sfarsit: string;
  stare: StareProgramare;
  total_inregistrari: number;
};

export type DetaliiProgramareAdministrativa = {
  id_programare: string;
  id_inscriere: string;
  id_cursant: string;
  cursant_nume: string;
  cursant_prenume: string;
  id_instructor: string;
  instructor_nume: string;
  instructor_prenume: string;
  id_vehicul: string;
  numar_inmatriculare: string;
  marca: string;
  model: string;
  inceput: string;
  sfarsit: string;
  stare: StareProgramare;
  observatii: string | null;
};

export type FiltreListaProgramari = {
  cautare?: string | null;
  stare?: StareProgramare | null;
  data?: string | null;
  limita?: number;
  offset?: number;
};

export type RezultatListaProgramari = {
  programari: ProgramareListaAdministrativa[];
  total: number;
};

export async function citesteListaProgramariAdministrativ(
  filtre: FiltreListaProgramari = {},
): Promise<RezultatListaProgramari> {
  const supabase = await creeazaClientServer();

  const limita = filtre.limita ?? 25;
  const offset = filtre.offset ?? 0;

  async function citestePagina(
    limitaPagina: number,
    offsetPagina: number,
  ): Promise<ProgramareListaAdministrativa[]> {
    const { data, error } = await supabase.rpc(
      "lista_programari_administrativ",
      {
        p_cautare: filtre.cautare ?? null,
        p_stare: filtre.stare ?? null,
        p_data: filtre.data ?? null,
        p_limita: limitaPagina,
        p_offset: offsetPagina,
      },
    );

    if (error) {
      throw new Error(
        `Citirea listei de programari a esuat: ${error.code ?? "EROARE_RPC"}`,
      );
    }

    return (data ?? []) as ProgramareListaAdministrativa[];
  }

  const programari = await citestePagina(
    limita,
    offset,
  );

  if (programari.length > 0) {
    return {
      programari,
      total:
        Number(
          programari[0].total_inregistrari,
        ) || 0,
    };
  }

  if (offset > 0) {
    const verificareTotal = await citestePagina(
      1,
      0,
    );

    return {
      programari,
      total:
        Number(
          verificareTotal[0]
            ?.total_inregistrari ?? 0,
        ),
    };
  }

  return {
    programari: [],
    total: 0,
  };
}

export async function citesteDetaliiProgramareAdministrativ(
  idProgramare: string,
): Promise<DetaliiProgramareAdministrativa | null> {
  const supabase = await creeazaClientServer();

  const { data, error } = await supabase.rpc(
    "detalii_programare_administrativ",
    {
      p_id_programare: idProgramare,
    },
  );

  if (error) {
    if (error.code === "PZ002") {
      return null;
    }

    throw new Error(
      `Citirea detaliilor programarii a esuat: ${error.code ?? "EROARE_RPC"}`,
    );
  }

  const randuri =
    (data ??
      []) as DetaliiProgramareAdministrativa[];

  return randuri[0] ?? null;
}