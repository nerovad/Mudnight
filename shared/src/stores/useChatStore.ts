import { create } from "zustand";
import type { ChatMessage, ChatState } from "../types";

export const useChatStore = create<ChatState>((set) => ({
  userId: null,
  channelId: "default-channel",
  messages: [],

  setUserId: (id) => set({ userId: id }),

  setChannelId: (id) => {
    console.log(` Zustand: Updating channelId to ${id}`);
    set({ channelId: id });
  },

  setMessages: (messages) =>
    set((state) => ({
      messages: typeof messages === 'function' ? messages(state.messages) : messages
    })),

  addMessage: (message) =>
    set((state) => ({ messages: [...state.messages, message] })),
}));

export type { ChatMessage, ChatState };
