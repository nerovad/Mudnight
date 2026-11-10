// User & Auth types (extracted from AuthContext.tsx)
export interface User {
  id: number;
  username: string;
  email: string;
}

export interface AuthContextType {
  user: User | null;
  token: string | null;
  login: (email: string, password: string) => Promise<boolean>;
  register: (email: string, username: string, password: string) => Promise<boolean>;
  logout: () => void;
  isLoading: boolean;
  isAuthenticated: boolean;
}

// Chat types (extracted from useChatStore.ts)
export interface ChatMessage {
  user: string;
  content: string;
  created_at?: string;
}

export interface ChatState {
  userId: number | null;
  channelId: string;
  messages: ChatMessage[];
  setUserId: (id: number) => void;
  setChannelId: (id: string) => void;
  setMessages: (messages: ChatMessage[] | ((prev: ChatMessage[]) => ChatMessage[])) => void;
  addMessage: (message: ChatMessage) => void;
}

// UI types (extracted from useUIStore.ts)
export interface UIState {
  isMobile: boolean;
  isMenuOpen: boolean;
  isChatOpen: boolean;
  setIsMobile: (isMobile: boolean) => void;
  setIsMenuOpen: (isOpen: boolean) => void;
  setIsChatOpen: (isOpen: boolean) => void;
  toggleMenu: () => void;
  toggleChat: () => void;
}

// Domain types
export interface Channel {
  id: number;
  name: string;
  description?: string;
}

export interface Film {
  id: number;
  title: string;
  description?: string;
  url?: string;
}

export interface ProfileData {
  id: string;
  handle: string;
  bio?: string;
  avatar_url?: string;
}

export interface DirectMessage {
  id: number;
  senderId: number;
  receiverId: number;
  content: string;
  createdAt: string;
  expiresAt: string;
}

export interface Conversation {
  userId: number;
  userHandle: string;
  lastMessage: string;
  lastMessageTime: string;
  unreadCount: number;
}
