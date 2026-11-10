import React, { useState } from "react";
import "./CreateChannelForm.scss";

const CreateChannelForm: React.FC = () => {
  const [name, setName] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [success, setSuccess] = useState(false);
  const [channelInfo, setChannelInfo] = useState<any>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);

    try {
      const res = await fetch("/api/channels", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, display_name: displayName }),
      });

      if (res.ok) {
        const data = await res.json();
        console.log("Channel created:", data);
        setChannelInfo(data); // ✅ save the response for rendering
        setName("");
        setDisplayName("");
        setSuccess(true);
      } else {
        console.error("Failed to create channel");
      }
    } catch (err) {
      console.error("Error submitting channel", err);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="create-channel-form">
      <h3>Create a New Channel</h3>
      <form onSubmit={handleSubmit}>
        <input
          type="text"
          placeholder="Internal name (e.g. channel42)"
          value={name}
          onChange={(e) => setName(e.target.value)}
          required
        />
        <input
          type="text"
          placeholder="Display name (e.g. Channel 42)"
          value={displayName}
          onChange={(e) => setDisplayName(e.target.value)}
          required
        />
        <button type="submit" disabled={submitting}>
          {submitting ? "Creating..." : "Create Channel"}
        </button>
      </form>

      {success && <p>✅ Channel created successfully!</p>}

      {channelInfo && (
        <div className="channel-details">
          <p><strong>Stream Key:</strong> {channelInfo.stream_key}</p>
          <p><strong>Ingest URL for OBS:</strong> rtmp://dainbramage.tv/live/{channelInfo.stream_key}</p>
          <p><strong>Playback URL (HLS):</strong> {channelInfo.playback_path}</p>

          <button onClick={() => navigator.clipboard.writeText(channelInfo.stream_key)}>
            Copy Stream Key
          </button>
        </div>
      )}
    </div>
  );
};

export default CreateChannelForm;
