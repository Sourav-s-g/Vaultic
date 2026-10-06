"use client";

import { useMemo, useState, type TouchEvent } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import type { TransactionRow } from "@/lib/data/finance";
import { transactionDateInputValue, parseDateInput } from "@/lib/dates";
import { DATA_COLORS } from "@/lib/categories/data";
import { databaseAmountToPaise, formatPaise } from "@/lib/money";
import { isCarryForwardTransaction } from "@/lib/finance-summary";

export type DonutSlice = {
  name: string;
  amountPaise: number;
  color: string;
};

function compactMoney(paise: number): string {
  const formatted = formatPaise(paise);
  return paise % 100 === 0 ? formatted.slice(0, -3) : formatted;
}

function polarPoint(radius: number, angle: number): [number, number] {
  const radians = ((angle - 90) * Math.PI) / 180;
  return [100 + radius * Math.cos(radians), 100 + radius * Math.sin(radians)];
}

function donutSegmentPath(startAngle: number, endAngle: number): string {
  const outerRadius = 78;
  const innerRadius = 35;
  const [outerStartX, outerStartY] = polarPoint(outerRadius, startAngle);
  const [outerEndX, outerEndY] = polarPoint(outerRadius, endAngle);
  const [innerEndX, innerEndY] = polarPoint(innerRadius, endAngle);
  const [innerStartX, innerStartY] = polarPoint(innerRadius, startAngle);
  const largeArc = endAngle - startAngle > 180 ? 1 : 0;
  return [
    `M ${outerStartX} ${outerStartY}`,
    `A ${outerRadius} ${outerRadius} 0 ${largeArc} 1 ${outerEndX} ${outerEndY}`,
    `L ${innerEndX} ${innerEndY}`,
    `A ${innerRadius} ${innerRadius} 0 ${largeArc} 0 ${innerStartX} ${innerStartY}`,
    "Z",
  ].join(" ");
}

export function CategoryDonutChart({
  slices,
  totalPaise,
  selectedCategory,
  onSelectCategory,
}: {
  slices: DonutSlice[];
  totalPaise: number;
  selectedCategory?: string;
  onSelectCategory: (category: string) => void;
}) {
  const total = slices.reduce((sum, slice) => sum + slice.amountPaise, 0);
  const segments = useMemo(() => {
    return slices.map((slice, index) => {
      const startAngle = slices.slice(0, index).reduce((sum, item) => sum + (total ? item.amountPaise / total : 0) * 360, 0);
      const percent = total ? (slice.amountPaise / total) * 100 : 0;
      const endAngle = startAngle + (percent / 100) * 360;
      return { ...slice, percent, startAngle, endAngle, midAngle: (startAngle + endAngle) / 2 };
    });
  }, [slices, total]);

  return (
    <section aria-labelledby="category-spend-title" className="feature-panel chart-panel donut-panel" data-testid="category-donut-card">
      <div className="panel-heading"><h2 id="category-spend-title">Category spend</h2><span className="muted-copy">Selected month</span></div>
      {segments.length === 0 || total === 0 ? (
        <p className="empty-state">No spending in this month.</p>
      ) : (
        <>
          <div className="donut-wrap">
            <svg aria-label="Category spending percentages" className="donut-chart" role="img" viewBox="0 0 200 200">
              <title>Category spending for the selected month</title>
              {segments.map((segment) => {
                const [labelX, labelY] = polarPoint(56, segment.midAngle);
                return (
                  <g key={segment.name}>
                    <path
                      d={donutSegmentPath(segment.startAngle, segment.endAngle)}
                      fill={segment.color}
                      opacity={selectedCategory && selectedCategory !== segment.name ? 0.38 : 1}
                      stroke="var(--surface)"
                      strokeWidth="1.5"
                    >
                      <title>{`${segment.name}: ${compactMoney(segment.amountPaise)} (${Math.round(segment.percent)}%)`}</title>
                    </path>
                    {segment.percent >= 5 && (
                      <text className="donut-percent-label" dominantBaseline="middle" textAnchor="middle" x={labelX} y={labelY}>
                        {Math.round(segment.percent)}%
                      </text>
                    )}
                  </g>
                );
              })}
            </svg>
            <div aria-hidden="true" className="donut-center"><strong>{compactMoney(totalPaise)}</strong><span>Spent</span></div>
          </div>
          <ul className="legend-list">
            {segments.map((segment) => (
              <li key={segment.name}>
                <button
                  aria-label={`Filter by ${segment.name}`}
                  aria-pressed={selectedCategory === segment.name}
                  className={`legend-key${selectedCategory === segment.name ? " is-selected" : ""}`}
                  onClick={() => onSelectCategory(selectedCategory === segment.name ? "" : segment.name)}
                  style={{ backgroundColor: segment.color }}
                  title={`${segment.name}: ${compactMoney(segment.amountPaise)} (${Math.round(segment.percent)}%)`}
                  type="button"
                />
                <button
                  aria-pressed={selectedCategory === segment.name}
                  className="legend-label"
                  onClick={() => onSelectCategory(selectedCategory === segment.name ? "" : segment.name)}
                  title={segment.name}
                  type="button"
                >
                  {segment.name}
                </button>
                <span className="legend-percent">{Math.round(segment.percent)}%</span>
              </li>
            ))}
          </ul>
          <table className="sr-only">
            <caption>Category spending percentage breakdown</caption>
            <thead><tr><th scope="col">Category</th><th scope="col">Amount</th><th scope="col">Percentage</th></tr></thead>
            <tbody>{segments.map((segment) => <tr key={segment.name}><th scope="row">{segment.name}</th><td>{compactMoney(segment.amountPaise)}</td><td>{Math.round(segment.percent)}%</td></tr>)}</tbody>
          </table>
        </>
      )}
    </section>
  );
}

