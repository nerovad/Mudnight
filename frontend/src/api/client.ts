// src/api/client.ts
import { API_BASE_URL } from "../config";

const BASE_URL = API_BASE_URL;

export function authHeaders(): Record<string, string> {
  const token = localStorage.getItem("token");
  return token ? { Authorization: `Bearer ${token}` } : {};
}

async function request(path: string, options: RequestInit = {}) {
  const res = await fetch(`${BASE_URL}${path}`, {
    headers: {
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
    credentials: "include", // if you use cookies/sessions
    ...options,
  });
  if (!res.ok) {
    throw new Error(await res.text());
  }
  return res.json();
}

export const api = {
  // Channels
  createChannel: (body: any) =>
    request("/channels", { method: "POST", body: JSON.stringify(body) }),
  listChannels: () => request("/channels"),

  // Festivals / Sessions
  createSession: (body: any) =>
    request("/sessions", { method: "POST", body: JSON.stringify(body) }),
  startSession: (id: number) =>
    request(`/sessions/${id}/start`, { method: "POST" }),
  closeSession: (id: number) =>
    request(`/sessions/${id}/close`, { method: "POST" }),
  leaderboard: (id: number) => request(`/sessions/${id}/leaderboard`),

  // Lineups
  lineup: (sessionId: number) =>
    request(`/sessions/${sessionId}/lineup`),
  addEntry: (sessionId: number, body: any) =>
    request(`/sessions/${sessionId}/lineup`, {
      method: "POST",
      body: JSON.stringify(body),
    }),
};
