"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/browser";
import { hasPublicSupabaseConfig } from "@/lib/supabase/env";

const recoveryExchanges = new Map<string, Promise<boolean>>();

function exchangeRecoveryCode(code: string) {
  const existing = recoveryExchanges.get(code);
  if (existing) return existing;

  const exchange = createClient().auth.exchangeCodeForSession(code)
    .then(({ error: exchangeError }) => !exchangeError)
    .catch(() => false);
  recoveryExchanges.set(code, exchange);
  return exchange;
}

export function ResetPasswordForm({ code, providerError }: { code: string | null; providerError: string | null }) {
  const router = useRouter();
  const configured = hasPublicSupabaseConfig();
  const [stage, setStage] = useState<"checking" | "ready" | "error">(providerError || !configured ? "error" : "checking");
  const [password, setPassword] = useState("");
  const [confirmation, setConfirmation] = useState("");
  const [visible, setVisible] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (providerError || !configured) {
      return;
    }

    const supabase = createClient();
    let active = true;
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event) => {
      if (event === "PASSWORD_RECOVERY" && active) setStage("ready");
    });

    async function prepareRecovery() {
      if (code) {
        const exchanged = await exchangeRecoveryCode(code);
        if (active) setStage(exchanged ? "ready" : "error");
        return;
      }

      try {
        const { data: { session } } = await supabase.auth.getSession();
        if (active) setStage(session ? "ready" : "error");
      } catch {
        if (active) setStage("error");
      }
    }

    void prepareRecovery();
    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, [code, configured, providerError]);

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    if (password.length < 8) {
      setError("Use a password with at least 8 characters.");
      return;
    }
    if (password !== confirmation) {
      setError("Passwords do not match.");
      return;
    }

    setBusy(true);
    try {
      const { error: updateError } = await createClient().auth.updateUser({ password });
      if (updateError) {
        setError("We couldn't update your password. The link may have expired or already been used.");
        setStage("error");
        return;
      }
      router.replace("/login?passwordUpdated=1");
      router.refresh();
    } catch {
      setError("We couldn't update your password. Request a new reset link and try again.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="auth-page">
      <div className="auth-shell">
        <header className="auth-brand">
          <Link aria-label="Vaultic home" className="auth-brand-link" href="/">
            <span className="auth-brand-mark" aria-hidden="true">V</span>
            <span>Vaultic</span>
          </Link>
          <p className="auth-quote">A reset link is the first step back in.</p>
        </header>
        <section aria-labelledby="reset-title" className="auth-panel">
          <p className="auth-kicker">ACCOUNT RECOVERY</p>
          <h1 id="reset-title">Set a new password</h1>
          {stage === "checking" ? <p className="auth-description">Checking your secure reset link…</p> : stage === "error" ? <>
            <p className="auth-description">This reset link is invalid, expired, or already used. Request a new link to continue.</p>
            {error && <p className="auth-error" role="alert">{error}</p>}
            <Link className="auth-submit auth-action-link" href="/forgot-password">Request a new link</Link>
          </> : <>
            <p className="auth-description">Choose a password with at least 8 characters.</p>
            {error && <p className="auth-error" role="alert">{error}</p>}
            <form className="auth-form" onSubmit={submit}>
              <label className="auth-label" htmlFor="new-password">New password</label>
              <input
                autoComplete="new-password"
                className="auth-input"
                id="new-password"
                minLength={8}
                onChange={(event) => setPassword(event.target.value)}
                required
                type={visible ? "text" : "password"}
                value={password}
              />
              <label className="auth-label" htmlFor="confirm-password">Confirm new password</label>
              <div className="auth-password-wrap">
                <input
                  autoComplete="new-password"
                  className="auth-input"
                  id="confirm-password"
                  minLength={8}
                  onChange={(event) => setConfirmation(event.target.value)}
                  required
                  type={visible ? "text" : "password"}
                  value={confirmation}
                />
                <button className="auth-password-toggle" onClick={() => setVisible((current) => !current)} type="button">
                  {visible ? "Hide" : "Show"}
                </button>
              </div>
              <button className="auth-submit" disabled={busy} type="submit">
                {busy ? <><span aria-hidden="true" className="auth-spinner" />Saving…</> : "Update password"}
              </button>
            </form>
          </>}
          <div className="auth-switch"><Link href="/login">Back to sign in</Link></div>
        </section>
        <footer className="auth-footer">Vaultic <span aria-hidden="true">·</span> Your money, in view.</footer>
      </div>
    </main>
  );
}
