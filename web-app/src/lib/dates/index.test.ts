import { describe, expect, it } from "vitest";
import {
  addCalendarYear,
  formatDateInTimeZone,
  isTransactionDateAllowed,
  parseDateInput,
  serializeFlutterLocalDateTime,
  transactionDateInputValue,
} from "./index";

describe("transaction date convention", () => {
  it("preserves a selected local calendar date as offsetless Flutter ISO", () => {
    expect(serializeFlutterLocalDateTime("2024-02-29")).toBe("2024-02-29T00:00:00.000");
    expect(serializeFlutterLocalDateTime("2024-01-31T23:59")).toBe("2024-01-31T23:59:00.000");
  });

  it.each([
    ["2024-01-30T19:00:00.000Z", "2024-01-31"],
    ["2024-01-31T18:00:00.000Z", "2024-01-31"],
  ])("preserves the calendar day of an instant in Asia/Kolkata", (instant, expected) => {
    expect(formatDateInTimeZone(new Date(instant), "Asia/Kolkata")).toBe(expected);
    expect(transactionDateInputValue(serializeFlutterLocalDateTime(expected))).toBe(expected);
  });

  it("handles month-end and leap-day bounds", () => {
    expect(parseDateInput("2024-02-29").day).toBe(29);
    expect(addCalendarYear("2024-02-29")).toBe("2025-02-28");
    expect(serializeFlutterLocalDateTime("2024-12-31T23:30")).toBe("2024-12-31T23:30:00.000");
  });

  it("enforces minimum date and one calendar year ahead", () => {
    expect(isTransactionDateAllowed("2020-01-01", "2024-05-10")).toBe(true);
    expect(isTransactionDateAllowed("2019-12-31", "2024-05-10")).toBe(false);
    expect(isTransactionDateAllowed("2025-05-10", "2024-05-10")).toBe(true);
    expect(isTransactionDateAllowed("2025-05-11", "2024-05-10")).toBe(false);
  });

  it("does not reinterpret date-only strings as UTC instants", () => {
    expect(transactionDateInputValue("2024-01-31")).toBe("2024-01-31");
  });
});
