import { creeazaClientServer } from "@/lib/supabase/server";

export type StareVehicul =
  | "activ"
  | "service"
  | "indisponibil"
  | "inactiv";

export type VehiculListaAdministrativa = {
  id_vehicul: string;
  numar_inmatriculare: string;
  marca: string;
  model: string;
  an_fabricatie: number | null;
  stare: StareVehicul;
  total_inregistrari: number;
};

export type DetaliiVehiculAdministrativ = {
  id_vehicul: string;
  numar_inmatriculare: string;
  marca: string;
  model: string;
  an_fabricatie: number | null;
  stare: StareVehicul;
  observatii: string | null;
};

export type FiltreListaVehicule = {
  cautare?: string | null;
  stare?: StareVehicul | null;
  limita?: number;
  offset?: number;
};

export type RezultatListaVehicule = {
  vehicule: VehiculListaAdministrativa[];
  total: number;
};

export async function citesteListaVehiculeAdministrativ(
  filtre: FiltreListaVehicule = {},
): Promise<RezultatListaVehicule> {
  const supabase = await creeazaClientServer();

  const limita = filtre.limita ?? 25;
  const offset = filtre.offset ?? 0;

  async function citestePagina(
    limitaPagina: number,
    offsetPagina: number,
  ): Promise<VehiculListaAdministrativa[]> {
    const { data, error } = await supabase.rpc(
      "lista_vehicule_administrativ",
      {
        p_cautare: filtre.cautare ?? null,
        p_stare: filtre.stare ?? null,
        p_limita: limitaPagina,
        p_offset: offsetPagina,
      },
    );

    if (error) {
      throw new Error(
        `Citirea listei de vehicule a esuat: ${error.code ?? "EROARE_RPC"}`,
      );
    }

    return (data ?? []) as VehiculListaAdministrativa[];
  }

  const vehicule = await citestePagina(limita, offset);

  if (vehicule.length > 0) {
    return {
      vehicule,
      total: Number(vehicule[0].total_inregistrari) || 0,
    };
  }

  if (offset > 0) {
    const verificareTotal = await citestePagina(1, 0);

    return {
      vehicule,
      total: Number(verificareTotal[0]?.total_inregistrari ?? 0),
    };
  }

  return {
    vehicule: [],
    total: 0,
  };
}

export async function citesteDetaliiVehiculAdministrativ(
  idVehicul: string,
): Promise<DetaliiVehiculAdministrativ | null> {
  const supabase = await creeazaClientServer();

  const { data, error } = await supabase.rpc(
    "detalii_vehicul_administrativ",
    {
      p_id_vehicul: idVehicul,
    },
  );

  if (error) {
    if (error.code === "PZ002") {
      return null;
    }

    throw new Error(
      `Citirea detaliilor vehiculului a esuat: ${error.code ?? "EROARE_RPC"}`,
    );
  }

  const randuri = (data ?? []) as DetaliiVehiculAdministrativ[];

  return randuri[0] ?? null;
}