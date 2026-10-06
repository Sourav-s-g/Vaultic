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
    } else if (!open && element.open) {
      element.close();
    }
    return () => {
      if (element.open) element.close();
      delete document.body.dataset.modalOpen;
      if (previousFocus.current?.isConnected) previousFocus.current.focus();
    };
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
