"use client";

import { createContext, useContext, useCallback, useRef, useState } from "react";

const NotificationContext = createContext(null);
const ICONS = { success: "✓", error: "⚠", info: "ℹ", warn: "⚠" };

export function NotificationProvider({ children }) {
  const [toasts, setToasts] = useState([]);
  const idRef = useRef(0);

  const showToast = useCallback((message, type = "success", icon) => {
    const id = ++idRef.current;
    setToasts((prev) => [...prev, { id, message, type, icon: icon || ICONS[type] || "✓", leaving: false }]);
    setTimeout(() => {
      setToasts((prev) => prev.map((tt) => (tt.id === id ? { ...tt, leaving: true } : tt)));
      setTimeout(() => {
        setToasts((prev) => prev.filter((tt) => tt.id !== id));
      }, 200);
    }, 2600);
  }, []);

  return (
    <NotificationContext.Provider value={{ toasts, showToast }}>
      {children}
    </NotificationContext.Provider>
  );
}

export function useToast() {
  const ctx = useContext(NotificationContext);
  if (!ctx) throw new Error("useToast must be used within NotificationProvider");
  return ctx;
}
