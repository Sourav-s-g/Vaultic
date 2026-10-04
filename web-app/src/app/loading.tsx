export default function Loading() {
  return (
    <main aria-busy="true" aria-label="Loading Vaultic" className="auth-page">
      <div className="loading-brand">
        <span aria-hidden="true" className="loading-mark">V</span>
        <span>Vaultic</span>
        <span aria-hidden="true" className="auth-spinner" />
      </div>
    </main>
  );
}
