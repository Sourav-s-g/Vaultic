"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { Eye, EyeOff, Landmark } from "lucide-react";
import { useEffect, useState } from "react";
import { safeNextPath } from "@/lib/auth/safe-next-path";
import { getCategories } from "@/lib/data/finance";
import { createClient } from "@/lib/supabase/browser";

type AuthMode = "login" | "signup" | "forgot";

const quotes: Record<"login" | "signup", string[]> = {
  login: [
    "Vaultic helps you know how you got broke.",
    "Checking if your wallet survived the weekend.",
    "Back for more financial accountability, are we?",
  ],
  signup: [
    "Track every detail, save more... hopefully.",
    "Step one: Facing the reality of your transaction history.",
    "Where your money learns to behave itself.",
  ],
};

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function AuthPage({
  mode,
  nextPath,
  passwordUpdated = false,
  confirmationFailed = false,
}: {
  mode: AuthMode;
  nextPath?: string | null;
  passwordUpdated?: boolean;
  confirmationFailed?: boolean;
}) {
  const router = useRouter();
  const [quoteIndex, setQuoteIndex] = useState(0);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmation, setConfirmation] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState(confirmationFailed ? "We couldn't confirm that email link. Request a new signup confirmation or try signing in." : "");
  const [error, setError] = useState("");

  useEffect(() => {
    if (mode === "forgot") return;
    const timer = window.setInterval(() => {
      setQuoteIndex((current) => (current + 1) % quotes[mode].length);
    }, 2000);
    return () => window.clearInterval(timer);
  }, [mode]);

  const normalizedEmail = email.trim().toLowerCase();
  const safeDestination = safeNextPath(nextPath) ?? "/";
  const isSignup = mode === "signup";
  const isForgot = mode === "forgot";

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setMessage("");

    if (!emailPattern.test(normalizedEmail)) {
      setError("Enter a valid email address.");
      return;
    }
    if (mode !== "forgot" && password.length < 8) {
      setError("Use a password with at least 8 characters.");
      return;
    }
    if (isSignup && password !== confirmation) {
      setError("Passwords do not match.");
      return;
    }

    setBusy(true);
    let authenticated = false;
    try {
      const supabase = createClient();

      if (mode === "login") {
        const { error: authError } = await supabase.auth.signInWithPassword({
          email: normalizedEmail,
          password,
        });
        if (authError) {
          setError("We couldn't sign you in. Check your email and password, then try again.");
          return;
        }
        authenticated = true;
        const destination = nextPath
          ? safeDestination
          : (await getCategories()).length === 0
            ? "/setup"
            : "/";
        router.replace(destination);
        router.refresh();
        return;
      }

      if (mode === "signup") {
        const { data, error: authError } = await supabase.auth.signUp({
          email: normalizedEmail,
          password,
          options: {
            emailRedirectTo: `${window.location.origin}/auth/callback?next=${encodeURIComponent(safeDestination)}`,
          },
        });
        if (authError) {
          setError("We couldn't create your account. Check your details and try again.");
          return;
        }
        if (data.user?.identities?.length === 0) {
          setError("An account with this email already exists. Please log in.");
          return;
        }
        if (!data.session) {
          setMessage("Your account is created. Check your email to confirm it, then log in.");
          return;
        }
        authenticated = true;
        const destination = nextPath
          ? safeDestination
          : (await getCategories()).length === 0
            ? "/setup"
            : "/";
        router.replace(destination);
        router.refresh();
        return;
      }

      const { error: resetError } = await supabase.auth.resetPasswordForEmail(normalizedEmail, {
        redirectTo: `${window.location.origin}/reset-password`,
      });
      if (resetError) {
        setError("We couldn't send the reset email. Check the site's Supabase redirect configuration and try again.");
        return;
      }
      setMessage("If an account exists for this email, a password-reset link has been sent.");
    } catch {
      setError(authenticated
        ? "You're signed in, but we couldn't load your categories. Reload the page to try again."
        : isForgot
          ? "We couldn't request a reset link right now. Please try again."
          : "We couldn't complete that request. Please try again.");
    } finally {
      setBusy(false);
    }
  }

  const quote = mode === "forgot" ? "A reset link is the first step back in." : quotes[mode][quoteIndex];

  return (
    <main className="auth-page">
      <div className="auth-shell">
        <header className="auth-brand">
          <Link aria-label="Vaultic home" className="auth-brand-link" href="/">
            <span className="auth-brand-mark"><Landmark aria-hidden="true" size={19} /></span>
            <span>Vaultic</span>
          </Link>
          {!isForgot && <p aria-live="polite" className="auth-quote" key={quote}>{quote}</p>}
        </header>

        <section aria-labelledby="auth-title" className="auth-panel">
          <p className="auth-kicker">PERSONAL FINANCE</p>
          <h1 id="auth-title">{isForgot ? "Reset your password" : isSignup ? "Create your account" : "Welcome back"}</h1>
          <p className="auth-description">
            {isForgot
              ? "Enter your email and we'll send a secure reset link if an account exists."
              : isSignup
                ? "A clearer picture of your money starts here."
                : "Sign in to continue to your private workspace."}
          </p>

          {passwordUpdated && <p className="auth-notice" role="status">Password updated. Sign in with your new password.</p>}
          {message && <p className="auth-notice" role="status">{message}</p>}
          {error && <p className="auth-error" role="alert">{error}</p>}

          <form className="auth-form" onSubmit={submit}>
            <label className="auth-label" htmlFor="email">Email address</label>
            <input
              autoComplete="email"
              autoCapitalize="none"
              className="auth-input"
              id="email"
              inputMode="email"
              name="email"
              onChange={(event) => setEmail(event.target.value)}
              required
              type="email"
              value={email}
            />

            {!isForgot && <>
              <label className="auth-label" htmlFor="password">Password</label>
              <div className="auth-password-wrap">
                <input
                  autoComplete={isSignup ? "new-password" : "current-password"}
                  className="auth-input"
                  id="password"
                  minLength={8}
                  name="password"
                  onChange={(event) => setPassword(event.target.value)}
                  required
                  type={showPassword ? "text" : "password"}
                  value={password}
                />
                <button
                  aria-label={showPassword ? "Hide password" : "Show password"}
                  className="auth-password-toggle"
                  onClick={() => setShowPassword((visible) => !visible)}
                  type="button"
                >
                  {showPassword ? <EyeOff aria-hidden="true" size={17} /> : <Eye aria-hidden="true" size={17} />}
                </button>
              </div>
              {isSignup && <>
                <label className="auth-label" htmlFor="confirmation">Confirm password</label>
                <input
                  autoComplete="new-password"
                  className="auth-input"
                  id="confirmation"
                  minLength={8}
                  name="confirmation"
                  onChange={(event) => setConfirmation(event.target.value)}
                  required
                  type={showPassword ? "text" : "password"}
                  value={confirmation}
                />
                <p className="auth-hint">Use at least 8 characters.</p>
              </>}
            </>}

            {!isSignup && !isForgot && <div className="auth-inline-link">
              <Link href="/forgot-password">Forgot password?</Link>
            </div>}

            <button className="auth-submit" disabled={busy} type="submit">
              {busy ? <><span aria-hidden="true" className="auth-spinner" />Working…</> : isForgot ? "Send reset link" : isSignup ? "Create account" : "Sign in"}
            </button>
          </form>

          <div className="auth-switch">
            {isForgot ? <Link href="/login">Back to sign in</Link> : isSignup ? <>
              <span>Already have an account?</span> <Link href="/login">Sign in</Link>
            </> : <>
              <span>New to Vaultic?</span> <Link href="/signup">Create an account</Link>
            </>}
          </div>
        </section>
        <footer className="auth-footer">Vaultic <span aria-hidden="true">·</span> Your money, in view.</footer>
      </div>
    </main>
  );
}
