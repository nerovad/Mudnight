import React, { useEffect, useState } from "react";
import io from "@cinezoo/shared/realtime";
import "./Chatbox.scss";
import FastForwardIcon from "../../assets/fast_forward_icon.svg";
import { useChatStore } from "../../store/useChatStore";
import { getUsernameColor } from "../../utils/getUsernameColor";
import { API_BASE_URL, SOCKET_URL } from "../../config";

const socket = io(SOCKET_URL, {
  withCredentials: true,
  transports: ["websocket"],
});

interface ChatboxProps {
  isOpen: boolean;
  setIsOpen: React.Dispatch<React.SetStateAction<boolean>>;
  mobileInline?: boolean;
}

const Chatbox: React.FC<ChatboxProps> = ({ isOpen, setIsOpen, mobileInline = false }) => {
  const { channelId, userId, setUserId, messages, setMessages, addMessage } = useChatStore();
  const [message, setMessage] = useState("");
  const [isConnected, setIsConnected] = useState(false);

  // Load user id once
  useEffect(() => {
    const token = localStorage.getItem("token");
    if (!token) {
      console.warn("⚠️ No token found, user not logged in");
      return;
    }
    console.log("🔑 Fetching user profile with token...");
    fetch(`${API_BASE_URL}/api/profile/me`, {
      headers: { Authorization: `Bearer ${token}` },
    })
      .then((r) => {
        console.log("📡 Profile API response status:", r.status);
        return r.json();
      })
      .then((data) => {
        console.log("👤 Profile data received:", data);
        if (data?.id) {
          const numericId = typeof data.id === 'string' ? parseInt(data.id) : data.id;
          console.log("✅ Setting userId to:", numericId);
          setUserId(numericId);
        } else {
          console.error("❌ No id in profile data:", data);
        }
      })
      .catch((e) => console.error("❌ Error fetching user ID:", e));
  }, [setUserId]);

  // Track connection status
  useEffect(() => {
    const onConnect = () => {
      console.log("✅ Socket connected");
      setIsConnected(true);
    };
    const onDisconnect = () => {
      console.log("❌ Socket disconnected");
      setIsConnected(false);
    };

    socket.on("connect", onConnect);
    socket.on("disconnect", onDisconnect);

    // Set initial state
    setIsConnected(socket.connected);

    return () => {
      socket.off("connect", onConnect);
      socket.off("disconnect", onDisconnect);
    };
  }, []);

  // Join room + wire listeners
  useEffect(() => {
    if (!channelId) {
      console.warn("⚠️ No channelId set, cannot join room");
      return;
    }

    console.log(`🔌 Joining room: ${channelId}`);
    socket.emit("joinRoom", { channelId });

    const onHistory = (chatHistory: any[]) => {
      console.log(`📜 Received chat history for ${channelId}:`, chatHistory.length, "messages");
      const formatted = chatHistory.map((msg) => ({
        user: msg.username || "Unknown",
        content: msg.content,
        created_at: msg.created_at,
      }));
      setMessages(formatted);
    };

    const onReceive = (newMsg: { user: string; content: string; created_at?: string }) => {
      console.log("📨 Received new message:", newMsg);
      addMessage({
        user: newMsg.user,
        content: newMsg.content,
        created_at: newMsg.created_at ?? new Date().toISOString(),
      });
    };

    // prevent duplicate handlers (hot reload / StrictMode)
    socket.off("chatHistory").off("receiveMessage");
    socket.on("chatHistory", onHistory);
    socket.on("receiveMessage", onReceive);

    return () => {
      socket.off("chatHistory", onHistory);
      socket.off("receiveMessage", onReceive);
    };
  }, [channelId, setMessages, addMessage]);

  // Filter out messages older than 1 hour every minute
  useEffect(() => {
    const filterOldMessages = () => {
      const oneHourAgo = Date.now() - 60 * 60 * 1000;
      setMessages((prevMessages) =>
        prevMessages.filter((msg) => {
          if (!msg.created_at) return true;
          const msgTime = new Date(msg.created_at).getTime();
          return msgTime > oneHourAgo;
        })
      );
    };

    const interval = setInterval(filterOldMessages, 60 * 1000); // Check every minute
    return () => clearInterval(interval);
  }, [setMessages]);

  const sendMessage = () => {
    const text = message.trim();
    if (!text) {
      console.warn("⚠️ Cannot send empty message");
      return;
    }
    if (!userId) {
      console.error("❌ Cannot send message: userId is", userId);
      alert("Please log in to send messages");
      return;
    }
    if (!channelId) {
      console.error("❌ Cannot send message: channelId is", channelId);
      return;
    }
    if (!isConnected) {
      console.error("❌ Cannot send message: socket not connected");
      alert("Chat not connected. Please refresh the page.");
      return;
    }
    console.log("📤 Sending message:", { userId, channelId, text });
    socket.emit("sendMessage", { userId, message: text, channelId });
    setMessage("");
  };

  return (
    <div className={`chatbox-container ${isOpen ? "open" : ""} ${mobileInline ? "mobile-inline" : ""}`}>
      {/* Hide toggle arrow in mobile portrait inline mode */}
      {!mobileInline && (
        <button
          className={`toggle-button-right ${isOpen ? "open" : ""}`}
          onClick={() => setIsOpen(!isOpen)}
        >
          <img src={FastForwardIcon} alt="Toggle Chat" />
        </button>
      )}

      <div className={`chatbox-content ${isOpen ? "open" : ""}`}>
        <h3>Live Chat</h3>

        <div className="messages">
          {messages.map((msg, index) => (
            <p key={index}>
              <strong style={{ color: getUsernameColor(msg.user) }}>{msg.user}:</strong>{" "}
              {msg.content}
            </p>
          ))}
        </div>

        <input
          type="text"
          placeholder="Type a message..."
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && sendMessage()}
        />
        <button className="chat-button" onClick={sendMessage}>
          Send
        </button>
      </div>
    </div>
  );
};

export default Chatbox;
