import { CHAT_COLORS } from "./chatColors";

export function getUsernameColor(username: string): string {
  let hash = 0;
  for (let i = 0; i < username.length; i++) {
    hash = username.charCodeAt(i) + ((hash << 5) - hash);
  }
  const index = Math.abs(hash) % CHAT_COLORS.length;
  return CHAT_COLORS[index];
}
