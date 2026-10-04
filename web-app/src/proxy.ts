import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";
import { safeNextPath } from "@/lib/auth/safe-next-path";
import { hasPublicSupabaseConfig } from "@/lib/supabase/env";
import { updateSession } from "@/lib/supabase/update-session";

export async function proxy(request: NextRequest) {
  if (request.nextUrl.pathname === "/api/health" || !hasPublicSupabaseConfig()) {
    return NextResponse.next();
  }

  const { response, user, supabase } = await updateSession(request);
  const pathname = request.nextUrl.pathname;
  const isAuthPage = ["/login", "/signup", "/forgot-password"].includes(pathname);
  const isSetupPage = pathname === "/setup";
  const isProtectedPage = pathname === "/" || isSetupPage || pathname.startsWith("/app/") ||
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

  const isCategoryRoute = pathname === "/" || isSetupPage || pathname === "/categories" || pathname === "/transactions";
  if (user && isCategoryRoute) {
    const { count, error } = await supabase
      .from("categories")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id);

    if (error && !isSetupPage) {
      const setupUrl = request.nextUrl.clone();
      setupUrl.pathname = "/setup";
      setupUrl.search = "";
      const destination = safeNextPath(`${pathname}${request.nextUrl.search}`);
      if (destination && destination !== "/") setupUrl.searchParams.set("next", destination);
      const redirect = NextResponse.redirect(setupUrl);
      response.cookies.getAll().forEach((cookie) => redirect.cookies.set(cookie));
      return redirect;
    }

    if (!error) {
      const hasCategories = (count ?? 0) > 0;
      if (!hasCategories && !isSetupPage) {
        const setupUrl = request.nextUrl.clone();
        setupUrl.pathname = "/setup";
        setupUrl.search = "";
        const destination = safeNextPath(`${pathname}${request.nextUrl.search}`);
        if (destination && destination !== "/") setupUrl.searchParams.set("next", destination);
        const redirect = NextResponse.redirect(setupUrl);
        response.cookies.getAll().forEach((cookie) => redirect.cookies.set(cookie));
        return redirect;
      }

      if (hasCategories && isSetupPage) {
        const destination = safeNextPath(request.nextUrl.searchParams.get("next"));
        const redirectUrl = new URL(destination && destination !== "/setup" ? destination : "/", request.url);
        const redirect = NextResponse.redirect(redirectUrl);
        response.cookies.getAll().forEach((cookie) => redirect.cookies.set(cookie));
        return redirect;
      }
    }
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
