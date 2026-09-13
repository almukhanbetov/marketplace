"use client";

import { useEffect, useRef } from "react";

const SIZE_CLASS = { md: "", lg: "modal--lg", xl: "modal--xl" };

/**
 * Generic reusable modal — used for login, register, quick view, gallery,
 * add product, ask a question, etc. Handles ESC-to-close, overlay click,
 * background scroll lock and initial focus, matching the legacy
 * ModalManager behaviour.
 */
export default function Modal({ open, onClose, title, children, footer, size = "md", labelledBy }) {
  const modalRef = useRef(null);

  useEffect(() => {
    if (!open) return;
    document.body.classList.add("no-scroll");

    const onKeyDown = (e) => {
      if (e.key === "Escape") onClose?.();
    };
    document.addEventListener("keydown", onKeyDown);

    const focusable = modalRef.current?.querySelector("input, button, select, textarea");
    focusable?.focus();

    return () => {
      document.removeEventListener("keydown", onKeyDown);
      document.body.classList.remove("no-scroll");
    };
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div
      className="modal-backdrop open"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onClose?.();
      }}
    >
      <div
        className={`modal ${SIZE_CLASS[size] || ""}`}
        role="dialog"
        aria-modal="true"
        aria-labelledby={labelledBy}
        ref={modalRef}
      >
        {title && (
          <div className="modal-head">
            <h3 id={labelledBy}>{title}</h3>
            <button className="modal-close" onClick={onClose} aria-label="Закрыть">
              ✕
            </button>
          </div>
        )}
        <div className="modal-body">{children}</div>
        {footer && <div className="modal-foot">{footer}</div>}
      </div>
    </div>
  );
}
