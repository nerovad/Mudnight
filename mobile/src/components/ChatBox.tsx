import React, { useEffect, useState, useRef } from "react";
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  FlatList,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
} from "react-native";
import io, { Socket } from "@cinezoo/shared/realtime";
import { useChatStore, getUsernameColor } from "@cinezoo/shared";
import { SOCKET_URL, API_BASE_URL } from "../config";
import { useAuth } from "../contexts/AuthContext";

let socket: Socket;

function getSocket(): Socket {
  if (!socket) {
    socket = io(SOCKET_URL, {
      transports: ["websocket"],
    });
  }
  return socket;
}

const ChatBox: React.FC = () => {
  const { channelId, userId, setUserId, messages, setMessages, addMessage } = useChatStore();
  const { token } = useAuth();
  const [message, setMessage] = useState("");
  const [isConnected, setIsConnected] = useState(false);
  const flatListRef = useRef<FlatList>(null);

  // Load user ID from token
  useEffect(() => {
    if (!token) return;
    fetch(`${API_BASE_URL}/api/profile/me`, {
      headers: { Authorization: `Bearer ${token}` },
    })
      .then((r) => r.json())
      .then((data) => {
        if (data?.id) {
          setUserId(typeof data.id === "string" ? parseInt(data.id) : data.id);
        }
      })
      .catch(() => {});
  }, [token, setUserId]);

  // Socket connection
  useEffect(() => {
    const s = getSocket();
    const onConnect = () => setIsConnected(true);
    const onDisconnect = () => setIsConnected(false);

    s.on("connect", onConnect);
    s.on("disconnect", onDisconnect);
    setIsConnected(s.connected);

    return () => {
      s.off("connect", onConnect);
      s.off("disconnect", onDisconnect);
    };
  }, []);

  // Join room + listen for messages
  useEffect(() => {
    if (!channelId) return;
    const s = getSocket();

    s.emit("joinRoom", { channelId });

    const onHistory = (history: any[]) => {
      const formatted = history.map((msg) => ({
        user: msg.username || "Unknown",
        content: msg.content,
        created_at: msg.created_at,
      }));
      setMessages(formatted);
    };

    const onReceive = (newMsg: { user: string; content: string; created_at?: string }) => {
      addMessage({
        user: newMsg.user,
        content: newMsg.content,
        created_at: newMsg.created_at ?? new Date().toISOString(),
      });
    };

    s.off("chatHistory").off("receiveMessage");
    s.on("chatHistory", onHistory);
    s.on("receiveMessage", onReceive);

    return () => {
      s.off("chatHistory", onHistory);
      s.off("receiveMessage", onReceive);
    };
  }, [channelId, setMessages, addMessage]);

  // Filter old messages every minute
  useEffect(() => {
    const interval = setInterval(() => {
      const oneHourAgo = Date.now() - 60 * 60 * 1000;
      setMessages((prev) =>
        prev.filter((msg) => {
          if (!msg.created_at) return true;
          return new Date(msg.created_at).getTime() > oneHourAgo;
        })
      );
    }, 60000);
    return () => clearInterval(interval);
  }, [setMessages]);

  const sendMessage = () => {
    const text = message.trim();
    if (!text || !userId || !channelId || !isConnected) return;
    getSocket().emit("sendMessage", { userId, message: text, channelId });
    setMessage("");
  };

  // Auto-scroll to bottom on new messages
  useEffect(() => {
    if (messages.length > 0) {
      setTimeout(() => flatListRef.current?.scrollToEnd({ animated: true }), 100);
    }
  }, [messages.length]);

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === "ios" ? "padding" : undefined}
      keyboardVerticalOffset={60}
    >
      <Text style={styles.header}>Live Chat</Text>

      <FlatList
        ref={flatListRef}
        data={messages}
        keyExtractor={(_, i) => String(i)}
        style={styles.messageList}
        renderItem={({ item }) => (
          <View style={styles.messageRow}>
            <Text style={[styles.username, { color: getUsernameColor(item.user) }]}>
              {item.user}:
            </Text>
            <Text style={styles.messageText}> {item.content}</Text>
          </View>
        )}
      />

      <View style={styles.inputRow}>
        <TextInput
          style={styles.input}
          value={message}
          onChangeText={setMessage}
          placeholder="Type a message..."
          placeholderTextColor="#666"
          returnKeyType="send"
          onSubmitEditing={sendMessage}
        />
        <TouchableOpacity style={styles.sendBtn} onPress={sendMessage}>
          <Text style={styles.sendText}>Send</Text>
        </TouchableOpacity>
      </View>
    </KeyboardAvoidingView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#12122a",
  },
  header: {
    color: "#e0e0e0",
    fontSize: 15,
    fontWeight: "bold",
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: "#2a2a4a",
  },
  messageList: {
    flex: 1,
    paddingHorizontal: 12,
    paddingTop: 4,
  },
  messageRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    marginBottom: 4,
  },
  username: {
    fontWeight: "bold",
    fontSize: 13,
  },
  messageText: {
    color: "#d0d0d0",
    fontSize: 13,
  },
  inputRow: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 8,
    paddingVertical: 6,
    borderTopWidth: 1,
    borderTopColor: "#2a2a4a",
    backgroundColor: "#0d0d1a",
  },
  input: {
    flex: 1,
    height: 36,
    backgroundColor: "#1a1a2e",
    borderRadius: 18,
    paddingHorizontal: 14,
    color: "#e0e0e0",
    fontSize: 13,
  },
  sendBtn: {
    marginLeft: 8,
    backgroundColor: "#4a4aff",
    borderRadius: 18,
    paddingHorizontal: 16,
    paddingVertical: 8,
  },
  sendText: {
    color: "#fff",
    fontWeight: "bold",
    fontSize: 13,
  },
});

export default ChatBox;
