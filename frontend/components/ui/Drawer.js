"use client";

import { useEffect } from "react";

/**
 * Generic slide-in drawer (from the right) — used for the cart drawer and
 * the mobile filters sheet. Stays mounted so the CSS transform transition
 * plays on open/close, matching the legacy DrawerManager behaviour.
 */
export default function Drawer({ open, onClose, title, children, footer, ariaLabel }) {
  useEffect(() => {
    if (!open) return;
    document.body.classList.add("no-scroll");

    const onKeyDown = (e) => {
      if (e.key === "Escape") onClose?.();
    };
    document.addEventListener("keydown", onKeyDown);

    return () => {
      document.removeEventListener("keydown", onKeyDown);
      document.body.classList.remove("no-scroll");
    };
  }, [open, onClose]);

  return (
    <>
      <div
        className={`drawer-backdrop ${open ? "open" : ""}`}
        onMouseDown={(e) => {
          if (e.target === e.currentTarget) onClose?.();
        }}
      />
      <aside className={`drawer ${open ? "open" : ""}`} aria-label={ariaLabel} aria-hidden={!open}>
        <div className="drawer-head">
          <h3>{title}</h3>
          <button className="modal-close" onClick={onClose} aria-label="Закрыть">
            ✕
          </button>
        </div>
        <div className="drawer-body">{children}</div>
        {footer && <div className="drawer-summary">{footer}</div>}
      </aside>
    </>
  );
}
