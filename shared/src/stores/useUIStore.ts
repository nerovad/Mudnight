import { create } from "zustand";
import type { UIState } from "../types";

export const useUIStore = create<UIState>((set) => ({
  isMobile: false,
  isMenuOpen: true,
  isChatOpen: true,
  setIsMobile: (isMobile) => set({ isMobile }),
  setIsMenuOpen: (isOpen) => set({ isMenuOpen: isOpen }),
  setIsChatOpen: (isOpen) => set({ isChatOpen: isOpen }),
  toggleMenu: () => set((state) => ({ isMenuOpen: !state.isMenuOpen })),
  toggleChat: () => set((state) => ({ isChatOpen: !state.isChatOpen })),
}));

export type { UIState };
