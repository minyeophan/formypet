import React, { createContext, useContext, useEffect, useState } from 'react';
import { authApi, AuthPayload, clearTokens, getStoredTokens, userApi, UserProfile } from '../services/api';

interface AuthContextValue {
  isAuthLoading: boolean;
  isAuthenticated: boolean;
  profile: UserProfile | null;
  refreshProfile: () => Promise<void>;
  updateProfile: (nickname: string) => Promise<void>;
  uploadProfileImage: (uri: string) => Promise<void>;
  login: (payload: Omit<AuthPayload, 'nickname'>) => Promise<void>;
  register: (payload: Required<AuthPayload>) => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [isAuthLoading, setIsAuthLoading] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [profile, setProfile] = useState<UserProfile | null>(null);

  useEffect(() => {
    let cancelled = false;

    getStoredTokens()
      .then(async (tokens) => {
        if (!tokens) {
          if (!cancelled) {
            setProfile(null);
            setIsAuthenticated(false);
          }
          return;
        }
        try {
          const nextProfile = await userApi.getMe();
          if (!cancelled) {
            setProfile(nextProfile);
            setIsAuthenticated(true);
          }
        } catch {
          await clearTokens();
          if (!cancelled) {
            setProfile(null);
            setIsAuthenticated(false);
          }
        }
      })
      .finally(() => {
        if (!cancelled) setIsAuthLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, []);

  async function refreshProfile() {
    setProfile(await userApi.getMe());
  }

  async function updateProfile(nickname: string) {
    setProfile(await userApi.updateMe(nickname));
  }

  async function uploadProfileImage(uri: string) {
    setProfile(await userApi.uploadProfileImage(uri));
  }

  async function login(payload: Omit<AuthPayload, 'nickname'>) {
    await authApi.login(payload);
    setProfile(await userApi.getMe());
    setIsAuthenticated(true);
  }

  async function register(payload: Required<AuthPayload>) {
    await authApi.register(payload);
    setProfile(await userApi.getMe());
    setIsAuthenticated(true);
  }

  async function logout() {
    await authApi.logout();
    setProfile(null);
    setIsAuthenticated(false);
  }

  return (
    <AuthContext.Provider
      value={{
        isAuthLoading,
        isAuthenticated,
        profile,
        refreshProfile,
        updateProfile,
        uploadProfileImage,
        login,
        register,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
