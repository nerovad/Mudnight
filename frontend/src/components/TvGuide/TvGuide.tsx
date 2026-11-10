import React, { useEffect, useRef, useState, useMemo } from "react";
import "./TvGuide.scss";
import { useApi } from "../../utils/useApi";

type Channel = {
  id: string;
  name: string;
  display_name?: string;
  channel_number?: number;  // ADD THIS
  slug?: string;
  description?: string;
  isLive?: boolean;
  thumbnail?: string;
};

interface TvGuideProps {
  isOpen: boolean;
  closeGuide: () => void;
}

const TvGuide: React.FC<TvGuideProps> = ({ isOpen, closeGuide }) => {
  const guideRef = useRef<HTMLDivElement>(null);
  const api = useApi();
  const [channels, setChannels] = useState<Channel[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const remoteButton = document.getElementById("remote-button");
      if (
        guideRef.current &&
        !guideRef.current.contains(event.target as Node) &&
        remoteButton &&
        !remoteButton.contains(event.target as Node)
      ) {
        closeGuide();
      }
    };

    if (isOpen) {
      document.addEventListener("mousedown", handleClickOutside);
    }

    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, [isOpen, closeGuide]);

  // Load channels when guide opens (same logic as profile.tsx)
  useEffect(() => {
    let mounted = true;

    const loadChannels = async () => {
      if (!isOpen) return;

      setLoading(true);
      try {
        // Fetch all channels (not just the user's own)
        const channelsData = await api.get("/api/channels", []);
        if (mounted) setChannels(channelsData);
      } catch (error) {
        console.error('Failed to load channels:', error);
      } finally {
        if (mounted) setLoading(false);
      }
    };

    loadChannels();

    return () => {
      mounted = false;
    };
  }, [isOpen]);

  // Sort channels by channel_number
  const sortedChannels = useMemo(() => {
    return [...channels].sort((a, b) => {
      // Put channels without numbers at the end
      if (a.channel_number === undefined && b.channel_number === undefined) return 0;
      if (a.channel_number === undefined) return 1;
      if (b.channel_number === undefined) return -1;
      return a.channel_number - b.channel_number;
    });
  }, [channels]);

  const handleChannelClick = (channel: Channel) => {
    // Use the same navigation logic as profile.tsx
    const url = channel.slug ? `/channel/${channel.slug}` : `/channel/${channel.id}`;
    window.location.href = url;
    closeGuide();
  };

  if (!isOpen) return null;

  return (
    <div className="tv-guide-overlay">
      <div className="tv-guide-content" ref={guideRef}>
        <button className="close-btn" onClick={closeGuide}>
          X
        </button>
        <h2>TV Guide</h2>

        {loading ? (
          <div className="guide-loading">Loading channels...</div>
        ) : channels.length === 0 ? (
          <p className="no-channels">No channels available yet.</p>
        ) : (
          <ul>
            {sortedChannels.map((channel) => (
              <li key={channel.id}>
                <button
                  className="channel-link"
                  onClick={() => handleChannelClick(channel)}
                >
                  <span className="channel-name">
                    {channel.channel_number ? `Channel ${channel.channel_number}` : ''}
                    {channel.display_name ? ` - ${channel.display_name}` : channel.name}
                  </span>
                  {channel.isLive && <span className="live-indicator">● LIVE</span>}
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
};

export default TvGuide;
