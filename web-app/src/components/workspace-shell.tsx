"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Landmark, LayoutDashboard, Moon, Plus, ReceiptText, Shapes, Sun } from "lucide-react";
import { useTheme } from "next-themes";
import { useSyncExternalStore, type ReactNode } from "react";
import { SessionControls } from "@/components/session-controls";
import { AppHeader, FloatingAddButton } from "@/components/finance-ui";

const subscribeToNothing = () => () => undefined;
const getHydratedSnapshot = () => true;
const getServerSnapshot = () => false;

function ThemeToggle() {
  const { resolvedTheme, setTheme } = useTheme();
  const mounted = useSyncExternalStore(subscribeToNothing, getHydratedSnapshot, getServerSnapshot);
  const isDark = mounted && resolvedTheme === "dark";
  const Icon = isDark ? Sun : Moon;

  return (
    <button
      aria-label={mounted ? `Switch to ${isDark ? "light" : "dark"} theme` : "Change theme"}
      className="theme-toggle"
      onClick={() => setTheme(isDark ? "light" : "dark")}
      title={mounted ? `Switch to ${isDark ? "light" : "dark"} theme` : "Change theme"}
      type="button"
      disabled={!mounted}
    >
      <Icon aria-hidden="true" size={16} />
    </button>
  );
}

export function WorkspaceShell({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const isHome = pathname === "/";
  const isCategories = pathname.startsWith("/categories");
  const isTransactions = pathname.startsWith("/transactions");
  const isAuthRoute = ["/login", "/signup", "/forgot-password", "/reset-password"].includes(pathname);
  const isSetupPage = pathname === "/setup";
  const currentPage = isCategories ? "Categories" : isTransactions ? "All transactions" : pathname === "/setup" ? "Setup" : "Home";

  if (isAuthRoute) return <div className="auth-frame">{children}</div>;

  return (
    <div className={`app-frame${isSetupPage ? " is-setup" : ""}`}>
      <aside aria-label="Primary navigation" className="desktop-rail">
        <Link aria-label="Vaultic home" className="brand-lockup" href="/">
          <span className="brand-symbol"><Landmark aria-hidden="true" size={18} /></span>
          <span className="brand-name">Vaultic</span>
        </Link>
        <p className="rail-caption">WORKSPACE</p>
        <Link aria-current={isHome ? "page" : undefined} className="rail-link" href="/">
          <LayoutDashboard aria-hidden="true" size={17} />
          <span>Home</span>
        </Link>
        <Link aria-current={isTransactions ? "page" : undefined} className="rail-link" href="/transactions">
          <ReceiptText aria-hidden="true" size={17} />
          <span>All transactions</span>
        </Link>
        <Link aria-current={isCategories ? "page" : undefined} className="rail-link" href="/categories">
          <Shapes aria-hidden="true" size={17} />
          <span>Categories</span>
        </Link>
        <div className="rail-bottom">
          <span>Appearance</span>
          <div className="mobile-session-actions">
            <SessionControls />
            <ThemeToggle />
          </div>
        </div>
      </aside>

      <div className="main-column">
        <header className="mobile-header">
          <AppHeader />
        </header>
        <header className="topbar">
          <div aria-label="Breadcrumb" className="breadcrumb">
            <span>Workspace</span>
            <span aria-hidden="true">/</span>
            <span className="breadcrumb-current">{currentPage}</span>
          </div>
          <div className="topbar-actions">
            <span className="topbar-meta"><span aria-hidden="true" className="status-dot" /> Personal workspace</span>
            <Link className="button button-primary header-add-button" href="/transactions?new=1"><Plus aria-hidden="true" size={16} /> Add transaction</Link>
            <SessionControls />
          </div>
        </header>
        {children}
      </div>

      <FloatingAddButton />
    </div>
  );
}
