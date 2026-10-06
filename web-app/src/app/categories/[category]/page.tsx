import { CategoryDetailPage } from "@/components/category-detail";
import type { Metadata } from "next";

type CategoryRouteProps = { params: Promise<{ category: string }> };

export async function generateMetadata({ params }: CategoryRouteProps): Promise<Metadata> {
  const { category } = await params;
  return { title: `${category} · Vaultic` };
}

export default async function CategoryDetailRoute({ params }: CategoryRouteProps) {
  const { category } = await params;
  return <CategoryDetailPage category={category} />;
}
