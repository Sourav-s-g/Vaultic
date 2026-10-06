"use client";

import { X } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import { Modal } from "@/components/modal";
import { isTransactionDateAllowed, todayDateInput, transactionDateInputValue, serializeFlutterLocalDateTime } from "@/lib/dates";
import { useCategories, useCreateTransaction, useUpdateTransaction } from "@/lib/data/hooks";
import { CategoryUnavailableError, type TransactionRow } from "@/lib/data/finance";
import { databaseAmountToPaise, parseAmountToPaise, paiseToDatabaseAmount } from "@/lib/money";
import { parseTransactionInput } from "@/lib/parser";
import { applyParsedFields, clearAutoFilledFields, type SmartFieldName, type SmartFields } from "@/lib/parser/auto-fill";
import { transactionInputSchema } from "@/lib/schemas";

function amountInputFromPaise(paise: number): string {
  const value = BigInt(Math.abs(paise));
  return `${value / BigInt(100)}.${(value % BigInt(100)).toString().padStart(2, "0")}`;
}

export function TransactionForm({
  userId,
  transaction,
  onClose,
  onSaved,
}: {
  userId: string;
  transaction?: TransactionRow;
  onClose: () => void;
  onSaved: () => void;
}) {
  const submitting = useRef(false);
  const touched = useRef(new Set<SmartFieldName>());
  const autoFilled = useRef(new Set<SmartFieldName>());
  const [autoFilledFields, setAutoFilledFields] = useState<Set<SmartFieldName>>(new Set());
  const [composing, setComposing] = useState(false);
  const categories = useCategories(userId);
  const create = useCreateTransaction(userId);
  const update = useUpdateTransaction(userId);
  const pending = create.isPending || update.isPending;
  const today = todayDateInput();
  const [naturalInput, setNaturalInput] = useState("");
  const [amount, setAmount] = useState(() => {
    if (!transaction) return "";
    try {
      return amountInputFromPaise(databaseAmountToPaise(transaction.amount));
    } catch {
      return String(transaction.amount);
    }
  });
  const [description, setDescription] = useState(transaction?.description ?? "");
  const [date, setDate] = useState(() => transaction
    ? transactionDateInputValue(transaction.date)
    : today);
  const [type, setType] = useState<"Credit" | "Debit">(transaction?.type ?? "Debit");
  const [selectedCategory, setCategory] = useState(transaction?.category ?? "");
  const [error, setError] = useState("");
  const fieldsRef = useRef<SmartFields>({
    amount,
    description,
    date,
    type,
    category: selectedCategory,
  });

  const categoryRows = categories.data ?? [];
  const categoryNames = useMemo(() => categories.data?.map((item) => item.name) ?? [], [categories.data]);
  const createAllowed = type === "Credit" || categoryRows.some((item) => item.name === selectedCategory);
  const minimum = "2020-01-01";
  const maximum = (() => {
    const parts = today.split("-").map(Number);
    const targetYear = parts[0] + 1;
    const lastDay = new Date(Date.UTC(targetYear, parts[1], 0)).getUTCDate();
    return `${targetYear}-${String(parts[1]).padStart(2, "0")}-${String(Math.min(parts[2], lastDay)).padStart(2, "0")}`;
  })();

  function commitSmartFields(fields: SmartFields, marked: Set<SmartFieldName>) {
    fieldsRef.current = fields;
    setAmount(fields.amount);
    setDescription(fields.description);
    setDate(fields.date);
    setType(fields.type);
    setCategory(fields.category);
    autoFilled.current = marked;
    setAutoFilledFields(new Set(marked));
  }

  function updateSmartInput(value: string) {
    setNaturalInput(value);
    if (!value.trim()) {
      const result = clearAutoFilledFields(fieldsRef.current, touched.current, autoFilled.current, today);
      commitSmartFields(result.fields, result.autoFilled);
    }
  }

  useEffect(() => {
    if (composing || !naturalInput.trim()) return;
    const timer = window.setTimeout(() => {
      const parsed = parseTransactionInput(naturalInput, categoryNames, today);
      const result = applyParsedFields(fieldsRef.current, touched.current, autoFilled.current, parsed, categoryNames, today);
      commitSmartFields(result.fields, result.autoFilled);
    }, 200);
    return () => window.clearTimeout(timer);
  }, [naturalInput, composing, categoryNames, today]);

  function markTouched(field: SmartFieldName) {
    touched.current.add(field);
    autoFilled.current.delete(field);
    setAutoFilledFields(new Set(autoFilled.current));
  }

  function updateManualField(field: Exclude<SmartFieldName, "type">, value: string) {
    markTouched(field);
    const next = { ...fieldsRef.current, [field]: value };
    fieldsRef.current = next;
    if (field === "amount") setAmount(value);
    else if (field === "description") setDescription(value);
    else if (field === "date") setDate(value);
    else setCategory(value);
  }

  function updateType(value: SmartFields["type"]) {
    markTouched("type");
    fieldsRef.current = { ...fieldsRef.current, type: value };
    setType(value);
  }

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (pending || submitting.current) return;
    setError("");
    const input = {
      amount,
      description: description.trim() || "Manual Entry",
      date,
      type,
      category: type === "Credit" ? "" : selectedCategory,
    };
    const result = transactionInputSchema.safeParse(input);
    if (!result.success) {
      setError(result.error.issues[0]?.message ?? "Check the transaction details.");
      return;
    }
    if (!isTransactionDateAllowed(result.data.date, today)) {
      setError("Choose a date from 2020 through one year from today.");
      return;
    }
    if (!createAllowed) {
      await categories.refetch();
      setError("The selected category is no longer available. Choose another category.");
      return;
    }

    submitting.current = true;
    try {
      const amountPaise = parseAmountToPaise(result.data.amount);
      if (transaction) {
        await update.mutateAsync({
          transactionId: transaction.transaction_id,
          updatedAt: transaction.updated_at,
          description: result.data.description,
          amountPaise,
          type: result.data.type,
          date: result.data.date,
          category: result.data.category,
        });
      } else {
        await create.mutateAsync({
          transaction_id: crypto.randomUUID(),
          description: result.data.description,
          amount: paiseToDatabaseAmount(amountPaise),
          type: result.data.type,
          date: serializeFlutterLocalDateTime(result.data.date),
          category: result.data.category,
        });
      }
      onSaved();
      onClose();
    } catch (failure) {
      if (failure instanceof CategoryUnavailableError) {
        await categories.refetch();
      }
      setError(failure instanceof Error ? failure.message : "Could not save the transaction. Your input is still here.");
    } finally {
      submitting.current = false;
    }
  }

  return (
    <Modal className="transaction-dialog" closeDisabled={pending} onClose={onClose} open titleId="transaction-form-title">
      <form onSubmit={(event) => void submit(event)}>
        <header className="transaction-dialog-header">
          <h2 id="transaction-form-title">{transaction ? "Edit transaction" : "Add transaction"}</h2>
          <button aria-label="Close transaction form" className="icon-button" disabled={pending} onClick={onClose} type="button"><X aria-hidden="true" size={19} /></button>
        </header>
        <div className="transaction-dialog-body">
          <div className="transaction-field">
            <label htmlFor="natural-entry">Quick entry</label>
            <input autoComplete="off" className="form-input" id="natural-entry" onChange={(event) => updateSmartInput(event.target.value)} onCompositionEnd={(event) => { setComposing(false); updateSmartInput(event.currentTarget.value); }} onCompositionStart={() => setComposing(true)} placeholder="e.g. Paid ₹250.50 for lunch" value={naturalInput} />
          </div>
          {autoFilledFields.size > 0 && <p aria-live="polite" className="auto-filled-note">Filled from your text</p>}
          <div className="transaction-fields-grid">
            <div className="transaction-field">
              <label htmlFor="transaction-amount">Amount (₹)</label>
              <input
                aria-describedby={error ? "transaction-error" : undefined}
                autoComplete="off"
                className="form-input"
                inputMode="decimal"
                id="transaction-amount"
                onChange={(event) => updateManualField("amount", event.target.value)}
                placeholder="0.00"
                value={amount}
              />
            </div>
            <div className="transaction-field">
              <label htmlFor="transaction-type">Type</label>
              <select className="form-select" id="transaction-type" onChange={(event) => {
                const nextType = event.target.value as "Credit" | "Debit";
                updateType(nextType);
                if (nextType === "Credit") updateManualField("category", "");
                else if (!selectedCategory) updateManualField("category", categoryRows[0]?.name ?? "");
              }} value={type}>
                <option value="Debit">Debit</option><option value="Credit">Credit</option>
              </select>
            </div>
          </div>
          <div className="transaction-fields-grid">
            <div className="transaction-field">
              <label htmlFor="transaction-date">Date</label>
              <input className="form-input" id="transaction-date" max={maximum} min={minimum} onChange={(event) => updateManualField("date", event.target.value)} required type="date" value={date} />
            </div>
            {type === "Debit" && (
              <div className="transaction-field">
                <label htmlFor="transaction-category">Category</label>
                <select className="form-select" id="transaction-category" onChange={(event) => updateManualField("category", event.target.value)} required value={selectedCategory}>
                  <option disabled value="">Choose a category</option>
                  {categoryRows.map((item) => <option key={item.id} value={item.name}>{item.name}</option>)}
                </select>
                {categoryRows.length === 0 && <span className="field-help">Add a category before recording a debit.</span>}
              </div>
            )}
          </div>
          <div className="transaction-field">
            <label htmlFor="transaction-description">Description</label>
            <textarea className="form-textarea" id="transaction-description" onChange={(event) => updateManualField("description", event.target.value)} placeholder="Manual Entry" value={description} />
          </div>
          {error && <p className="inline-error" id="transaction-error" role="alert">{error}</p>}
        </div>
        <footer className="transaction-form-footer">
          <button className="button button-secondary" disabled={pending} onClick={onClose} type="button">Cancel</button>
          <button className="button button-primary" disabled={pending || categories.isLoading || (type === "Debit" && categoryRows.length === 0)} type="submit">
            {pending ? "Saving…" : transaction ? "Save changes" : "Save transaction"}
          </button>
        </footer>
      </form>
    </Modal>
  );
}
