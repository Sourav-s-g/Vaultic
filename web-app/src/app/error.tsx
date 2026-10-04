"use client";

import { useEffect } from "react";

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("Vaultic route error", error);
  }, [error]);

  return (
    <main className="workspace-page">
      <section aria-labelledby="error-title" className="error-surface" role="alert">
        <p className="eyebrow">VAULTIC</p>
        <h1 id="error-title">This view could not load.</h1>
        <p>Try again. Your account data has not been changed by this page error.</p>
        <button className="error-action" onClick={reset} type="button">Try again</button>
      </section>
    </main>
  );
}
