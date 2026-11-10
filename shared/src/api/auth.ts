import { getApiBaseUrl } from "./client";

export const registerUser = async (email: string, password: string) => {
  const response = await fetch(`${getApiBaseUrl()}/api/auth/register`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  return response.json();
};

export const loginUser = async (email: string, password: string) => {
  const response = await fetch(`${getApiBaseUrl()}/api/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  return response.json();
};

export const getProfile = async (token: string) => {
  const response = await fetch(`${getApiBaseUrl()}/api/profile/me`, {
    method: "GET",
    headers: { Authorization: `Bearer ${token}` },
  });
  return response.json();
};
