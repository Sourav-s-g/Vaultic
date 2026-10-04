import { todayDateInput } from "../dates";

export type ParsedTransaction = {
  amount: string | null;
  category: string | null;
  type: "Credit" | "Debit";
  description: string;
  date: string;
  confidence: number;
  suggestions: string[];
  rawInput: string;
};

const categoryKeywords: Record<string, string[]> = {
  food: ["lunch", "dinner", "breakfast", "food", "restaurant", "cafe", "meal", "eat", "pizza", "burger", "coffee", "tea", "snacks", "grocery", "biryani", "juice", "bakery", "ice cream", "canteen", "kitchen", "veg", "non-veg", "swiggy", "zomato"],
  transport: ["fuel", "petrol", "diesel", "uber", "taxi", "metro", "bus", "train", "flight", "cab", "auto", "rickshaw", "parking", "toll", "fare", "ticket", "ola", "airfare", "commute", "subway", "carwash", "driver", "transport", "travel"],
  shopping: ["buy", "purchase", "shopping", "mall", "store", "market", "amazon", "flipkart", "bigbasket", "myntra", "ajio", "fashion", "clothes", "footwear", "electronics", "appliance", "supermarket", "accessory", "home decor", "gadget", "boutique", "jewelry"],
  income: ["salary", "wage", "income", "payment", "received", "got", "paid me", "earned", "bonus", "commission", "interest", "refund", "dividend", "cashback", "freelance", "stipend", "reimbursement", "transfer in", "deposit", "inflow"],
  entertainment: ["movie", "cinema", "netflix", "spotify", "game", "concert", "show", "theatre", "event", "music", "ticket", "fun", "outing", "amusement", "party", "club", "youtube", "subscription", "hotstar", "zee5", "bookmyshow"],
  bills: ["bill", "electricity", "water", "internet", "phone", "mobile", "rent", "gas", "postpaid", "prepaid", "wifi", "broadband", "tv", "dth", "insurance", "loan emi", "credit card", "maintenance", "subscription", "charge", "payment due"],
  health: ["hospital", "doctor", "medicine", "pharmacy", "clinic", "medical", "health", "checkup", "test", "scan", "diagnostic", "surgery", "dentist", "eye care", "therapy", "covid", "vaccine", "fitness", "gym", "protein", "consultation"],
  education: ["school", "college", "tuition", "course", "book", "study", "exam", "fees", "class", "university", "training", "online course", "udemy", "coursera", "byjus", "notebook", "stationery", "learning", "coaching", "degree", "certificate"],
  general: ["misc", "other", "unknown", "general", "personal", "expense", "transfer", "miscellaneous", "temp", "adjustment", "undefined", "others", "service", "fee", "transaction"],
};

const categoryVariations: Record<string, string[]> = {
  food: ["restaurant", "dining", "meal", "cafe", "canteen"],
  transport: ["travel", "commute", "vehicle", "car", "bike"],
  shopping: ["retail", "store", "market", "purchase"],
  income: ["salary", "earning", "revenue"],
  entertainment: ["fun", "leisure", "recreation"],
  bills: ["utilities", "payment", "due"],
  health: ["medical", "fitness", "wellness"],
  education: ["learning", "study", "school"],
  general: ["misc", "other", "personal"],
};

const creditKeywords = ["salary", "wage", "income", "received", "receive", "receiving", "credited", "credit", "cr", "got", "paid me", "earned", "refund", "bonus"];
const debitKeywords = ["spent", "paid", "bought", "purchase", "expense", "cost", "bill"];

function extractAmount(input: string): string | null {
  const cleaned = input.replace(/[₹,$€£]/g, "").trim();
  const matches = [...cleaned.matchAll(/(\d+(?:\.\d+)?)/g)];
  const amount = matches.at(-1)?.[1];
  return amount ? amount.replace(/,/g, "") : null;
}

function extractDescription(input: string, amount: string | null): string {
  let description = input.replace(/[₹,$€£]/g, " ");
  if (amount) {
    description = description.replace(new RegExp(`\\b${amount.replace(".", "\\.")}\\b`), "");
  }
  const words = description.trim().replace(/\s+/g, " ").split(" ");
  const filtered = words.filter((word) => word && !["for", "of", "the", "a", "an", "got", "paid", "spent"].includes(word.toLowerCase()));
  const result = filtered.join(" ");
  return result ? result[0].toUpperCase() + result.slice(1) : "Transaction";
}

function detectType(input: string): "Credit" | "Debit" | null {
  const tokens = input.split(/[^a-z0-9₹]+/).filter(Boolean);
  const matches = (keywords: string[]) =>
    keywords.some((keyword) => tokens.includes(keyword) || input.includes(keyword));
  if (matches(creditKeywords)) return "Credit";
  if (matches(debitKeywords)) return "Debit";
  return null;
}

function categoryMatchesGroup(category: string, group: string): boolean {
  const userName = category.toLowerCase();
  if (userName === group || userName.includes(group) || group.includes(userName.split(" ")[0])) return true;
  return (categoryVariations[group] ?? []).some(
    (variation) => userName.includes(variation) || variation.includes(userName.split(" ")[0]),
  );
}

function detectCategory(input: string, categories: readonly string[]): string | null {
  const direct = categories.find((category) => input.includes(category.toLowerCase()));
  if (direct) return direct;

  for (const [group, keywords] of Object.entries(categoryKeywords)) {
    const category = categories.find((candidate) => categoryMatchesGroup(candidate, group));
    if (category && keywords.some((keyword) => input.includes(keyword))) return category;
  }
  return null;
}

export function getCategorySuggestions(input: string, categories: readonly string[]): string[] {
  const normalized = input.trim().toLowerCase();
  if (!normalized) return [];

  const suggestions = categories.filter((category) => {
    const name = category.toLowerCase();
    return name.startsWith(normalized) || name.includes(normalized);
  });

  for (const [group, keywords] of Object.entries(categoryKeywords)) {
    const category = categories.find((candidate) => categoryMatchesGroup(candidate, group));
    if (
      category &&
      keywords.some((keyword) => keyword.startsWith(normalized) || keyword.includes(normalized)) &&
      !suggestions.includes(category)
    ) {
      suggestions.push(category);
    }
  }
  return suggestions.slice(0, 5);
}

export function parseTransactionInput(
  input: string,
  categories: readonly string[],
  today = todayDateInput(),
): ParsedTransaction {
  if (!input.trim()) {
    return { amount: null, category: null, type: "Debit", description: "", date: today, confidence: 0, suggestions: [], rawInput: input };
  }

  const normalized = input.toLowerCase().trim();
  const amount = extractAmount(input);
  const description = extractDescription(input, amount);
  const detectedType = detectType(normalized);
  const category = detectCategory(normalized, categories);
  let confidence = 0;
  if (amount !== null) confidence += 0.3;
  if (detectedType !== null) confidence += 0.2;
  if (category !== null) confidence += 0.3;
  if (amount !== null && description.length > 0) confidence += 0.2;

  return {
    amount,
    category,
    type: detectedType ?? "Debit",
    description,
    date: today,
    confidence: Math.min(confidence, 1),
    suggestions: getCategorySuggestions(normalized, categories),
    rawInput: input,
  };
}
