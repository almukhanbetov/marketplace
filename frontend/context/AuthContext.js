"use client";

import { createContext, useContext, useEffect, useState, useCallback, useMemo, useRef } from "react";
import { onSessionExpired } from "@/lib/api/client";
import * as authApi from "@/lib/api/auth";

const AuthContext = createContext(null);

/**
 * Stage 9: real backend-authenticated identity. The access token lives in
 * memory only (lib/api/authToken.js); on mount this silently attempts
 * /auth/refresh using the HttpOnly refresh cookie so a page reload doesn't
 * force a fresh login (Stage 9 §77) — if that fails, the user is simply
 * logged out, exactly as if they'd never had a session. Replaces the
 * Stage 4 localStorage-only mock entirely; nothing here reads
 * NEXT_PUBLIC_DEMO_*.
 */
export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [mounted, setMounted] = useState(false);
  const loadingRef = useRef(false);

  const refreshUser = useCallback(async () => {
    try {
      const me = await authApi.getMe();
      setUser(me);
      return me;
    } catch {
      setUser(null);
      return null;
    }
  }, []);

  useEffect(() => {
    if (loadingRef.current) return;
    loadingRef.current = true;
    (async () => {
      const token = await authApi.trySilentRefresh();
      if (token) await refreshUser();
      setMounted(true);
    })();
  }, [refreshUser]);

  useEffect(() => onSessionExpired(() => setUser(null)), []);

  const login = useCallback(
    async (identifier, password) => {
      const isEmail = identifier.includes("@");
      const loggedInUser = await authApi.login(isEmail ? { email: identifier, password } : { phone: identifier, password });
      setUser(await refreshUser());
      return loggedInUser;
    },
    [refreshUser]
  );

  const register = useCallback(
    async ({ email, phone, fullName, password }) => {
      await authApi.register({ email, phone, fullName, password });
      // Auto-login right after a successful registration — smoother UX,
      // backend remains authoritative on the credentials either way.
      return login(email || phone, password);
    },
    [login]
  );

  const logout = useCallback(async () => {
    await authApi.logout().catch(() => {});
    setUser(null);
  }, []);

  const value = useMemo(
    () => ({
      user,
      mounted,
      role: user?.role || null,
      sellerId: user?.seller_id ?? null,
      isAuthenticated: !!user,
      login,
      register,
      logout,
      refreshUser,
    }),
    [user, mounted, login, register, logout, refreshUser]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
