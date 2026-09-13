"use client";

import { useEffect, useRef, useState } from "react";
import { useLanguage } from "@/context/LanguageContext";
import { mockNotifications, notifTexts } from "@/data/notificationsMock";

export default function NotificationBell() {
  const { t, lang } = useLanguage();
  const [open, setOpen] = useState(false);
  const [items, setItems] = useState(mockNotifications);
  const ref = useRef(null);

  useEffect(() => {
    if (!open) return;
    function onClick(e) {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false);
    }
    document.addEventListener("click", onClick);
    return () => document.removeEventListener("click", onClick);
  }, [open]);

  const unreadCount = items.filter((n) => n.unread).length;

  return (
    <div style={{ position: "relative" }} ref={ref}>
      <button
        className="header-action hide-tablet"
        aria-label="Уведомления"
        onClick={(e) => {
          e.stopPropagation();
          setOpen((v) => !v);
        }}
      >
        <span className="ha-icon">
          🔔
          <span className="ha-count" style={{ display: unreadCount > 0 ? "flex" : "none" }}>
            {unreadCount}
          </span>
        </span>
        <span className="ha-label">{t("notifications")}</span>
      </button>
      <div className={`notif-panel ${open ? "open" : ""}`} onClick={(e) => e.stopPropagation()}>
        <div className="notif-panel-head">
          <span>{t("notifications")}</span>
          <button onClick={() => setItems((prev) => prev.map((n) => ({ ...n, unread: false })))}>
            {t("markAllRead")}
          </button>
        </div>
        <div className="notif-list">
          {items.map((n) => (
            <div key={n.id} className={`notif-item ${n.unread ? "unread" : ""}`}>
              <div className="ni-icon">{n.icon}</div>
              <div>
                <div className="ni-text">{notifTexts[lang][n.key]}</div>
                <div className="ni-time">{n.time}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
