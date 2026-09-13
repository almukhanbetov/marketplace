"use client";

import { useToast } from "@/context/NotificationContext";

export default function ToastStack() {
  const { toasts } = useToast();

  return (
    <div className="toast-stack" aria-live="polite">
      {toasts.map((tt) => (
        <div key={tt.id} className={`toast toast--${tt.type} ${tt.leaving ? "leaving" : ""}`}>
          <span className="toast-icon">{tt.icon}</span>
          <span>{tt.message}</span>
        </div>
      ))}
    </div>
  );
}
