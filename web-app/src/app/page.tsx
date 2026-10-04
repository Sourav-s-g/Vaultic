import { Landmark, ShieldCheck, Sparkles } from "lucide-react";

export default function Home() {
  return (
    <main className="workspace-page">
      <section className="workspace-heading" aria-labelledby="overview-heading">
        <div>
          <p className="eyebrow">PERSONAL FINANCE</p>
          <h1 id="overview-heading">Your workspace</h1>
          <p className="heading-copy">A quieter view of your financial life.</p>
        </div>
        <span className="foundation-badge">
          <span aria-hidden="true" className="status-dot" />
          Foundation ready
        </span>
      </section>

      <section className="welcome-surface" aria-label="Workspace status">
        <div className="welcome-mark" aria-hidden="true">
          <Landmark size={25} strokeWidth={1.6} />
        </div>
        <div className="welcome-copy">
          <p className="eyebrow">VAULTIC</p>
          <h2>Built around your numbers.</h2>
          <p>
            Your sign-in is ready. Private finance data features will appear
            here as the remaining approved phases are built.
          </p>
        </div>
        <div className="welcome-signals" aria-label="Foundation status">
          <div className="signal-row">
            <ShieldCheck size={17} aria-hidden="true" />
            <span>Server-rendered shell</span>
            <span className="signal-state">Ready</span>
          </div>
          <div className="signal-row">
            <Sparkles size={17} aria-hidden="true" />
            <span>Light and dark themes</span>
            <span className="signal-state">Ready</span>
          </div>
        </div>
      </section>

      <footer className="workspace-footer">
        <span>Vaultic</span>
        <span>Private by design</span>
      </footer>
    </main>
  );
}
