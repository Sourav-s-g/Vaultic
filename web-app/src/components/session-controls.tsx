"use client";

import { LogOut } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Modal } from "@/components/modal";
import { createClient } from "@/lib/supabase/browser";
import { hasPublicSupabaseConfig } from "@/lib/supabase/env";

export function SessionControls() {
  const router = useRouter();
  const [email, setEmail] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [confirming, setConfirming] = useState(false);

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
      <button aria-label="Logout" className="session-control" disabled={busy} onClick={() => setConfirming(true)} type="button">
        <LogOut aria-hidden="true" size={15} />
        <span>{busy ? "Signing out" : "Logout"}</span>
      </button>
      {error && !confirming && <span aria-live="polite" className="session-error" role="status">{error}</span>}
      <Modal className="confirm-dialog" closeDisabled={busy} onClose={() => setConfirming(false)} open={confirming} titleId="logout-confirm-title">
        <section className="modal-content">
          <h2 id="logout-confirm-title">Log out of Vaultic?</h2>
          <p>Your account will be signed out on this device.</p>
          {error && <p className="inline-error" role="alert">{error}</p>}
          <div className="wizard-actions">
            <button className="button button-secondary" disabled={busy} onClick={() => setConfirming(false)} type="button">Cancel</button>
            <button className="button button-primary" disabled={busy} onClick={() => void signOut()} type="button">{busy ? "Signing out…" : "Logout"}</button>
          </div>
        </section>
      </Modal>
    </>
  );
}
