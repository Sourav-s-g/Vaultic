"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Landmark, LayoutDashboard, Moon, ReceiptText, Shapes, Sun } from "lucide-react";
import { useTheme } from "next-themes";
import { useEffect, useState, useSyncExternalStore, type ReactNode } from "react";
import { SessionControls } from "@/components/session-controls";
import { DashboardHeader, FloatingAddButton } from "@/components/finance-ui";
import { TransactionForm } from "@/components/transaction-form";
import { useCurrentUserId } from "@/lib/data/hooks";

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

type WorkspaceToast = {
  message: string;
  error?: boolean;
  onUndo?: () => Promise<void> | void;
};

function WorkspaceComposer() {
  const user = useCurrentUserId();
  const [open, setOpen] = useState(false);
  const [toast, setToast] = useState<WorkspaceToast | null>(null);

  useEffect(() => {
    const handleToast = (event: Event) => {
      const detail = (event as CustomEvent<WorkspaceToast>).detail;
      if (!detail) return;
      setToast(detail);
    };
    window.addEventListener("vaultic:toast", handleToast as EventListener);
    return () => window.removeEventListener("vaultic:toast", handleToast as EventListener);
  }, []);

  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(null), toast.error ? 8000 : 5000);
    return () => window.clearTimeout(timer);
  }, [toast]);

  return (
    <>
      <FloatingAddButton onClick={() => setOpen(true)} />
      {open && user.data && (
        <TransactionForm
          onClose={() => setOpen(false)}
          onSaved={() => setToast({ message: "Transaction saved." })}
          userId={user.data}
        />
      )}
      {toast && (
        <div aria-live="polite" className="toast-message workspace-toast" role="status">
          <span>{toast.message}</span>
          {toast.onUndo && <button disabled={toast.error} onClick={() => { void toast.onUndo?.(); }} type="button">Undo</button>}
          <button aria-label="Dismiss notification" onClick={() => setToast(null)} type="button">Dismiss</button>
        </div>
      )}
    </>
  );
}

export function WorkspaceShell({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const isHome = pathname === "/";
  const isCategories = pathname.startsWith("/categories");
  const isTransactions = pathname.startsWith("/transactions");
  const isAuthRoute = ["/login", "/signup", "/forgot-password", "/reset-password"].includes(pathname);
  const isSetupPage = pathname === "/setup";

  if (isAuthRoute) return <div className="auth-frame">{children}</div>;

  return (
    <div className={`app-frame${isSetupPage ? " is-setup" : ""}`}>
      <aside aria-label="Primary navigation" className="desktop-rail">
        <Link aria-label="Vaultic Dashboard" className="brand-lockup" href="/">
          <span className="brand-symbol"><Landmark aria-hidden="true" size={18} /></span>
          <span className="brand-name">Vaultic</span>
        </Link>
        <p className="rail-caption">WORKSPACE</p>
        <Link aria-current={isHome ? "page" : undefined} className="rail-link" href="/">
          <LayoutDashboard aria-hidden="true" size={17} />
          <span>Dashboard</span>
        </Link>
        <Link aria-current={isTransactions ? "page" : undefined} className="rail-link" href="/transactions">
          <ReceiptText aria-hidden="true" size={17} />
          <span>Transaction History</span>
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
        {isHome && <DashboardHeader />}
        {children}
      </div>

      <WorkspaceComposer />
    </div>
  );
}