function localDateKey(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}

function displayDayMonth(dateKey: string): string {
  const { month, day } = parseDateInput(dateKey);
  return `${String(day).padStart(2, "0")}/${String(month).padStart(2, "0")}`;
}

function displayFullDate(dateKey: string): string {
  const { year, month, day } = parseDateInput(dateKey);
  return `${String(day).padStart(2, "0")}/${String(month).padStart(2, "0")}/${year}`;
}

function niceChartMaximum(value: number): number {
  if (value <= 0) return 1000;
  const magnitude = 10 ** Math.floor(Math.log10(value));
  const normalized = value / magnitude;
  const rounded = normalized <= 1 ? 1 : normalized <= 2 ? 2 : normalized <= 5 ? 5 : 10;
  return rounded * magnitude;
}

const DAY_LABELS = ["S", "M", "T", "W", "T", "F", "S"];
const DAY_NAMES = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

export function WeeklySpendingChart({ rows }: { rows: TransactionRow[] }) {
  const [weekOffset, setWeekOffset] = useState(0);
  const [selectedDay, setSelectedDay] = useState<number>();
  const [touchStartX, setTouchStartX] = useState<number>();

  const week = useMemo(() => {
    const now = new Date();
    const sunday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - now.getDay() + weekOffset * 7, 12);
    const dates = Array.from({ length: 7 }, (_, index) => {
      const date = new Date(sunday);
      date.setDate(sunday.getDate() + index);
      return date;
    });
    const keys = dates.map(localDateKey);
    const amounts = keys.map((key) => rows.reduce((sum, row) => {
      if (row.type !== "Debit" || isCarryForwardTransaction(row) || transactionDateInputValue(row.date) !== key) return sum;
      return sum + databaseAmountToPaise(Number(row.amount));
    }, 0));
    const max = niceChartMaximum(Math.max(...amounts));
    return { dates, keys, amounts, max };
  }, [rows, weekOffset]);

  const rangeLabel = `${displayDayMonth(week.keys[0])} - ${displayDayMonth(week.keys[6])}`;
  const chart = { width: 360, height: 260, left: 58, right: 350, top: 27, bottom: 210 };
  const plotWidth = chart.right - chart.left;
  const plotHeight = chart.bottom - chart.top;
  const ticks = [week.max, week.max / 2, 0];

  function onTouchStart(event: TouchEvent<HTMLDivElement>) {
    setTouchStartX(event.touches[0]?.clientX);
  }

  function onTouchEnd(event: TouchEvent<HTMLDivElement>) {
    if (touchStartX === undefined) return;
    const delta = (event.changedTouches[0]?.clientX ?? touchStartX) - touchStartX;
    if (Math.abs(delta) > 55) setWeekOffset((offset) => offset + (delta > 0 ? 1 : -1));
    setTouchStartX(undefined);
  }

  return (
    <section aria-labelledby="weekly-chart-title" className="feature-panel chart-panel weekly-panel" data-testid="weekly-chart-card">
      <div className="week-chart-heading">
        <button aria-label="Previous week" className="week-nav-button" onClick={() => { setWeekOffset((offset) => offset + 1); setSelectedDay(undefined); }} type="button"><ChevronLeft aria-hidden="true" size={20} /></button>
        <h2 id="weekly-chart-title">{rangeLabel}</h2>
        <button aria-label="Next week" className="week-nav-button" onClick={() => { setWeekOffset((offset) => offset - 1); setSelectedDay(undefined); }} type="button"><ChevronRight aria-hidden="true" size={20} /></button>
      </div>
      <div className="weekly-chart-wrap" onTouchEnd={onTouchEnd} onTouchStart={onTouchStart}>
        <svg aria-label={`Weekly debit amounts from ${displayFullDate(week.keys[0])} to ${displayFullDate(week.keys[6])}`} className="weekly-chart" data-testid="weekly-bar-chart" role="img" viewBox={`0 0 ${chart.width} ${chart.height}`}>
          <title>Daily debit amounts for the displayed week</title>
          <text className="chart-axis-title chart-y-title" textAnchor="middle" transform={`translate(14 ${chart.top + plotHeight / 2}) rotate(-90)`}>Amount</text>
          {ticks.map((tick) => {
            const y = chart.top + (1 - tick / week.max) * plotHeight;
            return (
              <g key={tick}>
                <line className="chart-horizontal-grid" x1={chart.left} x2={chart.right} y1={y} y2={y} />
                <text className="chart-tick-label" textAnchor="end" x={chart.left - 8} y={y + 4}>{compactMoney(Math.round(tick))}</text>
              </g>
            );
          })}
          {week.dates.map((date, index) => {
            const band = plotWidth / 7;
            const centerX = chart.left + band * index + band / 2;
            const value = week.amounts[index] ?? 0;
            const barHeight = value ? Math.max(4, (value / week.max) * plotHeight) : 0;
            const barY = chart.bottom - barHeight;
            return (
              <g aria-label={`${DAY_NAMES[index]}, ${displayFullDate(week.keys[index] ?? "")}: ${compactMoney(value)}`} key={week.keys[index]}>
                <line className="chart-vertical-grid" x1={centerX} x2={centerX} y1={chart.top} y2={chart.bottom} />
                <rect
                  aria-label={`${DAY_NAMES[index]} ${displayFullDate(week.keys[index] ?? "")}: ${compactMoney(value)}`}
                  className="weekly-bar"
                  data-testid="weekly-bar"
                  height={barHeight || 1}
                  onClick={() => setSelectedDay(selectedDay === index ? undefined : index)}
                  onFocus={() => setSelectedDay(index)}
                  onMouseEnter={() => setSelectedDay(index)}
                  onMouseLeave={() => setSelectedDay(undefined)}
                  onKeyDown={(event) => { if (event.key === "Enter" || event.key === " ") setSelectedDay(index); }}
                  role="button"
                  rx="6"
                  style={{ fill: DATA_COLORS.weekly }}
                  tabIndex={0}
                  width="16"
                  x={centerX - 8}
                  y={barY}
                >
                  <title>{`${DAY_NAMES[index]} ${displayFullDate(week.keys[index] ?? "")}: ${compactMoney(value)}`}</title>
                </rect>
                <text className="chart-day-label" textAnchor="middle" x={centerX} y={chart.bottom + 19}>
                  <title>{DAY_NAMES[index]}</title>{DAY_LABELS[index]}
                </text>
              </g>
            );
          })}
          <rect className="chart-plot-frame" height={plotHeight} width={plotWidth} x={chart.left} y={chart.top} />
          <text className="chart-axis-title" textAnchor="middle" x={chart.left + plotWidth / 2} y={chart.height - 8}>Days</text>
        </svg>
        {selectedDay !== undefined && (
          <div aria-live="polite" className="weekly-tooltip" role="status">
            {DAY_NAMES[selectedDay]}, {displayFullDate(week.keys[selectedDay] ?? "")}: {compactMoney(week.amounts[selectedDay] ?? 0)}
          </div>
        )}
      </div>
    </section>
  );
}
