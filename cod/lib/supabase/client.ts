import { createBrowserClient } from "@supabase/ssr";

import { obtineConfiguratiaSupabase } from "./configuratie";

export function creeazaClientBrowser() {
  const { url, cheiePublicabila } = obtineConfiguratiaSupabase();

  return createBrowserClient(url, cheiePublicabila);
}
