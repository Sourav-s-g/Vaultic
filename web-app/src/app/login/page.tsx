import { AuthPage } from "@/components/auth-page";
import { safeNextPath } from "@/lib/auth/safe-next-path";

type LoginSearchParams = Promise<Record<string, string | string[] | undefined>>;

export default async function LoginPage({ searchParams }: { searchParams: LoginSearchParams }) {
  const query = await searchParams;
  const next = Array.isArray(query.next) ? query.next[0] : query.next;
  const passwordUpdated = Array.isArray(query.passwordUpdated) ? query.passwordUpdated[0] : query.passwordUpdated;
  const confirmation = Array.isArray(query.confirmation) ? query.confirmation[0] : query.confirmation;
  return <AuthPage mode="login" nextPath={safeNextPath(next)} passwordUpdated={passwordUpdated === "1"} confirmationFailed={confirmation === "failed"} />;
}
