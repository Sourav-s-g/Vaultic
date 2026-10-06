import { CategoriesPage } from "@/components/categories-page";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Edit Categories · Vaultic",
};

export default function CategoriesRoute() {
  return <CategoriesPage />;
}
