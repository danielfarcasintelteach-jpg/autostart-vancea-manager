export function obtineConfiguratiaSupabase() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const cheiePublicabila = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

  if (!url || !cheiePublicabila) {
    throw new Error(
      "Configureaza NEXT_PUBLIC_SUPABASE_URL si NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY in cod/.env.local.",
    );
  }

  return { url, cheiePublicabila };
}
