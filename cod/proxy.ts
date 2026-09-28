import type { NextRequest } from "next/server";

import { actualizeazaSesiunea } from "@/lib/supabase/proxy";

export async function proxy(cerere: NextRequest) {
  return actualizeazaSesiunea(cerere);
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
