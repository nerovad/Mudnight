import React, { useState } from "react";
import "./Settings.scss";

const Settings: React.FC = () => {
  const [username, setUsername] = useState<string>("");
  const [email, setEmail] = useState<string>("");
  const [password, setPassword] = useState<string>("");
  const [theme, setTheme] = useState<string>("light");
  const [notifications, setNotifications] = useState<boolean>(true);

  return (
    <div className="settings-page">
      <h1>User Settings</h1>

      <div className="settings-section">
        <label htmlFor="username">Username:</label>
        <input
          type="text"
          id="username"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          placeholder="Enter username"
        />
      </div>

      <div className="settings-section">
        <label htmlFor="email">Email:</label>
        <input
          type="email"
          id="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="Enter email"
        />
      </div>

      <div className="settings-section">
        <label htmlFor="password">New Password:</label>
        <input
          type="password"
          id="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder="Enter new password"
        />
      </div>

      <div className="settings-section">
        <label>Theme:</label>
        <select value={theme} onChange={(e) => setTheme(e.target.value)}>
          <option value="light">Light</option>
          <option value="dark">Dark</option>
        </select>
      </div>

      <div className="settings-section">
        <label>
          <input
            type="checkbox"
            checked={notifications}
            onChange={() => setNotifications(!notifications)}
          />
          Enable Notifications
        </label>
      </div>

      <button className="save-btn">Save Changes</button>
    </div>
  );
};

export default Settings;

