import React, { useEffect, useRef, useState } from "react";
import TournamentSeeding, { TournamentBracket } from "../CreateChannelModal/TournamentSeeding";
import "./EventModal.scss";

interface Props {
  isOpen: boolean;
  onClose: () => void;
  channel: {
    id: string;
    name: string;
    display_name?: string;
    channel_number?: number;
    slug?: string;
  } | null;
  onEventCreated?: (event: any) => void;
}

type EventType = "film_festival" | "battle_royal" | "tournament";

type NewFilm = {
  title: string;
  creator?: string;
  duration?: string;
  thumbnail?: string;
};

const emptyFilm: NewFilm = { title: "", creator: "", duration: "", thumbnail: "" };

// Event type configurations with auto-applied widgets
const EVENT_CONFIGS: Record<EventType, { label: string; description: string; widgets: string[] }> = {
  film_festival: {
    label: "Film Festival",
    description: "Viewers rate films 1-10. Best for showcasing multiple entries.",
    widgets: ["voting_ballot", "leaderboard"],
  },
  battle_royal: {
    label: "Battle Royale",
    description: "Head-to-head matchups. Viewers pick winners in each pairing.",
    widgets: ["battle_royale"],
  },
  tournament: {
    label: "Tournament",
    description: "Bracket-style elimination. Films compete until one winner remains.",
    widgets: ["tournament_bracket"],
  },
};

