import React, { useEffect, useRef, useState } from "react";
import "./AnalyticsModal.scss";

interface AnalyticsData {
  channel: {
    id: number;
    display_name: string | null;
    name: string;
    channel_number: number | null;
    created_at: string;
    owner_name?: string;
  };
  sessions: {
    total: number;
    live: number;
    completed: number;
    first_session: string | null;
    latest_session: string | null;
  };
  engagement: {
    total_entries: number;
    total_ballots: number;
    total_ratings: number;
    avg_rating: number | null;
    total_match_votes: number;
    unique_voters: number;
  };
  chat: {
    total_messages: number;
  };
  schedule: {
    total_items: number;
  };
  recent_sessions: {
    id: number;
    title: string;
    starts_at: string;
    ends_at: string | null;
    status: string;
    created_at: string;
  }[];
}

interface Props {
  isOpen: boolean;
  onClose: () => void;
  apiUrl: string; // e.g. "/api/channels/123/analytics" or "/api/admin/channels/123/analytics"
}

const AnalyticsModal: React.FC<Props> = ({ isOpen, onClose, apiUrl }) => {
  const [data, setData] = useState<AnalyticsData | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const boxRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!isOpen) return;

    setLoading(true);
    setError(null);
    setData(null);

    const token = localStorage.getItem("token");
    fetch(apiUrl, {
      headers: { Authorization: `Bearer ${token}` },
    })
      .then((res) => {
        if (!res.ok) throw new Error("Failed to load analytics");
        return res.json();
      })
      .then((d) => setData(d))
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [isOpen, apiUrl]);

  useEffect(() => {
    if (!isOpen) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    const onClick = (e: MouseEvent) => {
      if (boxRef.current && !boxRef.current.contains(e.target as Node)) onClose();
    };

    document.addEventListener("keydown", onKey);
    document.addEventListener("mousedown", onClick);
    return () => {
      document.body.style.overflow = prev;
      document.removeEventListener("keydown", onKey);
      document.removeEventListener("mousedown", onClick);
    };
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  const formatDate = (d: string | null) => {
    if (!d) return "--";
    return new Date(d).toLocaleDateString(undefined, {
      year: "numeric",
      month: "short",
      day: "numeric",
    });
  };

  const statusClass = (status: string) => {
    switch (status) {
      case "live": return "analytics-status--live";
      case "closed":
      case "archived": return "analytics-status--closed";
      default: return "analytics-status--scheduled";
    }
  };

  return (
    <div className="analytics-overlay" role="dialog" aria-modal="true">
      <div className="analytics-content" ref={boxRef}>
        <button className="analytics-close" onClick={onClose}>X</button>

        {loading && <div className="analytics-loading">Loading analytics...</div>}
        {error && <div className="analytics-error">{error}</div>}

        {data && (
          <>
            <h2 className="analytics-title">
              {data.channel.display_name || data.channel.name}
              {data.channel.channel_number && (
                <span className="analytics-channel-num"> Ch. {data.channel.channel_number}</span>
              )}
            </h2>
            {data.channel.owner_name && (
              <div className="analytics-owner">Owner: {data.channel.owner_name}</div>
            )}
            <div className="analytics-created">Created {formatDate(data.channel.created_at)}</div>

            <div className="analytics-grid">
              <div className="analytics-card">
                <div className="analytics-card__value">{data.sessions.total}</div>
                <div className="analytics-card__label">Total Events</div>
              </div>
              <div className="analytics-card">
                <div className="analytics-card__value">{data.sessions.live}</div>
                <div className="analytics-card__label">Live Now</div>
              </div>
              <div className="analytics-card">
                <div className="analytics-card__value">{data.sessions.completed}</div>
                <div className="analytics-card__label">Completed</div>
              </div>
              <div className="analytics-card">
                <div className="analytics-card__value">{data.engagement.total_entries}</div>
                <div className="analytics-card__label">Film Entries</div>
              </div>
              <div className="analytics-card">
                <div className="analytics-card__value">{data.engagement.unique_voters}</div>
                <div className="analytics-card__label">Unique Voters</div>
              </div>
              <div className="analytics-card">
                <div className="analytics-card__value">{data.engagement.total_ballots}</div>
                <div className="analytics-card__label">Ballots Cast</div>
              </div>
              <div className="analytics-card">
                <div className="analytics-card__value">{data.engagement.total_ratings}</div>
                <div className="analytics-card__label">Ratings</div>
              </div>
              <div className="analytics-card">
                <div className="analytics-card__value">
                  {data.engagement.avg_rating !== null ? data.engagement.avg_rating.toFixed(1) : "--"}
                </div>
                <div className="analytics-card__label">Avg Rating</div>
              </div>
              <div className="analytics-card">
                <div className="analytics-card__value">{data.engagement.total_match_votes}</div>
                <div className="analytics-card__label">Match Votes</div>
              </div>
              <div className="analytics-card">
                <div className="analytics-card__value">{data.chat.total_messages}</div>
                <div className="analytics-card__label">Chat Messages</div>
              </div>
              <div className="analytics-card">
                <div className="analytics-card__value">{data.schedule.total_items}</div>
                <div className="analytics-card__label">Schedule Items</div>
              </div>
            </div>

            {data.recent_sessions.length > 0 && (
              <div className="analytics-sessions">
                <h3>Recent Events</h3>
                <table className="analytics-sessions__table">
                  <thead>
                    <tr>
                      <th>Title</th>
                      <th>Date</th>
                      <th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.recent_sessions.map((s) => (
                      <tr key={s.id}>
                        <td>{s.title}</td>
                        <td>{formatDate(s.starts_at)}</td>
                        <td>
                          <span className={`analytics-status ${statusClass(s.status)}`}>
                            {s.status}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
};

export default AnalyticsModal;
