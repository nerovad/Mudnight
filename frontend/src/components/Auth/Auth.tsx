import React, { useState } from "react";
import TermsOfService from "./TermsOfService";
import { useAuth } from "../../store/AuthContext";
import { API_BASE_URL } from "../../config";
import "./Auth.scss";

interface AuthProps {
  setIsAuthOpen: React.Dispatch<React.SetStateAction<boolean>>;
  authMode: "login" | "register";
  setAuthMode: React.Dispatch<React.SetStateAction<"login" | "register">>;
}

const Auth: React.FC<AuthProps> = ({ setIsAuthOpen, authMode, setAuthMode }) => {
  const { login } = useAuth();
  const [emailOrUsername, setEmailOrUsername] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [email, setEmail] = useState("");
  const [username, setUsername] = useState("");
  const [showTos, setShowTos] = useState(false);
  const [showForgotPassword, setShowForgotPassword] = useState(false);
  const [forgotEmail, setForgotEmail] = useState("");
  const [forgotMessage, setForgotMessage] = useState("");

  const handleForgotPassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setForgotMessage("");
    try {
      const res = await fetch(`${API_BASE_URL}/api/auth/forgot-password`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: forgotEmail }),
      });
      const data = await res.json();
      if (!res.ok) {
        setForgotMessage("Something went wrong. Please try again.");
        return;
      }
      setForgotMessage(data.message || "If that email is registered, a temporary password has been sent.");
    } catch {
      setForgotMessage("Something went wrong. Please try again.");
    } finally {
      setSubmitting(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    // If registering, show ToS first
    if (authMode === "register") {
      setShowTos(true);
      return;
    }

    // Otherwise, proceed with login
    await proceedWithAuth();
  };

  const proceedWithAuth = async () => {
    if (authMode === "register" && password !== confirmPassword) {
      alert("Passwords do not match.");
      return;
    }

    setSubmitting(true);
    try {
      if (authMode === "login") {
        // Use AuthContext's login method - this properly sets user state
        const success = await login(emailOrUsername, password);
        if (success) {
          setIsAuthOpen(false);
        } else {
          throw new Error("Login failed. Please check your credentials.");
        }
      } else {
        // Registration - keep existing flow
        const res = await fetch(`${API_BASE_URL}/api/auth/register`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ email, username, password }),
        });

        const text = await res.text();
        let data: any = {};
        try {
          data = text ? JSON.parse(text) : {};
        } catch {
          // response wasn't JSON
        }

        if (!res.ok) {
          const message =
            data?.error ||
            data?.message ||
            `Request failed (${res.status})${text ? `: ${text.slice(0, 200)}` : ""}`;
          throw new Error(message);
        }

        alert("Registration successful! You can now log in.");
        setAuthMode("login");
      }
    } catch (err: any) {
      console.error("Auth error:", err);
      alert(err?.message || "Something went wrong.");
    } finally {
      setSubmitting(false);
    }
  }; return (
    <div className="auth-overlay">
      <div className="auth-card">
        <button className="close-btn" onClick={() => setIsAuthOpen(false)} disabled={submitting}>
          ✖
        </button>
        {showForgotPassword ? (
          <>
            <h2>Forgot Password</h2>
            <form onSubmit={handleForgotPassword}>
              <input
                type="email"
                placeholder="Enter your email"
                value={forgotEmail}
                onChange={(e) => setForgotEmail(e.target.value)}
                required
                disabled={submitting}
              />
              <button type="submit" disabled={submitting}>
                {submitting ? "Please wait…" : "Send Temporary Password"}
              </button>
            </form>
            {forgotMessage && <p className="forgot-message">{forgotMessage}</p>}
            <p>
              <span onClick={() => { setShowForgotPassword(false); setForgotMessage(""); }}>
                Back to Login
              </span>
            </p>
          </>
        ) : (
          <>
            <h2>{authMode === "login" ? "Login" : "Register"}</h2>
            <form onSubmit={handleSubmit}>
              {authMode === "register" ? (
                <>
                  <input
                    type="email"
                    placeholder="Email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    required
                    disabled={submitting}
                  />
                  <input
                    type="text"
                    placeholder="Username"
                    value={username}
                    onChange={(e) => setUsername(e.target.value)}
                    required
                    disabled={submitting}
                  />
                </>
              ) : (
                <input
                  type="text"
                  placeholder="Email or Username"
                  value={emailOrUsername}
                  onChange={(e) => setEmailOrUsername(e.target.value)}
                  required
                  disabled={submitting}
                />
              )}
              <input
                type="password"
                placeholder="Password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                disabled={submitting}
              />
              {authMode === "register" && (
                <input
                  type="password"
                  placeholder="Confirm Password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  required
                  disabled={submitting}
                />
              )}
              <button type="submit" disabled={submitting}>
                {submitting ? "Please wait…" : authMode === "login" ? "Login" : "Register"}
              </button>
            </form>
            {authMode === "login" && (
              <p>
                <span onClick={() => setShowForgotPassword(true)}>Forgot password?</span>
              </p>
            )}
            <p>
              {authMode === "login" ? "Don't have an account?" : "Already have an account?"}
              <span onClick={() => setAuthMode(authMode === "login" ? "register" : "login")}>
                {authMode === "login" ? " Register" : " Login"}
              </span>
            </p>
          </>
        )}
      </div>
      {showTos && (
        <TermsOfService
          onAccept={() => {
            setShowTos(false);
            proceedWithAuth();
          }}
          onDecline={() => {
            setShowTos(false);
          }}
        />
      )}
    </div>
  );
};

export default Auth;
