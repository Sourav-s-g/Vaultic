import { formatPaise } from "./index";

export function formatCardAmount(paise: number | null): string {
  if (paise === null) return "—";
  if (!Number.isSafeInteger(paise) || paise < 0) {
    throw new Error("Card amount must be a non-negative integer number of paise.");
  }
  const formatted = formatPaise(paise);
  return paise % 100 === 0 ? formatted.slice(0, -3) : formatted;
}
