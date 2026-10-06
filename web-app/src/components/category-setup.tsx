"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { createCategoryDraft, duplicateCategory, INITIAL_CATEGORIES, SUGGESTED_CATEGORIES, type CategoryDraft } from "@/lib/categories/data";
import { safeNextPath } from "@/lib/auth/safe-next-path";
import { useCategories, useCurrentUserId, useSaveSetupCategories } from "@/lib/data/hooks";
import { CategoryTiles } from "@/components/finance-ui";

export function CategorySetup({ nextPath }: { nextPath: string | null }) {
  const router = useRouter();
  const user = useCurrentUserId();
  const categories = useCategories(user.data);
  const save = useSaveSetupCategories(user.data);
  const [step, setStep] = useState(0);
  const [selected, setSelected] = useState<CategoryDraft[]>(INITIAL_CATEGORIES);
  const [customName, setCustomName] = useState("");
  const [validation, setValidation] = useState("");
  const [success, setSuccess] = useState(false);

  function addCustom() {
    const name = customName.trim();
    if (!name) {
      setValidation("Enter a category name.");
      return;
    }
    if (duplicateCategory(selected, name)) {
      setValidation("That category is already selected.");
      return;
    }
    setSelected((current) => [...current, createCategoryDraft(name)]);
    setCustomName("");
    setValidation("");
  }

  function toggleSuggested(category: CategoryDraft) {
    setValidation("");
    setSelected((current) => {
      if (duplicateCategory(current, category.name)) {
        return current.filter((item) => item.name.toLocaleLowerCase() !== category.name.toLocaleLowerCase());
      }
      return [...current, category];
    });
  }

  async function finish() {
    if (selected.length === 0) {
      setValidation("Select at least one category to continue.");
      return;
    }
    setValidation("");
    try {
      await save.mutateAsync(selected);
      setSuccess(true);
      window.setTimeout(() => {
        router.replace(safeNextPath(nextPath) ?? "/");
        router.refresh();
      }, 250);
    } catch (error) {
      setValidation(error instanceof Error ? error.message : "Could not save your categories. Try again.");
    }
  }

  if (user.isLoading || categories.isLoading) {
    return <main className="feature-page" aria-busy="true"><div className="skeleton skeleton-title" /><div className="skeleton skeleton-panel" /></main>;
  }
  if (user.error || categories.error) {
    return (
      <main className="feature-page">
        <section className="feature-panel" role="alert">
          <h1>Could not load setup</h1>
          <p>{(user.error ?? categories.error)?.message}</p>
          <button className="button button-primary" onClick={() => { void user.refetch(); void categories.refetch(); }} type="button">Try again</button>
        </section>
      </main>
    );
  }
  if (!user.data) return <main className="feature-page"><p role="status">Sign in to set up categories.</p><Link href="/login">Sign in</Link></main>;

  return (
    <main className="feature-page setup-page">
      <section className="feature-heading">
        <div><p className="eyebrow">ACCOUNT SETUP</p><h1>Make Vaultic yours</h1><p className="heading-copy">Choose the categories you use to organize spending.</p></div>
        <span className="step-count">Step {step + 1} of 3</span>
      </section>
      <div className="step-track" aria-hidden="true"><span style={{ width: `${((step + 1) / 3) * 100}%` }} /></div>
      {step === 0 && (
        <section className="feature-panel setup-intro" aria-labelledby="setup-intro-title">
          <p className="eyebrow">A CLEARER MONEY VIEW</p>
          <h2 id="setup-intro-title">Start with the categories that fit your life.</h2>
          <p>Your choices are saved to your account. You can add or remove categories later; existing transactions keep their category text.</p>
        </section>
      )}
      {step === 1 && (
        <section className="feature-panel" aria-labelledby="setup-category-title">
          <h2 id="setup-category-title">Choose categories</h2>
          <p className="muted-copy">Suggested categories start with five selected. Select any others you need.</p>
          <div className="category-chips">
            {SUGGESTED_CATEGORIES.map((category) => {
              const active = duplicateCategory(selected, category.name);
              return (
                <button
                  aria-pressed={active}
                  className={`category-chip${active ? " is-selected" : ""}`}
                  key={category.name}
                  onClick={() => toggleSuggested(category)}
                  type="button"
                >
                  <span aria-hidden="true" className="category-swatch" style={{ backgroundColor: category.color }} />
                  <span>{category.name}</span><span className="choice-state">{active ? "Selected" : "Add"}</span>
                </button>
              );
            })}
          </div>
          <form className="inline-add" onSubmit={(event) => { event.preventDefault(); addCustom(); }}>
            <label className="sr-only" htmlFor="setup-custom-category">Custom category</label>
            <input autoComplete="off" className="text-input" id="setup-custom-category" maxLength={120} onChange={(event) => setCustomName(event.target.value)} placeholder="Add a custom category" value={customName} />
            <button className="button button-secondary" type="submit">Add custom</button>
          </form>
          {selected.some((category) => !SUGGESTED_CATEGORIES.some((suggested) => suggested.name === category.name)) && (
            <CategoryTiles
              categories={selected.filter((category) => !SUGGESTED_CATEGORIES.some((suggested) => suggested.name === category.name))}
              onRemove={(name) => setSelected((current) => current.filter((item) => item.name !== name))}
            />
          )}
        </section>
      )}
      {step === 2 && (
        <section className="feature-panel" aria-labelledby="setup-review-title">
          <h2 id="setup-review-title">Review your categories</h2>
          <p className="muted-copy">{selected.length} selected. You can manage these any time.</p>
          {selected.length === 0 ? <p className="empty-state">No categories selected yet.</p> : (
            <CategoryTiles categories={selected} onRemove={(name) => setSelected((current) => current.filter((item) => item.name !== name))} />
          )}
        </section>
      )}
      {validation && <p className="inline-error" role="alert">{validation}</p>}
      {success && <p className="inline-success" role="status">Categories saved. Opening your workspace…</p>}
      <div className="wizard-actions">
        {step > 0 ? <button className="button button-secondary" onClick={() => { setStep((current) => current - 1); setValidation(""); }} type="button">Previous</button> : <span />}
        {step < 2
          ? <button className="button button-primary" onClick={() => { setStep((current) => current + 1); setValidation(""); }} type="button">Next</button>
          : <button className="button button-primary" disabled={save.isPending || success || selected.length === 0} onClick={() => void finish()} type="button">{save.isPending ? "Saving…" : "Finish setup"}</button>}
      </div>
    </main>
  );
}
