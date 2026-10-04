export const MIN_TRANSACTION_DATE = "2020-01-01";
const DATE_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;
const DATE_TIME_PATTERN =
  /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,3}))?)?$/;

export type CalendarDateParts = {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
  millisecond: number;
};

function validateCalendarDate(value: string): CalendarDateParts {
  const match = DATE_TIME_PATTERN.exec(value);
  const dateMatch = DATE_PATTERN.exec(value);
  const parts = match ?? dateMatch;
  if (!parts) throw new Error("Use a valid local calendar date.");

  const year = Number(parts[1]);
  const month = Number(parts[2]);
  const day = Number(parts[3]);
  const hour = match ? Number(match[4]) : 0;
  const minute = match ? Number(match[5]) : 0;
  const second = match ? Number(match[6] ?? "0") : 0;
  const millisecond = match ? Number((match[7] ?? "").padEnd(3, "0") || "0") : 0;
  const check = new Date(Date.UTC(year, month - 1, day, hour, minute, second, millisecond));

  if (
    check.getUTCFullYear() !== year ||
    check.getUTCMonth() !== month - 1 ||
    check.getUTCDate() !== day ||
    hour > 23 ||
    minute > 59 ||
    second > 59
  ) {
    throw new Error("Use a valid local calendar date.");
  }

  return { year, month, day, hour, minute, second, millisecond };
}

export function parseDateInput(value: string): CalendarDateParts {
  return validateCalendarDate(value);
}

export function serializeFlutterLocalDateTime(value: string): string {
  const parts = validateCalendarDate(value);
  const date = `${parts.year.toString().padStart(4, "0")}-${parts.month.toString().padStart(2, "0")}-${parts.day.toString().padStart(2, "0")}`;
  const time = `${parts.hour.toString().padStart(2, "0")}:${parts.minute.toString().padStart(2, "0")}:${parts.second.toString().padStart(2, "0")}.${parts.millisecond.toString().padStart(3, "0")}`;
  return `${date}T${time}`;
}

export function transactionDateInputValue(value: string): string {
  const wallTimeMatch = DATE_TIME_PATTERN.exec(value);
  const dateMatch = DATE_PATTERN.exec(value);
  if (wallTimeMatch || dateMatch) {
    const parts = validateCalendarDate(value);
    return `${parts.year.toString().padStart(4, "0")}-${parts.month.toString().padStart(2, "0")}-${parts.day.toString().padStart(2, "0")}`;
  }

  const instant = new Date(value);
  if (!Number.isFinite(instant.getTime())) throw new Error("Stored transaction date is invalid.");
  return formatUtcCalendarDate(instant);
}

export function formatUtcCalendarDate(value: Date): string {
  return `${value.getUTCFullYear().toString().padStart(4, "0")}-${(value.getUTCMonth() + 1).toString().padStart(2, "0")}-${value.getUTCDate().toString().padStart(2, "0")}`;
}

export function formatDateInTimeZone(instant: Date, timeZone: string): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(instant);
  const value = Object.fromEntries(parts.map(({ type, value }) => [type, value]));
  return `${value.year}-${value.month}-${value.day}`;
}

export function todayDateInput(now = new Date()): string {
  const year = now.getFullYear().toString().padStart(4, "0");
  const month = (now.getMonth() + 1).toString().padStart(2, "0");
  const day = now.getDate().toString().padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export function addCalendarYear(value: string): string {
  const { year, month, day } = validateCalendarDate(value);
  const targetYear = year + 1;
  const lastDay = new Date(Date.UTC(targetYear, month, 0)).getUTCDate();
  return `${targetYear.toString().padStart(4, "0")}-${month.toString().padStart(2, "0")}-${Math.min(day, lastDay).toString().padStart(2, "0")}`;
}

export function isTransactionDateAllowed(value: string, today = todayDateInput()): boolean {
  try {
    validateCalendarDate(value);
    return value.slice(0, 10) >= MIN_TRANSACTION_DATE && value.slice(0, 10) <= addCalendarYear(today);
  } catch {
    return false;
  }
}

export function compareCalendarDates(left: string, right: string): number {
  return left.slice(0, 10).localeCompare(right.slice(0, 10));
}
