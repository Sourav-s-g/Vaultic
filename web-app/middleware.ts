import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";
import { safeNextPath } from "@/lib/auth/safe-next-path";
import { hasPublicSupabaseConfig } from "@/lib/supabase/env";
import { updateSession } from "@/lib/supabase/update-session";

export async function middleware(request: NextRequest) {
  if (request.nextUrl.pathname === "/api/health" || !hasPublicSupabaseConfig()) {
    return NextResponse.next();
  }

  const { response, user } = await updateSession(request);
  const pathname = request.nextUrl.pathname;
  const isAuthPage = ["/login", "/signup", "/forgot-password"].includes(pathname);
  const isProtectedPage = pathname === "/" || pathname.startsWith("/app/") ||
    ["/transactions", "/categories", "/settings", "/trips", "/debts", "/owo"].some(
      (route) => pathname === route || pathname.startsWith(`${route}/`),
    );

  if (!user && isProtectedPage) {
    const loginUrl = request.nextUrl.clone();
    loginUrl.pathname = "/login";
    loginUrl.search = "";
    loginUrl.searchParams.set("next", safeNextPath(`${pathname}${request.nextUrl.search}`) ?? "/");
    const redirect = NextResponse.redirect(loginUrl);
    response.cookies.getAll().forEach((cookie) => redirect.cookies.set(cookie));
    return redirect;
  }

  const isPasswordUpdatedNotice = pathname === "/login" && request.nextUrl.searchParams.get("passwordUpdated") === "1";
  if (user && isAuthPage && !isPasswordUpdatedNotice) {
    const destination = safeNextPath(request.nextUrl.searchParams.get("next")) ?? "/";
    const redirectUrl = new URL(destination, request.url);
    const redirect = NextResponse.redirect(redirectUrl);
    response.cookies.getAll().forEach((cookie) => redirect.cookies.set(cookie));
    return redirect;
  }

  return response;
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)"],
};
