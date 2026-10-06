"use client";

import { useEffect, useRef, type ReactNode } from "react";

export function Modal({
  open,
  titleId,
  className = "",
  closeDisabled = false,
  onClose,
  children,
}: {
  open: boolean;
  titleId: string;
  className?: string;
  closeDisabled?: boolean;
  onClose: () => void;
  children: ReactNode;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const previousFocus = useRef<HTMLElement | null>(null);

  useEffect(() => {
    const element = dialog.current;
    if (!element) return;
    if (open && !element.open) {
      previousFocus.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
      element.showModal();
      document.body.dataset.modalOpen = "true";
      const scrollY = window.scrollY;
      const previousBodyStyle = {
        position: document.body.style.position,
        top: document.body.style.top,
        width: document.body.style.width,
        overflow: document.body.style.overflow,
      };
      document.body.style.position = "fixed";
      document.body.style.top = `-${scrollY}px`;
      document.body.style.width = "100%";
      document.body.style.overflow = "hidden";

      const viewport = window.visualViewport;
      let frame = 0;
      const positionDialog = () => {
        cancelAnimationFrame(frame);
        frame = requestAnimationFrame(() => {
          const rect = element.getBoundingClientRect();
          const viewportLeft = viewport?.offsetLeft ?? 0;
          const viewportTop = viewport?.offsetTop ?? 0;
          const viewportWidth = viewport?.width ?? window.innerWidth;
          const viewportHeight = viewport?.height ?? window.innerHeight;
          const safeInset = 12;
          const maxHeight = Math.max(180, viewportHeight - safeInset * 2);
          element.style.maxHeight = `${maxHeight}px`;
          element.style.left = `${viewportLeft + Math.max(safeInset, (viewportWidth - rect.width) / 2)}px`;
          element.style.top = `${viewportTop + Math.max(safeInset, (viewportHeight - Math.min(rect.height, maxHeight)) / 2)}px`;
          element.style.right = "auto";
          element.style.bottom = "auto";
        });
      };
      const keepFocusVisible = (event: FocusEvent) => {
        const target = event.target;
        if (target instanceof HTMLElement && element.contains(target)) {
          requestAnimationFrame(() => target.scrollIntoView({ block: "nearest", inline: "nearest" }));
        }
      };
      positionDialog();
      viewport?.addEventListener("resize", positionDialog);
      viewport?.addEventListener("scroll", positionDialog);
      element.addEventListener("focusin", keepFocusVisible);
      window.addEventListener("resize", positionDialog);
      return () => {
        cancelAnimationFrame(frame);
        viewport?.removeEventListener("resize", positionDialog);
        viewport?.removeEventListener("scroll", positionDialog);
        element.removeEventListener("focusin", keepFocusVisible);
        window.removeEventListener("resize", positionDialog);
        if (element.open) element.close();
        delete document.body.dataset.modalOpen;
        document.body.style.position = previousBodyStyle.position;
        document.body.style.top = previousBodyStyle.top;
        document.body.style.width = previousBodyStyle.width;
        document.body.style.overflow = previousBodyStyle.overflow;
        window.scrollTo(0, scrollY);
        element.style.left = "";
        element.style.top = "";
        element.style.right = "";
        element.style.bottom = "";
        element.style.maxHeight = "";
        if (previousFocus.current?.isConnected) previousFocus.current.focus();
      };
    } else if (!open && element.open) {
      element.close();
    }
    return undefined;
  }, [open]);

  function close() {
    if (closeDisabled) return;
    onClose();
  }

  return (
    <dialog
      aria-labelledby={titleId}
      className={`shared-modal ${className}`}
      onCancel={(event) => { event.preventDefault(); close(); }}
      onClick={(event) => { if (event.target === event.currentTarget) close(); }}
      onClose={() => { delete document.body.dataset.modalOpen; }}
      ref={dialog}
    >
      <span aria-hidden="true" className="modal-drag-handle" />
      {children}
    </dialog>
  );
}
