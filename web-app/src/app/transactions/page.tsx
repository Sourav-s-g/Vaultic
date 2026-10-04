import { TransactionsPage } from "@/components/transaction-list";

type TransactionsSearchParams = Promise<Record<string, string | string[] | undefined>>;

export default async function TransactionsRoute({ searchParams }: { searchParams: TransactionsSearchParams }) {
  const query = await searchParams;
  const newValue = Array.isArray(query.new) ? query.new[0] : query.new;
  const startOpen = newValue === "1";
  return <TransactionsPage key={startOpen ? "new" : "list"} startOpen={startOpen} />;
}
