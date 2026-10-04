export const MAX_PAISA = 100_000_000_000_000;

const amountPattern = /^\d+(?:\.\d{1,2})?$/;

export function parseAmountToPaise(input: string): number {
  const value = input.trim();
  if (!amountPattern.test(value)) {
    throw new Error("Enter an amount with at most two decimal places.");
  }

  const [rupeesText, paiseText = ""] = value.split(".");
  const paise = BigInt(rupeesText) * BigInt(100) + BigInt(paiseText.padEnd(2, "0") || "0");
  if (paise <= BigInt(0)) throw new Error("Amount must be greater than zero.");
  if (paise > BigInt(MAX_PAISA)) throw new Error("Amount is too large.");
  return Number(paise);
}

export function paiseToDatabaseAmount(paise: number): number {
  if (!Number.isSafeInteger(paise) || paise <= 0) {
    throw new Error("Amount must be a positive, safe integer number of paise.");
  }

  const value = BigInt(paise);
  const rupees = value / BigInt(100);
  const remainder = (value % BigInt(100)).toString().padStart(2, "0");
  return Number(`${rupees}.${remainder}`);
}

export function databaseAmountToPaise(amount: number): number {
  if (!Number.isFinite(amount)) {
    throw new Error("Database amount must be finite.");
  }
  const input = amount.toString();
  const negative = input.startsWith("-");
  const unsigned = negative ? input.slice(1) : input;
  if (!amountPattern.test(unsigned)) throw new Error("Database amount must have at most two decimal places.");
  const [rupeesText, paiseText = ""] = unsigned.split(".");
  const paise = BigInt(rupeesText) * BigInt(100) + BigInt(paiseText.padEnd(2, "0") || "0");
  if (paise > BigInt(MAX_PAISA)) throw new Error("Database amount is too large.");
  return Number(negative ? -paise : paise);
}

export function formatPaise(paise: number): string {
  if (!Number.isSafeInteger(paise)) {
    throw new Error("Amount must be a safe integer number of paise.");
  }

  const value = BigInt(Math.abs(paise));
  const rupees = value / BigInt(100);
  const remainder = (value % BigInt(100)).toString().padStart(2, "0");
  const formattedRupees = new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(paise < 0 ? -rupees : rupees);
  return `${formattedRupees}.${remainder}`;
}
