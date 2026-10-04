import { ResetPasswordForm } from "@/components/reset-password-form";

type ResetSearchParams = Promise<Record<string, string | string[] | undefined>>;

export default async function ResetPasswordPage({ searchParams }: { searchParams: ResetSearchParams }) {
  const query = await searchParams;
  const first = (value: string | string[] | undefined) => Array.isArray(value) ? value[0] : value;
  return <ResetPasswordForm code={first(query.code) ?? null} providerError={first(query.error) ?? first(query.error_code) ?? null} />;
}
