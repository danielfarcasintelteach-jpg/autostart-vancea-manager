import { creeazaClientServer } from "@/lib/supabase/server";

export type StareCursant = "activ" | "inactiv";

export type CursantListaAdministrativa = {
  id_cursant: string;
  id_persoana: string;
  nume: string;
  prenume: string;
  telefon: string | null;
  email: string | null;
  stare: StareCursant;
  total_inregistrari: number;
};

export type DetaliiCursantAdministrativ = {
  id_cursant: string;
  id_persoana: string;
  nume: string;
  prenume: string;
  telefon: string | null;
  email: string | null;
  data_nasterii: string | null;
  adresa: string | null;
  stare: StareCursant;
  observatii: string | null;
};

export type FiltreListaCursanti = {
  cautare?: string | null;
  stare?: StareCursant | null;
  limita?: number;
  offset?: number;
};

export type RezultatListaCursanti = {
  cursanti: CursantListaAdministrativa[];
  total: number;
};

export async function citesteListaCursantiAdministrativ(
  filtre: FiltreListaCursanti = {},
): Promise<RezultatListaCursanti> {
  const supabase = await creeazaClientServer();

  const limita = filtre.limita ?? 25;
  const offset = filtre.offset ?? 0;

  async function citestePagina(
    limitaPagina: number,
    offsetPagina: number,
  ): Promise<CursantListaAdministrativa[]> {
    const { data, error } = await supabase.rpc(
      "lista_cursanti_administrativ",
      {
        p_cautare: filtre.cautare ?? null,
        p_stare: filtre.stare ?? null,
        p_limita: limitaPagina,
        p_offset: offsetPagina,
      },
    );

    if (error) {
      throw new Error(
        `Citirea listei de cursanti a esuat: ${error.code ?? "EROARE_RPC"}`,
      );
    }

    return (data ?? []) as CursantListaAdministrativa[];
  }

  const cursanti = await citestePagina(limita, offset);

  if (cursanti.length > 0) {
    return {
      cursanti,
      total: Number(cursanti[0].total_inregistrari) || 0,
    };
  }

  // Daca URL-ul cere un offset dincolo de ultima pagina,
  // facem o citire minima pentru a recupera totalul real.
  if (offset > 0) {
    const verificareTotal = await citestePagina(1, 0);

    return {
      cursanti,
      total: Number(verificareTotal[0]?.total_inregistrari ?? 0),
    };
  }

  return {
    cursanti: [],
    total: 0,
  };
}

export async function citesteDetaliiCursantAdministrativ(
  idCursant: string,
): Promise<DetaliiCursantAdministrativ | null> {
  const supabase = await creeazaClientServer();

  const { data, error } = await supabase.rpc(
    "detalii_cursant_administrativ",
    {
      p_id_cursant: idCursant,
    },
  );

  if (error) {
    if (error.code === "PZ002") {
      return null;
    }

    throw new Error(
      `Citirea detaliilor cursantului a esuat: ${error.code ?? "EROARE_RPC"}`,
    );
  }

  const randuri = (data ?? []) as DetaliiCursantAdministrativ[];

  return randuri[0] ?? null;
}
