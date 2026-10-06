"use client";

import Link from "next/link";
import { ArrowDownRight, Plus, Trash2 } from "lucide-react";
import type { ReactNode } from "react";
import { DATA_COLORS, getCategoryColor, getCategoryIcon } from "@/lib/categories/data";
import { cardForeground } from "@/lib/categories/contrast";
import { SessionControls } from "@/components/session-controls";
import { formatCardAmount } from "@/lib/money/card";

export function AppHeader() {
  return (
    <header className="app-mobile-header">
      <Link className="app-mobile-title" href="/">Vaultic</Link>
      <div className="app-header-actions">
        <Link className="header-pill" href="/categories">Edit Categories</Link>
        <SessionControls />
      </div>
    </header>
  );
}

export type CategoryCardItem = {
  name: string;
  amountPaise: number | null;
  icon?: ReactNode;
  color?: string;
  href?: string;
};

export function CategoryCard({
  name,
  amountPaise,
  color = getCategoryColor(name),
  icon,
  href = "/transactions",
}: CategoryCardItem) {
  const contents = (
    <>
      <span className="category-card-icon" aria-hidden="true">{icon ?? <span className="category-card-glyph">{getCategoryIcon(name).slice(0, 1).toUpperCase()}</span>}</span>
      <span className="category-card-name" title={name}>{name}</span>
      <strong>{formatCardAmount(amountPaise)}</strong>
    </>
  );
  return (
    <Link aria-label={`${name}: ${formatCardAmount(amountPaise)}`} className="category-card" href={href} style={{ backgroundColor: color, color: cardForeground(color) }}>
      {contents}
    </Link>
  );
}

export function CategoryCardStrip({ categories }: { categories: CategoryCardItem[] }) {
  return (
    <section aria-label="Category totals" className="category-card-strip">
      <CategoryCard color={DATA_COLORS.expense} icon={<ArrowDownRight size={20} />} name="This Month Spent" amountPaise={null} href="/transactions" />
      {categories.map((item) => <CategoryCard key={item.name} {...item} />)}
      <Link aria-label="Add category" className="category-card category-card-add" href="/categories">
        <Plus aria-hidden="true" size={25} /><span>+ Add category</span>
      </Link>
    </section>
  );
}

export function DashboardTabs() {
  return (
    <div aria-label="Workspace views" className="dashboard-tabs" role="tablist">
      <Link aria-selected="true" className="dashboard-tab is-active" href="/transactions" role="tab">Transactions</Link>
    </div>
  );
}

export function FloatingAddButton() {
  return <Link aria-label="Add transaction" className="mobile-add-button" href="/transactions?new=1"><Plus aria-hidden="true" size={23} /></Link>;
}

export function CategoryTiles({
  categories,
  onRemove,
  disabled = false,
}: {
  categories: { id?: string; name: string; color?: string | null; icon?: string | null }[];
  onRemove?: (name: string) => void;
  disabled?: boolean;
}) {
  return (
    <ul className="category-tile-grid">
      {categories.map((category) => (
        <li className="category-tile" key={category.id ?? category.name}>
          <span aria-hidden="true" className="category-swatch" style={{ backgroundColor: getCategoryColor(category.name) }} />
          <span className="category-tile-name" title={category.name}>{category.name}</span>
          {onRemove && (
            <button aria-label={`Remove category: ${category.name}`} className="category-tile-remove" disabled={disabled} onClick={() => onRemove(category.name)} title={`Remove category: ${category.name}`} type="button">
              <Trash2 aria-hidden="true" size={16} />
            </button>
          )}
        </li>
      ))}
    </ul>
  );
}
