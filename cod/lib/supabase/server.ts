import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

import { obtineConfiguratiaSupabase } from "./configuratie";

export async function creeazaClientServer() {
  const depozitCookieuri = await cookies();
  const { url, cheiePublicabila } = obtineConfiguratiaSupabase();

  return createServerClient(url, cheiePublicabila, {
    cookies: {
      getAll() {
        return depozitCookieuri.getAll();
      },
      setAll(cookieuri) {
        try {
          cookieuri.forEach(({ name, value, options }) =>
            depozitCookieuri.set(name, value, options),
          );
        } catch {
          // Componentele server nu pot scrie cookie-uri; Proxy le actualizeaza.
        }
      },
    },
  });
}
