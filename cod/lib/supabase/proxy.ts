import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

import { obtineConfiguratiaSupabase } from "./configuratie";

export async function actualizeazaSesiunea(cerere: NextRequest) {
  let raspuns = NextResponse.next({ request: cerere });
  const { url, cheiePublicabila } = obtineConfiguratiaSupabase();

  const supabase = createServerClient(url, cheiePublicabila, {
    cookies: {
      getAll() {
        return cerere.cookies.getAll();
      },
      setAll(cookieuri, antete) {
        cookieuri.forEach(({ name, value }) => cerere.cookies.set(name, value));
        raspuns = NextResponse.next({ request: cerere });

        cookieuri.forEach(({ name, value, options }) =>
          raspuns.cookies.set(name, value, options),
        );
        Object.entries(antete).forEach(([nume, valoare]) =>
          raspuns.headers.set(nume, valoare),
        );
      },
    },
  });

  await supabase.auth.getClaims();

  return raspuns;
}
