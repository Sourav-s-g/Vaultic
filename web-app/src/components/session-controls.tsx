"use client";

import { LogOut } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/browser";
import { hasPublicSupabaseConfig } from "@/lib/supabase/env";

export function SessionControls() {
  const router = useRouter();
  const [email, setEmail] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!hasPublicSupabaseConfig()) return;

    const supabase = createClient();
    let active = true;
    void supabase.auth.getUser().then(({ data, error }) => {
      if (active) setEmail(error ? null : data.user?.email ?? null);
    }).catch(() => {
      if (active) setEmail(null);
    });
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (!active) return;
      if (event === "SIGNED_OUT") setEmail(null);
      else if (session?.user.email) setEmail(session.user.email);
    });

    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, []);

  async function signOut() {
    setError("");
    setBusy(true);
    try {
      const { error } = await createClient().auth.signOut();
      if (error) throw error;
      router.replace("/login");
      router.refresh();
    } catch {
      setError("Sign out failed. Please try again.");
    } finally {
      setBusy(false);
    }
  }

  if (!email) return null;

  return (
    <>
      <button aria-label="Sign out" className="session-control" disabled={busy} onClick={signOut} type="button">
        <LogOut aria-hidden="true" size={15} />
        <span>{busy ? "Signing out" : "Sign out"}</span>
      </button>
      {error && <span aria-live="polite" className="session-error" role="status">{error}</span>}
    </>
  );
}
