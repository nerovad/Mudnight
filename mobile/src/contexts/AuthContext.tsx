import React, { createContext, useContext, useState, useEffect, ReactNode } from "react";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { API_BASE_URL } from "../config";

interface User {
  id: number;
  username: string;
  email: string;
}

interface AuthContextType {
  user: User | null;
  token: string | null;
  login: (emailOrUsername: string, password: string) => Promise<boolean>;
  register: (email: string, username: string, password: string) => Promise<boolean>;
  logout: () => void;
  isLoading: boolean;
  isAuthenticated: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    AsyncStorage.getItem("token").then((storedToken) => {
      if (storedToken) {
        setToken(storedToken);
        verifyToken(storedToken);
      } else {
        setIsLoading(false);
      }
    });
  }, []);

  const verifyToken = async (t: string) => {
    try {
      const res = await fetch(`${API_BASE_URL}/api/profile/me`, {
        headers: { Authorization: `Bearer ${t}` },
      });
      if (res.ok) {
        const data = await res.json();
        setUser({
          id: parseInt(data.id),
          username: data.handle?.replace("@", "") || "user",
          email: "user@example.com",
        });
      } else {
        await AsyncStorage.removeItem("token");
        setToken(null);
      }
    } catch {
      await AsyncStorage.removeItem("token");
      setToken(null);
    } finally {
      setIsLoading(false);
    }
  };

  const login = async (emailOrUsername: string, password: string): Promise<boolean> => {
    try {
      const res = await fetch(`${API_BASE_URL}/api/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: emailOrUsername, username: emailOrUsername, password }),
      });
      if (res.ok) {
        const { token: newToken } = await res.json();
        setToken(newToken);
        await AsyncStorage.setItem("token", newToken);
        await verifyToken(newToken);
        return true;
      }
      return false;
    } catch {
      return false;
    }
  };

  const register = async (email: string, username: string, password: string): Promise<boolean> => {
    try {
      const res = await fetch(`${API_BASE_URL}/api/auth/register`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, username, password }),
      });
      if (res.ok) {
        return await login(email, password);
      }
      return false;
    } catch {
      return false;
    }
  };

  const logout = async () => {
    setUser(null);
    setToken(null);
    await AsyncStorage.removeItem("token");
  };

  return (
    <AuthContext.Provider
      value={{ user, token, login, register, logout, isLoading, isAuthenticated: !!(token && user) }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export function useAuth(): AuthContextType {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
