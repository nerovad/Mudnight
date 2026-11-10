import React, { useState } from "react";
import "./Channel.scss";

const Channel: React.FC = () => {
  const [channelName, setChannelName] = useState("");
  const [description, setDescription] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    console.log("Create channel:", { channelName, description });
    // TODO: hook up to backend POST /channels
  };

  return (
    <div className="channel-container">
      <h2>Create a Channel</h2>
      <form className="channel-form" onSubmit={handleSubmit}>
        <label>
          Channel Name
          <input
            type="text"
            value={channelName}
            onChange={(e) => setChannelName(e.target.value)}
            required
          />
        </label>
        <label>
          Description
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            rows={4}
          />
        </label>
        <button type="submit">Create Channel</button>
      </form>
    </div>
  );
};

export default Channel;
