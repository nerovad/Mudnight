import React, { useState } from "react";
import "./Upload.scss";

const Upload: React.FC = () => {
  const [festivalType, setFestivalType] = useState<string>("classic");
  const [streamKey, setStreamKey] = useState<string>("");
  const [customSettings, setCustomSettings] = useState<string>("");

  return (
    <div className="upload-page">
      <h1>Upload & Live Stream</h1>

      <div className="upload-section">
        <label htmlFor="streamKey">Stream Key:</label>
        <input
          type="text"
          id="streamKey"
          value={streamKey}
          onChange={(e) => setStreamKey(e.target.value)}
          placeholder="Enter your stream key"
        />
      </div>

      <div className="festival-section">
        <label>Festival Type:</label>
        <select value={festivalType} onChange={(e) => setFestivalType(e.target.value)}>
          <option value="classic">Classic Festival (Voting System)</option>
          <option value="tournament">Tournament Bracket</option>
          <option value="battle-royale">Battle Royale</option>
        </select>
      </div>

      {festivalType !== "classic" && (
        <div className="custom-settings">
          <label htmlFor="customSettings">Custom Settings:</label>
          <textarea
            id="customSettings"
            value={customSettings}
            onChange={(e) => setCustomSettings(e.target.value)}
            placeholder="Enter custom settings for your festival"
          />
        </div>
      )}

      <button className="upload-btn">Start Live Stream</button>
    </div>
  );
};

export default Upload;

