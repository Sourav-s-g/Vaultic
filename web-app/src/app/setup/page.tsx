import { safeNextPath } from "@/lib/auth/safe-next-path";
import { CategorySetup } from "@/components/category-setup";

type SetupSearchParams = Promise<Record<string, string | string[] | undefined>>;

export default async function SetupPage({ searchParams }: { searchParams: SetupSearchParams }) {
  const query = await searchParams;
  const next = Array.isArray(query.next) ? query.next[0] : query.next;
  return <CategorySetup nextPath={safeNextPath(next)} />;
}
