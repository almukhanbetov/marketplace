"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useLanguage } from "@/context/LanguageContext";
import { useAuth } from "@/context/AuthContext";
import { useModal } from "@/context/ModalContext";
import { useToast } from "@/context/NotificationContext";

export default function UserMenu() {
  const { t } = useLanguage();
  const { user, mounted, logout } = useAuth();
  const { openModal } = useModal();
  const { showToast } = useToast();
  const [open, setOpen] = useState(false);
  const ref = useRef(null);

  useEffect(() => {
    if (!open) return;
    function onClick(e) {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false);
    }
    document.addEventListener("click", onClick);
    return () => document.removeEventListener("click", onClick);
  }, [open]);

  return (
    <div style={{ position: "relative" }} ref={ref}>
      <button
        className="header-action desktop-only"
        aria-label="Профиль"
        onClick={(e) => {
          e.stopPropagation();
          setOpen((v) => !v);
        }}
      >
        <span className="ha-icon">👤</span>
        <span className="ha-label">{t("profile")}</span>
      </button>
      <div className={`user-panel ${open ? "open" : ""}`} onClick={(e) => e.stopPropagation()}>
        {!mounted || !user ? (
          <div>
            <button
              onClick={() => {
                setOpen(false);
                openModal("login");
              }}
            >
              🔑 <span>{t("login")}</span>
            </button>
            <button
              onClick={() => {
                setOpen(false);
                openModal("register");
              }}
            >
              📝 <span>{t("register")}</span>
            </button>
          </div>
        ) : (
          <div>
            <Link href="/profile" onClick={() => setOpen(false)}>
              👤 <span>{user.full_name}</span>
            </Link>
            <Link href="/profile" onClick={() => setOpen(false)}>
              {t("myOrders")}
            </Link>
            <Link href="/favorites" onClick={() => setOpen(false)}>
              {t("favorites")}
            </Link>
            <Link href="/profile" onClick={() => setOpen(false)}>
              {t("settings")}
            </Link>
            {user.role === "seller" && (
              <Link href="/seller-dashboard" onClick={() => setOpen(false)}>
                🏬 <span>Кабинет продавца</span>
              </Link>
            )}
            {user.role === "admin" && (
              <Link href="/admin" onClick={() => setOpen(false)}>
                🛠️ <span>Админ-панель</span>
              </Link>
            )}
            <div className="user-panel-divider" />
            <button
              onClick={() => {
                setOpen(false);
                logout();
                showToast("Вы вышли из аккаунта", "info", "👋");
              }}
            >
              🚪 <span>{t("logout")}</span>
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
