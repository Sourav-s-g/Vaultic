"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { Landmark, Shapes, Sparkles } from "lucide-react";
import { RecentTransactions } from "@/components/transaction-list";
import { useCategories, useCurrentUserId } from "@/lib/data/hooks";

export default function Home() {
  const router = useRouter();
  const user = useCurrentUserId();
  const categories = useCategories(user.data);

  useEffect(() => {
    if (categories.data && categories.data.length === 0) router.replace("/setup");
  }, [categories.data, router]);

  if (user.isLoading || categories.isLoading) {
    return <main className="workspace-page" aria-busy="true"><div className="skeleton skeleton-title" /><div className="skeleton skeleton-panel" /></main>;
  }
  if (user.error || categories.error) {
    return (
      <main className="workspace-page">
        <section className="feature-panel" role="alert">
          <h1>Could not load your workspace</h1>
          <p>{(user.error ?? categories.error)?.message}</p>
          <button className="button button-primary" onClick={() => { void user.refetch(); void categories.refetch(); }} type="button">Try again</button>
        </section>
      </main>
    );
  }
  if (categories.data?.length === 0) return <main className="workspace-page" aria-live="polite"><div className="skeleton skeleton-panel" /><p>Opening setup…</p></main>;

  return (
    <main className="workspace-page">
      <section className="workspace-heading" aria-labelledby="overview-heading">
        <div><p className="eyebrow">PERSONAL FINANCE</p><h1 id="overview-heading">Your workspace</h1><p className="heading-copy">A clear place to manage categories and transaction history.</p></div>
        <span className="foundation-badge"><span aria-hidden="true" className="status-dot" />Online</span>
      </section>
      <section className="welcome-surface" aria-label="Workspace status">
        <div className="welcome-mark" aria-hidden="true"><Landmark size={25} strokeWidth={1.6} /></div>
        <div className="welcome-copy">
          <p className="eyebrow">VAULTIC</p>
          <h2>Your records, organized.</h2>
          <p>Manage spending categories and maintain a searchable transaction ledger. Dashboard summaries and balances are not part of this phase.</p>
        </div>
        <div className="welcome-signals" aria-label="Available capabilities">
          <div className="signal-row"><Shapes size={17} aria-hidden="true" /><span>Categories</span><span className="signal-state">Ready</span></div>
          <div className="signal-row"><Sparkles size={17} aria-hidden="true" /><span>Transaction history</span><span className="signal-state">Ready</span></div>
        </div>
      </section>
      <RecentTransactions />
      <footer className="workspace-footer"><span>Vaultic</span><span>Private by design</span></footer>
    </main>
  );
}
