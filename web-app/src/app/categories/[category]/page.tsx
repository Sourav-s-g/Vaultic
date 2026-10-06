import { CategoryDetailPage } from "@/components/category-detail";

export default async function CategoryDetailRoute({ params }: { params: Promise<{ category: string }> }) {
  const { category } = await params;
  return <CategoryDetailPage category={category} />;
}
