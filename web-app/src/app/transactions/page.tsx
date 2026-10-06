import { TransactionsPage } from "@/components/transaction-list";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Transaction History · Vaultic",
};

export default function TransactionsRoute() {
  return <TransactionsPage />;
}
