"use client";

import { useState } from "react";
import { createCategoryDraft, DATA_COLORS, duplicateCategory, SUGGESTED_CATEGORIES } from "@/lib/categories/data";
import {
  useAddCategory,
  useCategories,
  useCurrentUserId,
  useRemoveCategory,
} from "@/lib/data/hooks";

export function CategoriesPage() {
  const user = useCurrentUserId();
  const categories = useCategories(user.data);
  const add = useAddCategory(user.data);
  const remove = useRemoveCategory(user.data);
  const [name, setName] = useState("");
  const [validation, setValidation] = useState("");
  const [message, setMessage] = useState("");
  const [pendingRemoval, setPendingRemoval] = useState<string | null>(null);

  async function addCustom(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const normalizedName = name.trim();
    if (!normalizedName) {
      setValidation("Enter a category name.");
      return;
    }
    if (duplicateCategory(categories.data ?? [], normalizedName)) {
      setValidation("A category with that name already exists.");
      return;
    }
    setValidation("");
    setMessage("");
    try {
      await add.mutateAsync(createCategoryDraft(normalizedName));
      setName("");
      setMessage(`${normalizedName} added.`);
    } catch (error) {
      setValidation(error instanceof Error ? error.message : "Could not add category. Try again.");
    }
  }

  async function addSuggested(nameToAdd: string) {
    const suggestion = SUGGESTED_CATEGORIES.find((category) => category.name === nameToAdd);
    if (!suggestion) return;
    setValidation("");
    setMessage("");
    try {
      await add.mutateAsync(suggestion);
      setMessage(`${suggestion.name} added.`);
    } catch (error) {
      setValidation(error instanceof Error ? error.message : "Could not add category. Try again.");
    }
  }

  async function confirmRemoval() {
    if (!pendingRemoval) return;
    const removedName = pendingRemoval;
    setValidation("");
    setMessage("");
    try {
      await remove.mutateAsync(removedName);
      setPendingRemoval(null);
      setMessage(`${removedName} removed. Transactions keep their category text.`);
    } catch (error) {
      setValidation(error instanceof Error ? error.message : "Could not remove category. Try again.");
    }
  }

  if (user.isLoading || categories.isLoading) {
    return <main className="feature-page" aria-busy="true"><div className="skeleton skeleton-title" /><div className="skeleton skeleton-panel" /></main>;
  }
  if (user.error || categories.error) {
    return <main className="feature-page"><section className="feature-panel" role="alert"><h1>Could not load categories</h1><p>{(user.error ?? categories.error)?.message}</p><button className="button button-primary" onClick={() => { void user.refetch(); void categories.refetch(); }} type="button">Try again</button></section></main>;
  }
  if (!user.data) return <main className="feature-page"><p role="status">Sign in to manage categories.</p></main>;

  const rows = categories.data ?? [];
  const available = SUGGESTED_CATEGORIES.filter((item) => !duplicateCategory(rows, item.name));
  return (
    <main className="feature-page">
      <section className="feature-heading">
        <div><p className="eyebrow">ORGANIZE</p><h1>Categories</h1><p className="heading-copy">Manage spending labels without changing transaction history.</p></div>
      </section>
      <section className="feature-panel" aria-labelledby="category-list-title">
        <div className="panel-heading"><h2 id="category-list-title">Your categories</h2><span className="muted-copy">{rows.length} total</span></div>
        {rows.length === 0 ? <p className="empty-state">No categories yet. Add a custom or suggested category.</p> : (
          <ul className="category-list">
            {rows.map((category) => (
              <li key={category.id}>
                <span><span aria-hidden="true" className="category-swatch" style={{ backgroundColor: category.color ?? DATA_COLORS.custom }} />{category.name}</span>
                <button aria-label={`Remove ${category.name}`} className="text-button" disabled={remove.isPending} onClick={() => setPendingRemoval(category.name)} type="button">Remove</button>
              </li>
            ))}
          </ul>
        )}
      </section>
      <section className="feature-panel" aria-labelledby="category-add-title">
        <h2 id="category-add-title">Add a custom category</h2>
        <form className="inline-add" onSubmit={(event) => void addCustom(event)}>
          <label className="sr-only" htmlFor="custom-category-name">Category name</label>
          <input autoComplete="off" className="text-input" id="custom-category-name" maxLength={120} onChange={(event) => setName(event.target.value)} placeholder="e.g. Pets" value={name} />
          <button className="button button-primary" disabled={add.isPending} type="submit">{add.isPending ? "Adding…" : "Add category"}</button>
        </form>
        {available.length > 0 && (
          <div className="suggested-categories">
            <p className="muted-copy">Suggested</p>
            <div className="category-grid">
              {available.map((item) => (
                <button className="category-choice" disabled={add.isPending} key={item.name} onClick={() => void addSuggested(item.name)} type="button">
                  <span aria-hidden="true" className="category-swatch" style={{ backgroundColor: item.color }} />
                  <span>{item.name}</span><span className="choice-state">Add</span>
                </button>
              ))}
            </div>
          </div>
        )}
      </section>
      {validation && <p className="inline-error" role="alert">{validation}</p>}
      {message && <p className="inline-success" role="status">{message}</p>}
      {pendingRemoval && (
        <div aria-labelledby="remove-category-title" aria-modal="true" className="confirm-backdrop" role="dialog">
          <section className="confirm-dialog">
            <h2 id="remove-category-title">Remove {pendingRemoval}?</h2>
            <p>The category and its budget will be deleted. Transactions keep their existing category text and will not be changed.</p>
            <div className="wizard-actions">
              <button className="button button-secondary" disabled={remove.isPending} onClick={() => setPendingRemoval(null)} type="button">Cancel</button>
              <button className="button button-primary" disabled={remove.isPending} onClick={() => void confirmRemoval()} type="button">{remove.isPending ? "Removing…" : "Remove category"}</button>
            </div>
          </section>
        </div>
      )}
    </main>
  );
}