const EventModal: React.FC<Props> = ({ isOpen, onClose, channel, onEventCreated }) => {
  const boxRef = useRef<HTMLDivElement>(null);

  // Event fields
  const [eventType, setEventType] = useState<EventType>("film_festival");
  const [eventTitle, setEventTitle] = useState("");
  const [startsAt, setStartsAt] = useState<string>("");
  const [endsAt, setEndsAt] = useState<string>("");
  const [submitting, setSubmitting] = useState(false);
  const [success, setSuccess] = useState(false);

  // Films
  const [films, setFilms] = useState<NewFilm[]>([{ ...emptyFilm }]);

  // Tournament bracket
  const [tournamentBracket, setTournamentBracket] = useState<TournamentBracket | null>(null);

  // Reset form when modal opens
  useEffect(() => {
    if (isOpen) {
      setEventType("film_festival");
      setEventTitle("");
      setStartsAt("");
      setEndsAt("");
      setFilms([{ ...emptyFilm }]);
      setTournamentBracket(null);
      setSuccess(false);
    }
  }, [isOpen]);

  // Close on outside click
  useEffect(() => {
    if (!isOpen) return;
    const handleClickOutside = (event: MouseEvent) => {
      if (boxRef.current && !boxRef.current.contains(event.target as Node)) {
        onClose();
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, [isOpen, onClose]);

  // ESC key and scroll lock
  useEffect(() => {
    if (!isOpen) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    document.addEventListener("keydown", onKey);
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = prevOverflow;
    };
  }, [isOpen, onClose]);

  const canSubmit = () => {
    if (!eventTitle.trim()) return false;
    if (!startsAt || !endsAt) return false;
    if (new Date(startsAt) >= new Date(endsAt)) return false;
    const validFilms = films.filter(f => f.title.trim().length > 0);
    if (validFilms.length === 0) return false;
    if (eventType === "tournament" && !tournamentBracket) return false;
    return true;
  };

  const addFilmRow = () => setFilms(prev => [...prev, { ...emptyFilm }]);
  const removeFilmRow = (idx: number) => setFilms(prev => prev.filter((_, i) => i !== idx));
  const updateFilm = (idx: number, patch: Partial<NewFilm>) =>
    setFilms(prev => prev.map((f, i) => (i === idx ? { ...f, ...patch } : f)));

  const normalizeFilms = (): NewFilm[] => {
    return films
      .map(f => ({
        title: f.title.trim(),
        creator: f.creator?.trim() || undefined,
        duration: f.duration?.trim() || undefined,
        thumbnail: f.thumbnail?.trim() || undefined,
      }))
      .filter(f => f.title.length > 0);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!canSubmit() || !channel) return;

    setSubmitting(true);
    try {
      // Get the widgets for this event type
      const eventWidgets = EVENT_CONFIGS[eventType].widgets.map((type, idx) => ({
        type,
        order: idx,
      }));

      const body = {
        event: {
          kind: eventType,
          title: eventTitle,
          starts_at: new Date(startsAt).toISOString(),
          ends_at: new Date(endsAt).toISOString(),
          tournament_bracket: eventType === "tournament" ? tournamentBracket : null,
        },
        films: normalizeFilms(),
        widgets: eventWidgets,
      };

      const token = localStorage.getItem("token");
      const res = await fetch(`/api/channels/${channel.id}/events`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${token}`,
        },
        credentials: "include",
        body: JSON.stringify(body),
      });

      if (!res.ok) {
        const msg = await res.text();
        throw new Error(`Failed to create event: ${res.status} ${msg}`);
      }

      const data = await res.json();
      setSuccess(true);

      if (onEventCreated) {
        onEventCreated(data);
      }

      // Close after short delay
      setTimeout(() => onClose(), 1500);
    } catch (err) {
      console.error("Error creating event:", err);
      alert("Failed to create event. Please try again.");
    } finally {
      setSubmitting(false);
    }
  };

  if (!isOpen || !channel) return null;

  const config = EVENT_CONFIGS[eventType];

  return (
    <div className="event-modal-overlay" role="dialog" aria-modal="true">
      <div className="event-modal-content" ref={boxRef}>
        <button className="close-btn" onClick={onClose} aria-label="Close">X</button>

        <h2>Add Event to Channel {channel.channel_number}</h2>
        <p className="channel-name">{channel.display_name || channel.name}</p>

        {success ? (
          <div className="success-message">
            <span className="success-icon">✓</span>
            <p>Event created successfully!</p>
          </div>
        ) : (
          <form className="event-form" onSubmit={handleSubmit}>
            {/* Event Type Selection */}
            <div className="event-type-selector">
              <label>Event Type</label>
              <div className="event-type-grid">
                {(Object.keys(EVENT_CONFIGS) as EventType[]).map((type) => (
                  <label
                    key={type}
                    className={`event-type-option ${eventType === type ? 'selected' : ''}`}
                  >
                    <input
                      type="radio"
                      name="eventType"
                      value={type}
                      checked={eventType === type}
                      onChange={() => {
                        setEventType(type);
                        setTournamentBracket(null);
                      }}
                    />
                    <div className="event-type-card">
                      <strong>{EVENT_CONFIGS[type].label}</strong>
                      <p>{EVENT_CONFIGS[type].description}</p>
                    </div>
                  </label>
                ))}
              </div>
            </div>

            {/* Auto-applied widgets info */}
            <div className="auto-widgets-info">
              <span className="label">Auto-applied widgets:</span>
              <span className="widget-list">
                {config.widgets.map(w => w.replace('_', ' ')).join(', ')}
              </span>
            </div>

            {/* Event Name */}
            <div className="row">
              <label htmlFor="event-name">Event Name</label>
              <input
                id="event-name"
                type="text"
                placeholder="e.g., Summer Shorts Festival 2025"
                value={eventTitle}
                onChange={(e) => setEventTitle(e.target.value)}
                required
              />
            </div>

            {/* Date Range */}
            <div className="row cols-2">
              <div>
                <label htmlFor="starts-at">Starts</label>
                <input
                  id="starts-at"
                  type="datetime-local"
                  value={startsAt}
                  onChange={(e) => setStartsAt(e.target.value)}
                  required
                />
              </div>
              <div>
                <label htmlFor="ends-at">Ends</label>
                <input
                  id="ends-at"
                  type="datetime-local"
                  value={endsAt}
                  onChange={(e) => setEndsAt(e.target.value)}
                  required
                />
              </div>
            </div>

            {/* Films */}
            <div className="films-section">
              <div className="films-header">
                <h4>Films / Entries</h4>
                <button type="button" className="btn-secondary small" onClick={addFilmRow}>
                  + Add Film
                </button>
              </div>

              <div className="films-table">
                {films.map((f, idx) => (
                  <div key={idx} className="film-row">
                    <input
                      type="text"
                      placeholder="Title *"
                      value={f.title}
                      onChange={(e) => updateFilm(idx, { title: e.target.value })}
                      required
                    />
                    <input
                      type="text"
                      placeholder="Creator"
                      value={f.creator || ""}
                      onChange={(e) => updateFilm(idx, { creator: e.target.value })}
                    />
                    <input
                      type="text"
                      placeholder="Duration (MM:SS)"
                      value={f.duration || ""}
                      onChange={(e) => updateFilm(idx, { duration: e.target.value })}
                    />
                    <input
                      type="url"
                      placeholder="Thumbnail URL"
                      value={f.thumbnail || ""}
                      onChange={(e) => updateFilm(idx, { thumbnail: e.target.value })}
                    />
                    <button
                      type="button"
                      className="icon-btn"
                      aria-label="Remove film"
                      onClick={() => removeFilmRow(idx)}
                      disabled={films.length === 1}
                    >
                      ✕
                    </button>
                  </div>
                ))}
              </div>
            </div>

            {/* Tournament Seeding */}
            {eventType === "tournament" && films.filter(f => f.title.trim()).length > 0 && (
              <div className="tournament-section">
                <TournamentSeeding
                  films={films.filter(f => f.title.trim()).map((f, idx) => ({
                    id: `temp-${idx}`,
                    title: f.title,
                    creator: f.creator,
                    thumbnail: f.thumbnail,
                  }))}
                  onSeedingComplete={(bracket) => {
                    console.log("Bracket setup complete:", bracket);
                    setTournamentBracket(bracket);
                  }}
                />
              </div>
            )}

            <button type="submit" className="submit-btn" disabled={submitting || !canSubmit()}>
              {submitting ? "Creating Event..." : "Create Event"}
            </button>
          </form>
        )}
      </div>
    </div>
  );
};

export default EventModal;
