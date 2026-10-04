import { AuthPage } from "@/components/auth-page";
import { safeNextPath } from "@/lib/auth/safe-next-path";

type SignupSearchParams = Promise<Record<string, string | string[] | undefined>>;

export default async function SignupPage({ searchParams }: { searchParams: SignupSearchParams }) {
  const query = await searchParams;
  const next = Array.isArray(query.next) ? query.next[0] : query.next;
  return <AuthPage mode="signup" nextPath={safeNextPath(next)} />;
}
