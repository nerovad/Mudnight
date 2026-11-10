import React, { useState } from "react";
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  Modal,
  KeyboardAvoidingView,
  Platform,
} from "react-native";
import { useAuth } from "../contexts/AuthContext";

interface AuthModalProps {
  visible: boolean;
  onClose: () => void;
}

const AuthModal: React.FC<AuthModalProps> = ({ visible, onClose }) => {
  const { login, register } = useAuth();
  const [mode, setMode] = useState<"login" | "register">("login");
  const [email, setEmail] = useState("");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async () => {
    setError("");
    setLoading(true);
    try {
      let success: boolean;
      if (mode === "login") {
        success = await login(email, password);
      } else {
        success = await register(email, username, password);
      }
      if (success) {
        onClose();
        setEmail("");
        setUsername("");
        setPassword("");
      } else {
        setError(mode === "login" ? "Invalid credentials" : "Registration failed");
      }
    } catch {
      setError("Something went wrong");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <View style={styles.backdrop}>
        <KeyboardAvoidingView
          behavior={Platform.OS === "ios" ? "padding" : undefined}
          style={styles.modalContainer}
        >
          <View style={styles.card}>
            <TouchableOpacity style={styles.closeBtn} onPress={onClose}>
              <Text style={styles.closeText}>×</Text>
            </TouchableOpacity>

            <Text style={styles.title}>{mode === "login" ? "Login" : "Register"}</Text>

            <TextInput
              style={styles.input}
              placeholder={mode === "login" ? "Email or username" : "Email"}
              placeholderTextColor="#666"
              value={email}
              onChangeText={setEmail}
              autoCapitalize="none"
              keyboardType="email-address"
            />

            {mode === "register" && (
              <TextInput
                style={styles.input}
                placeholder="Username"
                placeholderTextColor="#666"
                value={username}
                onChangeText={setUsername}
                autoCapitalize="none"
              />
            )}

            <TextInput
              style={styles.input}
              placeholder="Password"
              placeholderTextColor="#666"
              value={password}
              onChangeText={setPassword}
              secureTextEntry
            />

            {error !== "" && <Text style={styles.error}>{error}</Text>}

            <TouchableOpacity
              style={[styles.submitBtn, loading && styles.submitBtnDisabled]}
              onPress={handleSubmit}
              disabled={loading}
            >
              <Text style={styles.submitText}>
                {loading ? "..." : mode === "login" ? "Login" : "Register"}
              </Text>
            </TouchableOpacity>

            <TouchableOpacity
              onPress={() => { setMode(mode === "login" ? "register" : "login"); setError(""); }}
            >
              <Text style={styles.switchText}>
                {mode === "login" ? "Don't have an account? Register" : "Already have an account? Login"}
              </Text>
            </TouchableOpacity>
          </View>
        </KeyboardAvoidingView>
      </View>
    </Modal>
  );
};

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: "rgba(0,0,0,0.7)",
    justifyContent: "center",
    alignItems: "center",
  },
  modalContainer: {
    width: "85%",
    maxWidth: 360,
  },
  card: {
    backgroundColor: "#1a1a2e",
    borderRadius: 12,
    padding: 24,
    borderWidth: 1,
    borderColor: "#2a2a4a",
  },
  closeBtn: {
    position: "absolute",
    top: 10,
    right: 14,
    zIndex: 1,
  },
  closeText: {
    color: "#888",
    fontSize: 24,
  },
  title: {
    color: "#e0e0e0",
    fontSize: 22,
    fontWeight: "bold",
    marginBottom: 20,
    textAlign: "center",
  },
  input: {
    backgroundColor: "#0d0d1a",
    borderRadius: 8,
    paddingHorizontal: 14,
    paddingVertical: 12,
    color: "#e0e0e0",
    fontSize: 14,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: "#2a2a4a",
  },
  error: {
    color: "#ff6b6b",
    fontSize: 13,
    marginBottom: 10,
    textAlign: "center",
  },
  submitBtn: {
    backgroundColor: "#4a4aff",
    borderRadius: 8,
    paddingVertical: 14,
    alignItems: "center",
    marginBottom: 14,
  },
  submitBtnDisabled: {
    opacity: 0.6,
  },
  submitText: {
    color: "#fff",
    fontWeight: "bold",
    fontSize: 15,
  },
  switchText: {
    color: "#6a6aff",
    fontSize: 13,
    textAlign: "center",
  },
});

export default AuthModal;
