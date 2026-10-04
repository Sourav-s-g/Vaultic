import { NextResponse, type NextRequest } from "next/server";
import { safeNextPath } from "@/lib/auth/safe-next-path";
import { hasPublicSupabaseConfig } from "@/lib/supabase/env";
import { createClient } from "@/lib/supabase/server";

export async function GET(request: NextRequest) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const destination = safeNextPath(url.searchParams.get("next")) ?? "/";

  if (!code) {
    return NextResponse.redirect(new URL("/login?confirmation=failed", request.url));
  }

  if (!hasPublicSupabaseConfig()) {
    return NextResponse.redirect(new URL("/login?confirmation=failed", request.url));
  }

  try {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (error) return NextResponse.redirect(new URL("/login?confirmation=failed", request.url));
    return NextResponse.redirect(new URL(destination, request.url));
  } catch {
    return NextResponse.redirect(new URL("/login?confirmation=failed", request.url));
  }
}
