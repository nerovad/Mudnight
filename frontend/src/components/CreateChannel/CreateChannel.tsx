import React, { useEffect, useState } from "react";

const CreateChannelForm: React.FC = () => {
  const [channelName, setChannelName] = useState("");
  const [selectedNumber, setSelectedNumber] = useState("");
  const [error, setError] = useState("");
  const [takenChannelNumbers, setTakenChannelNumbers] = useState<Set<number>>(new Set());
  const [loadingChannels, setLoadingChannels] = useState(true);

  // Generate available channel numbers (2-99), excluding taken ones
  const availableChannels = Array.from({ length: 98 }, (_, i) => i + 2)
    .filter(num => !takenChannelNumbers.has(num));

  // Fetch existing channels to determine taken channel numbers
  useEffect(() => {
    const fetchTakenChannels = async () => {
      setLoadingChannels(true);
      try {
        const res = await fetch("/api/channels");
        if (res.ok) {
          const channels = await res.json();
          const taken = new Set<number>(
            channels
              .map((ch: any) => ch.channel_number)
              .filter((num: any) => typeof num === 'number')
          );
          setTakenChannelNumbers(taken);
        }
      } catch (err) {
        console.error("Failed to fetch channels:", err);
      } finally {
        setLoadingChannels(false);
      }
    };

    fetchTakenChannels();
  }, []);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (!channelName.trim()) {
      setError("Channel name is required");
      return;
    }

    if (!selectedNumber) {
      setError("Please select a channel number");
      return;
    }

    // Auto-generate slug from name
    const slug = channelName
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9]+/g, "-") // replace non-alphanumeric with hyphens
      .replace(/^-+|-+$/g, "");     // remove leading/trailing hyphens

    // TODO: Send to API/backend
    console.log({
      name: channelName,
      number: parseInt(selectedNumber),
      slug: slug
    });

    setError("");
  };

  return (
    <form className="create-channel-form" onSubmit={handleSubmit}>
      <div className="form-group">
        <label htmlFor="channel-name">Channel Name:</label>
        <input
          id="channel-name"
          type="text"
          value={channelName}
          onChange={(e) => setChannelName(e.target.value.slice(0, 20))}
          maxLength={20}
          placeholder="Enter channel name..."
          autoFocus
        />
        <small>{channelName.length}/20 characters</small>
      </div>

      <div className="form-group">
        <label htmlFor="channel-number">Channel Number:</label>
        <select
          id="channel-number"
          value={selectedNumber}
          onChange={(e) => setSelectedNumber(e.target.value)}
          disabled={loadingChannels}
        >
          <option value="">
            {loadingChannels ? "Loading available channels..." : "Select a channel number..."}
          </option>
          {availableChannels.map(num => (
            <option key={num} value={num}>
              Channel {num}
            </option>
          ))}
        </select>
        {!loadingChannels && availableChannels.length === 0 && (
          <small style={{ color: '#ff6b6b' }}>All channel numbers are taken.</small>
        )}
      </div>

      {error && <div className="error-message">{error}</div>}

      <button type="submit" className="submit-btn">
        Create Channel
      </button>
    </form>
  );
};

export default CreateChannelForm;
