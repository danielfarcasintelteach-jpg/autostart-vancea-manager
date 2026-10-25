import { creeazaClientServer } from "@/lib/supabase/server";

export type StareInstructor = "activ" | "inactiv";

export type InstructorListaAdministrativa = {
  id_instructor: string;
  id_persoana: string;
  nume: string;
  prenume: string;
  telefon: string | null;
  email: string | null;
  data_angajarii: string | null;
  stare: StareInstructor;
  total_inregistrari: number;
};

export type DetaliiInstructorAdministrativ = {
  id_instructor: string;
  id_persoana: string;
  nume: string;
  prenume: string;
  telefon: string | null;
  email: string | null;
  data_nasterii: string | null;
  adresa: string | null;
  data_angajarii: string | null;
  stare: StareInstructor;
  observatii: string | null;
};

export type FiltreListaInstructori = {
  cautare?: string | null;
  stare?: StareInstructor | null;
  limita?: number;
  offset?: number;
};

export type RezultatListaInstructori = {
  instructori: InstructorListaAdministrativa[];
  total: number;
};

export async function citesteListaInstructoriAdministrativ(
  filtre: FiltreListaInstructori = {},
): Promise<RezultatListaInstructori> {
  const supabase = await creeazaClientServer();

  const limita = filtre.limita ?? 25;
  const offset = filtre.offset ?? 0;

  async function citestePagina(
    limitaPagina: number,
    offsetPagina: number,
  ): Promise<InstructorListaAdministrativa[]> {
    const { data, error } = await supabase.rpc(
      "lista_instructori_administrativ",
      {
        p_cautare: filtre.cautare ?? null,
        p_stare: filtre.stare ?? null,
        p_limita: limitaPagina,
        p_offset: offsetPagina,
      },
    );

    if (error) {
      throw new Error(
        `Citirea listei de instructori a esuat: ${error.code ?? "EROARE_RPC"}`,
      );
    }

    return (data ?? []) as InstructorListaAdministrativa[];
  }

  const instructori = await citestePagina(limita, offset);

  if (instructori.length > 0) {
    return {
      instructori,
      total: Number(instructori[0].total_inregistrari) || 0,
    };
  }

  if (offset > 0) {
    const verificareTotal = await citestePagina(1, 0);

    return {
      instructori,
      total: Number(verificareTotal[0]?.total_inregistrari ?? 0),
    };
  }

  return {
    instructori: [],
    total: 0,
  };
}

export async function citesteDetaliiInstructorAdministrativ(
  idInstructor: string,
): Promise<DetaliiInstructorAdministrativ | null> {
  const supabase = await creeazaClientServer();

  const { data, error } = await supabase.rpc(
    "detalii_instructor_administrativ",
    {
      p_id_instructor: idInstructor,
    },
  );

  if (error) {
    if (error.code === "PZ002") {
      return null;
    }

    throw new Error(
      `Citirea detaliilor instructorului a esuat: ${error.code ?? "EROARE_RPC"}`,
    );
  }

  const randuri = (data ?? []) as DetaliiInstructorAdministrativ[];

  return randuri[0] ?? null;
}