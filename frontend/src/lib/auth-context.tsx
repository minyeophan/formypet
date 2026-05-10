import React, { createContext, useContext, useEffect, useState } from 'react';
import { authApi, AuthPayload, getStoredTokens } from '../services/api';

interface AuthContextValue {
  isAuthLoading: boolean;
  isAuthenticated: boolean;
  login: (payload: Omit<AuthPayload, 'nickname'>) => Promise<void>;
  register: (payload: Required<AuthPayload>) => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [isAuthLoading, setIsAuthLoading] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  useEffect(() => {
    getStoredTokens()
      .then((tokens) => setIsAuthenticated(!!tokens))
      .finally(() => setIsAuthLoading(false));
  }, []);

  async function login(payload: Omit<AuthPayload, 'nickname'>) {
    await authApi.login(payload);
    setIsAuthenticated(true);
  }

  async function register(payload: Required<AuthPayload>) {
    await authApi.register(payload);
    setIsAuthenticated(true);
  }

  async function logout() {
    await authApi.logout();
    setIsAuthenticated(false);
  }

  return (
    <AuthContext.Provider value={{ isAuthLoading, isAuthenticated, login, register, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
