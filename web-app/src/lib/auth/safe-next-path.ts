export function safeNextPath(candidate: string | null | undefined): string | null {
  if (!candidate || candidate.length > 2048 || !candidate.startsWith("/") || candidate.startsWith("//")) {
    return null;
  }

  if (candidate.includes("\\") || /[\u0000-\u001f\u007f]/.test(candidate)) return null;

  try {
    const decoded = decodeURIComponent(candidate);
    if (decoded.startsWith("//") || decoded.includes("\\")) return null;
  } catch {
    return null;
  }

  const target = new URL(candidate, "https://vaultic.invalid");
  if (target.origin !== "https://vaultic.invalid" || target.pathname.startsWith("//")) return null;

  return `${target.pathname}${target.search}${target.hash}`;
}