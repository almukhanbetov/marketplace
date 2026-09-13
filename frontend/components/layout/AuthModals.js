"use client";

import { useState } from "react";
import Modal from "@/components/ui/Modal";
import { useModal } from "@/context/ModalContext";
import { useAuth } from "@/context/AuthContext";
import { useLanguage } from "@/context/LanguageContext";
import { useToast } from "@/context/NotificationContext";

const EMPTY_LOGIN = { identifier: "", password: "" };
const EMPTY_REGISTER = { fullName: "", email: "", phone: "", password: "", confirmPassword: "" };

/** Maps a backend error code to a localized, friendly message (Stage 9
 * §82) — never a raw error/stack dump. */
function errorMessage(err, t) {
  const table = {
    INVALID_CREDENTIALS: t("errInvalidCredentials"),
    ACCOUNT_DISABLED: t("errAccountDisabled"),
    UNAUTHORIZED: t("errUnauthorized"),
    FORBIDDEN: t("errForbidden"),
    SESSION_EXPIRED: t("errSessionExpired"),
  };
  if (err?.status === 0) return t("errNetwork");
  return table[err?.code] || err?.message || t("errNetwork");
}

export default function AuthModals() {
  const { activeModal, closeModal } = useModal();
  const { login, register } = useAuth();
  const { t } = useLanguage();
  const { showToast } = useToast();

  const [loginForm, setLoginForm] = useState(EMPTY_LOGIN);
  const [registerForm, setRegisterForm] = useState(EMPTY_REGISTER);
  const [loginSubmitting, setLoginSubmitting] = useState(false);
  const [registerSubmitting, setRegisterSubmitting] = useState(false);

  async function submitLogin(e) {
    e.preventDefault();
    setLoginSubmitting(true);
    try {
      const user = await login(loginForm.identifier.trim(), loginForm.password);
      setLoginForm(EMPTY_LOGIN);
      closeModal();
      showToast(`${t("login")}: ${user?.full_name || ""}`, "success", "✓");
    } catch (err) {
      showToast(errorMessage(err, t), "warn", "⚠");
    } finally {
      setLoginSubmitting(false);
    }
  }

  async function submitRegister(e) {
    e.preventDefault();
    if (!registerForm.email.trim() && !registerForm.phone.trim()) {
      showToast(t("errEmailOrPhoneRequired"), "warn", "⚠");
      return;
    }
    if (registerForm.password !== registerForm.confirmPassword) {
      showToast(t("errPasswordsDontMatch"), "warn", "⚠");
      return;
    }
    setRegisterSubmitting(true);
    try {
      await register({
        fullName: registerForm.fullName.trim(),
        email: registerForm.email.trim(),
        phone: registerForm.phone.trim(),
        password: registerForm.password,
      });
      setRegisterForm(EMPTY_REGISTER);
      closeModal();
      showToast(t("register") + " ✓", "success", "✓");
    } catch (err) {
      showToast(errorMessage(err, t), "warn", "⚠");
    } finally {
      setRegisterSubmitting(false);
    }
  }

  return (
    <>
      <Modal open={activeModal === "login"} onClose={closeModal} title={t("login")} labelledBy="login-title">
        <form style={{ display: "flex", flexDirection: "column", gap: 14 }} onSubmit={submitLogin}>
          <div className="field">
            <label htmlFor="login-identifier">Email / {t("phone")}</label>
            <input
              id="login-identifier"
              placeholder="you@example.com"
              required
              autoFocus
              value={loginForm.identifier}
              onChange={(e) => setLoginForm((f) => ({ ...f, identifier: e.target.value }))}
            />
          </div>
          <div className="field">
            <label htmlFor="login-pass">{t("password")}</label>
            <input
              id="login-pass"
              type="password"
              placeholder="••••••••"
              required
              value={loginForm.password}
              onChange={(e) => setLoginForm((f) => ({ ...f, password: e.target.value }))}
            />
          </div>
          <button type="submit" className="btn btn--primary btn--block btn--lg" disabled={loginSubmitting}>
            {loginSubmitting ? t("loggingIn") : t("login")}
          </button>
        </form>
      </Modal>

      <Modal open={activeModal === "register"} onClose={closeModal} title={t("register")} labelledBy="register-title">
        <form style={{ display: "flex", flexDirection: "column", gap: 14 }} onSubmit={submitRegister}>
          <div className="field">
            <label>{t("fullName")}</label>
            <input
              placeholder="Айгерим Ким"
              required
              value={registerForm.fullName}
              onChange={(e) => setRegisterForm((f) => ({ ...f, fullName: e.target.value }))}
            />
          </div>
          <div className="field">
            <label>Email</label>
            <input
              type="email"
              placeholder="you@example.com"
              value={registerForm.email}
              onChange={(e) => setRegisterForm((f) => ({ ...f, email: e.target.value }))}
            />
          </div>
          <div className="field">
            <label>{t("phone")}</label>
            <input
              type="tel"
              placeholder="+7 700 000 00 00"
              value={registerForm.phone}
              onChange={(e) => setRegisterForm((f) => ({ ...f, phone: e.target.value }))}
            />
          </div>
          <div className="field">
            <label>{t("password")}</label>
            <input
              type="password"
              placeholder="••••••••"
              required
              minLength={8}
              value={registerForm.password}
              onChange={(e) => setRegisterForm((f) => ({ ...f, password: e.target.value }))}
            />
          </div>
          <div className="field">
            <label>{t("confirmPassword")}</label>
            <input
              type="password"
              placeholder="••••••••"
              required
              minLength={8}
              value={registerForm.confirmPassword}
              onChange={(e) => setRegisterForm((f) => ({ ...f, confirmPassword: e.target.value }))}
            />
          </div>
          <button type="submit" className="btn btn--primary btn--block btn--lg" disabled={registerSubmitting}>
            {registerSubmitting ? t("registering") : t("register")}
          </button>
        </form>
      </Modal>
    </>
  );
}
