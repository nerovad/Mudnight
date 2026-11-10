import { getStorage } from "../storage";

let baseUrl = "http://localhost:4000";

export function setApiBaseUrl(url: string) {
  baseUrl = url;
}

export function getApiBaseUrl(): string {
  return baseUrl;
}

export async function authHeaders(): Promise<Record<string, string>> {
  const token = await getStorage().getItem("token");
  return token ? { Authorization: `Bearer ${token}` } : {};
}

async function request(path: string, options: RequestInit = {}) {
  const auth = await authHeaders();
  const res = await fetch(`${baseUrl}${path}`, {
    headers: {
      "Content-Type": "application/json",
      ...auth,
      ...(options.headers || {}),
    },
    ...options,
  });
  if (!res.ok) {
    throw new Error(await res.text());
  }
  return res.json();
}

export const api = {
  // Channels
  createChannel: (body: Record<string, unknown>) =>
    request("/channels", { method: "POST", body: JSON.stringify(body) }),
  listChannels: () => request("/channels"),

  // Festivals / Sessions
  createSession: (body: Record<string, unknown>) =>
    request("/sessions", { method: "POST", body: JSON.stringify(body) }),
  startSession: (id: number) =>
    request(`/sessions/${id}/start`, { method: "POST" }),
  closeSession: (id: number) =>
    request(`/sessions/${id}/close`, { method: "POST" }),
  leaderboard: (id: number) => request(`/sessions/${id}/leaderboard`),

  // Lineups
  lineup: (sessionId: number) =>
    request(`/sessions/${sessionId}/lineup`),
  addEntry: (sessionId: number, body: Record<string, unknown>) =>
    request(`/sessions/${sessionId}/lineup`, {
      method: "POST",
      body: JSON.stringify(body),
    }),
};
