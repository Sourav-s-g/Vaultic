export const DATA_COLORS = {
  custom: "#9E9E9E",
  suggested: {
    Food: "#FF9800",
    Stationary: "#2196F3",
    Outings: "#9C27B0",
    Travel: "#4CAF50",
    Shopping: "#E91E63",
    Healthcare: "#F44336",
    Education: "#3F51B5",
    Entertainment: "#009688",
    Transport: "#00BCD4",
    Bills: "#795548",
  },
  dashboard: [
    "#2196F3",
    "#9C27B0",
    "#FF9800",
    "#009688",
    "#E91E63",
    "#3F51B5",
    "#00BCD4",
    "#FFC107",
    "#FF5722",
    "#03A9F4",
  ],
} as const;

export type SuggestedCategoryName = keyof typeof DATA_COLORS.suggested;

export type CategoryDraft = {
  name: string;
  color: string;
  icon: string;
};

const suggestedIcons: Record<SuggestedCategoryName, string> = {
  Food: "utensils",
  Stationary: "pencil",
  Outings: "ticket",
  Travel: "car",
  Shopping: "shopping-bag",
  Healthcare: "heart-pulse",
  Education: "graduation-cap",
  Entertainment: "film",
  Transport: "bus",
  Bills: "receipt",
};

export const SUGGESTED_CATEGORIES: CategoryDraft[] = (
  Object.keys(DATA_COLORS.suggested) as SuggestedCategoryName[]
).map((name) => ({
  name,
  color: DATA_COLORS.suggested[name],
  icon: suggestedIcons[name],
}));

export const INITIAL_CATEGORIES = SUGGESTED_CATEGORIES.slice(0, 5);

export function normalizeCategoryName(name: string): string {
  return name.trim().toLocaleLowerCase("en");
}

export function findSuggestedCategory(name: string): CategoryDraft | undefined {
  const normalized = normalizeCategoryName(name);
  return SUGGESTED_CATEGORIES.find((category) => normalizeCategoryName(category.name) === normalized);
}

export function fnv1a(value: string): number {
  let hash = 0x811c9dc5;
  for (const byte of new TextEncoder().encode(value)) {
    hash ^= byte;
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash >>> 0;
}

export function getCategoryColor(name: string): string {
  const suggested = findSuggestedCategory(name);
  if (suggested) return suggested.color;
  const normalized = normalizeCategoryName(name);
  const colorIndex = fnv1a(normalized) % DATA_COLORS.dashboard.length;
  return DATA_COLORS.dashboard[colorIndex];
}

export function getCategoryIcon(name: string): string {
  return findSuggestedCategory(name)?.icon ?? "tag";
}

export function createCategoryDraft(name: string): CategoryDraft {
  const suggested = findSuggestedCategory(name);
  const normalizedName = name.trim();
  return suggested
    ? { ...suggested, name: normalizedName }
    : { name: normalizedName, color: getCategoryColor(normalizedName), icon: "tag" };
}

export function duplicateCategory(categories: readonly { name: string }[], name: string): boolean {
  const normalized = normalizeCategoryName(name);
  return categories.some((category) => normalizeCategoryName(category.name) === normalized);
}
