import React, { useMemo, useState, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import io from "@cinezoo/shared/realtime";
import "./Menu.scss";
import RewindIcon from "../../assets/rewind_icon.svg";
import { SOCKET_URL } from "../../config";
import { useChatStore } from "../../store/useChatStore";
import { useAuth } from "../../store/AuthContext";
import TournamentBracket from "./TournamentBracket";
import AboutWidget from "./AboutWidget";
import NowPlayingWidget from "./NowPlayingWidget";
import ContributionsWidget from "./ContributionsWidget";
import PluginSlot from "../../plugins/PluginSlot";
import PluginsPanel from "../../plugins/PluginsPanel/PluginsPanel";
import { usePluginRuntime } from "../../plugins/usePluginStore";

/* === VIEWER COUNT FORMATTING === */
// <100: exact number (single digits e.g. 1, 23, 99)
// 100–999: rounded to nearest 50 (e.g. 150, 200, 950)
// 1000+: rounded to nearest 100 shown as k (e.g. 1.1k, 3.4k, 10.3k)
function formatViewers(n: number): string {
  if (n < 100) return String(n);
  if (n < 1000) return String(Math.round(n / 50) * 50);
  const rounded = Math.round(n / 100) * 100;
  const k = rounded / 1000;
  return `${k % 1 === 0 ? k.toFixed(0) : k.toFixed(1)}k`;
}

type TrendingChannel = {
  slug: string;
  name: string;
  channelNumber: number | null;
  viewers: number;
};

type OGChannel = {
  slug: string;
  name: string;
  created_at: string;
};

/* === PROPS === */
interface UtilitiesProps {
  isOpen: boolean;
  setIsOpen: React.Dispatch<React.SetStateAction<boolean>>;
  isMobile?: boolean;
  mobileInline?: boolean;
}

/* === TYPES === */
type ModalKind = null | "ballot" | "battle" | "bracket" | "leaderboard" | "about" | "now_playing" | "contributions" | "plugins";

type Film = {
  id: string;
  title: string;
  creator?: string;
  thumbnail?: string;
  duration?: string;
  synopsis?: string;
};

type BallotSubmit = {
  filmId: string;
  score: number; // 1..10
  tags: string[];
  comment?: string;
};

/* === REUSABLE MODAL (unchanged) === */
const Modal: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  title?: string;
  children: React.ReactNode;
  width?: number;
}> = ({ isOpen, onClose, title, children, width = 560 }) => {
  const onKey = useCallback((e: KeyboardEvent) => {
    if (e.key === "Escape") onClose();
  }, [onClose]);

  useEffect(() => {
    if (!isOpen) return;
    document.addEventListener("keydown", onKey);
    const original = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = original;
    };
  }, [isOpen, onKey]);

  if (!isOpen) return null;

  return (
    <div className="modal-backdrop" onClick={onClose} role="dialog" aria-modal="true" aria-label={title || "Dialog"}>
      <div className="modal-card" style={{ maxWidth: width }} onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h4>{title}</h4>
          <button className="modal-close" onClick={onClose} aria-label="Close dialog">×</button>
        </div>
        <div className="modal-body">{children}</div>
      </div>
    </div>
  );
};

/* === BALLOT WIDGET (single view only) === */
const TAGS = ["Cinematography", "Story", "Originality", "Sound", "Editing"];

const StarRow: React.FC<{ value: number; onChange: (v: number) => void }> = ({ value, onChange }) => {
  return (
    <div className="star-row" role="radiogroup" aria-label="Star rating 1 to 10">
      {Array.from({ length: 10 }, (_, i) => i + 1).map((n) => {
        const filled = n <= value;
        return (
          <button
            key={n}
            className={`star ${filled ? "filled" : ""}`}
            role="radio"
            aria-checked={n === value}
            onClick={() => onChange(n)}
            onKeyDown={(e) => {
              if (e.key === "ArrowRight" || e.key === "ArrowUp") onChange(Math.min(10, value + 1));
              if (e.key === "ArrowLeft" || e.key === "ArrowDown") onChange(Math.max(1, value - 1));
            }}
            title={`${n} / 10`}
          >
            ★
          </button>
        );
      })}
      <span className="score-badge">{value}</span>
    </div>
  );
};

const VotingBallot: React.FC<{
  film: Film | null;
  onSubmit: (payload: BallotSubmit) => Promise<void> | void;
  onSeeAll: () => void;
}> = ({ film, onSubmit, onSeeAll }) => {
  const [score, setScore] = useState<number>(8);
  const [useStars, setUseStars] = useState<boolean>(true);
  const [tags, setTags] = useState<string[]>([]);
  const [comment, setComment] = useState<string>("");

  // reset when film changes
  useEffect(() => {
    setScore(8);
    setUseStars(true);
    setTags([]);
    setComment("");
  }, [film?.id]);

  const toggleTag = (t: string) =>
    setTags((prev) => (prev.includes(t) ? prev.filter((x) => x !== t) : [...prev, t]));

  const submit = async () => {
    if (!film) return;
    await onSubmit({
      filmId: film.id,
      score,
      tags,
      comment: comment.trim() || undefined,
    });
  };

  if (!film) return <p>No films available for this channel yet.</p>;

  return (
    <div className="ballot-card">
      <div className="ballot-header">
        {film.thumbnail && <img className="ballot-thumb" src={film.thumbnail} alt="" />}
        <div className="ballot-meta">
          <h4 className="ballot-title">{film.title}</h4>
          <p className="ballot-byline">
            {film.creator ? `by ${film.creator}` : null} {film.duration ? `• ${film.duration}` : null}
          </p>
          {film.synopsis && <p className="ballot-synopsis">{film.synopsis}</p>}
        </div>
      </div>

      <div className="ballot-controls">
        <div className="ballot-score">
          <div className="ballot-score__top">
            <span className="label">Score</span>
            <button
              className="linklike"
              onClick={() => setUseStars((v) => !v)}
              aria-label="Toggle score input type"
              title="Toggle between stars and slider"
            >
              {useStars ? "Use slider" : "Use stars"}
            </button>
          </div>

          {useStars ? (
            <StarRow value={score} onChange={setScore} />
          ) : (
            <div className="slider-row">
              <input
                type="range"
                min={1}
                max={10}
                step={1}
                value={score}
                onChange={(e) => setScore(parseInt(e.target.value, 10))}
                onKeyDown={(e) => {
                  if (e.key === "ArrowUp" || e.key === "ArrowRight") setScore((s) => Math.min(10, s + 1));
                  if (e.key === "ArrowDown" || e.key === "ArrowLeft") setScore((s) => Math.max(1, s - 1));
                  if (e.key === "Enter") submit();
                }}
                aria-label="Score slider"
              />
              <span className="score-badge">{score}</span>
            </div>
          )}
        </div>

        <div className="ballot-tags">
          <span className="label">What stood out?</span>
          <div className="tag-row">
            {TAGS.map((t) => (
              <button
                key={t}
                onClick={() => toggleTag(t)}
                className={`tag-chip ${tags.includes(t) ? "selected" : ""}`}
                aria-pressed={tags.includes(t)}
              >
                {t}
              </button>
            ))}
          </div>
        </div>

        <label className="ballot-notes">
          <span className="label">Notes (optional)</span>
          <textarea
            value={comment}
            onChange={(e) => setComment(e.target.value)}
            placeholder="Leave a brief note for the filmmaker."
            rows={4}
          />
        </label>
      </div>

      <div className="ballot-actions">
        <button className="btn-secondary" onClick={onSeeAll}>
          See all films
        </button>

        <button className="btn-primary" onClick={submit}>
          Submit Vote
        </button>
      </div>

    </div>
  );
};

const FilmGrid: React.FC<{
  films: Film[];
  selectedIndex: number;
  onPick: (index: number) => void;
}> = ({ films, selectedIndex, onPick }) => {
  return (
    <div className="film-grid" role="list">
      {films.map((f, i) => (
        <button
          key={f.id}
          role="listitem"
          className={`film-card ${i === selectedIndex ? "selected" : ""}`}
          onClick={() => onPick(i)}
          title={`Select ${f.title}`}
        >
          <div className="film-thumb" aria-hidden>
            {f.thumbnail ? <img src={f.thumbnail} alt="" /> : <div className="thumb-fallback">{f.title.charAt(0)}</div>}
          </div>
          <div className="film-info">
            <div className="film-title">{f.title}</div>
            <div className="film-meta">
              {f.creator ? `by ${f.creator}` : ""} {f.duration ? `• ${f.duration}` : ""}
            </div>
          </div>
        </button>
      ))}
    </div>
  );
};

const Utilities: React.FC<UtilitiesProps> = ({ isOpen, setIsOpen, isMobile = false, mobileInline = false }) => {
  const [activeModal, setActiveModal] = useState<ModalKind>(null);
  const toggleMenu = () => setIsOpen(!isOpen);
  const navigate = useNavigate();

  // get current channel from store (VideoPlayer sets it)
  const { channelId } = useChatStore(); // assumes store has { channelId }

  // Trending channels via socket viewer counts
  const [trending, setTrending] = useState<TrendingChannel[]>([]);

  // OG Channels – top 5 longest-running channels by creation date
  const [ogChannels, setOgChannels] = useState<OGChannel[]>([]);

  // Saved Channels
  const { token, isAuthenticated } = useAuth();
  const [savedChannels, setSavedChannels] = useState<{ slug: string; name: string }[]>([]);
  const [savingChannel, setSavingChannel] = useState(false);

  // Plugins: the channel's config, the viewer's overrides, uploaded code
  usePluginRuntime(token, channelId || null);

  const isCurrentChannelSaved = savedChannels.some((ch) => ch.slug === channelId);

  // Fetch saved channels
  useEffect(() => {
    if (!isAuthenticated || !token) { setSavedChannels([]); return; }
    (async () => {
      try {
        const res = await fetch("/api/saved-channels", {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (res.ok) setSavedChannels(await res.json());
      } catch { /* ignore */ }
    })();
  }, [isAuthenticated, token]);

  const toggleSaveChannel = async () => {
    if (!isAuthenticated || !token || !channelId || savingChannel) return;
    setSavingChannel(true);
    try {
      if (isCurrentChannelSaved) {
        const res = await fetch(`/api/saved-channels/${encodeURIComponent(channelId)}`, {
          method: "DELETE",
          headers: { Authorization: `Bearer ${token}` },
        });
        if (res.ok) setSavedChannels((prev) => prev.filter((ch) => ch.slug !== channelId));
      } else {
        if (savedChannels.length >= 5) { setSavingChannel(false); return; }
        const res = await fetch(`/api/saved-channels/${encodeURIComponent(channelId)}`, {
          method: "POST",
          headers: { Authorization: `Bearer ${token}` },
        });
        if (res.ok) {
          // Re-fetch to get correct name from server
          const listRes = await fetch("/api/saved-channels", {
            headers: { Authorization: `Bearer ${token}` },
          });
          if (listRes.ok) setSavedChannels(await listRes.json());
        }
      }
    } catch { /* ignore */ }
    setSavingChannel(false);
  };

  useEffect(() => {
    (async () => {
      try {
        const res = await fetch("/api/channels");
        if (!res.ok) return;
        const data = await res.json();
        const sorted = [...data]
          .sort((a: any, b: any) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime())
          .slice(0, 5)
          .map((ch: any) => ({
            slug: ch.slug,
            name: ch.display_name || ch.name || ch.slug,
            created_at: ch.created_at,
          }));
        setOgChannels(sorted);
      } catch {
        // silently ignore
      }
    })();
  }, []);

  useEffect(() => {
    const sock = io(SOCKET_URL, {
      withCredentials: true,
      transports: ["websocket"],
    });

    sock.on("viewerCounts", (data: TrendingChannel[]) => {
      setTrending(data);
    });

    return () => {
      sock.disconnect();
    };
  }, []);
  const [films, setFilms] = useState<Film[]>([]);
  const [idx, setIdx] = useState(0);
  const [, setEventType] = useState<string | null>(null);
  const [channelWidgets, setChannelWidgets] = useState<Array<{type: string, order: number}>>([]);
  const [, setChannelData] = useState<any>(null);

  useEffect(() => {
    if (activeModal === "ballot") setView("grid");
  }, [activeModal]);

  // Helper function for legacy channels
  const deriveWidgetsFromEventType = (eventType: string): Array<{type: string, order: number}> => {
    switch (eventType?.toLowerCase()) {
      case 'film festival':
      case 'film_festival':
        return [
          { type: 'voting_ballot', order: 0 },
          { type: 'leaderboard', order: 1 }
        ];
      case 'battle royal':
      case 'battle_royal':
      case 'battle royale':
      case 'battle_royale':
        return [{ type: 'battle_royale', order: 0 }];
      case 'tournament':
        return [{ type: 'tournament_bracket', order: 0 }];
      default:
        return [];
    }
  };

  // fetch channel metadata including widgets
  useEffect(() => {
    let on = true;
    (async () => {
      if (!channelId) {
        setEventType(null);
        setChannelWidgets([]);
        setChannelData(null);
        return;
      }
      try {
        const res = await fetch(`/api/channels/${encodeURIComponent(channelId)}`);
        if (!res.ok) throw new Error("Failed to load channel");
        const data = await res.json();
        if (on) {
          setChannelData(data);

          // Use widgets if available, otherwise fallback to event_type (legacy)
          if (data.widgets && data.widgets.length > 0) {
            setChannelWidgets(data.widgets.sort((a: any, b: any) => a.order - b.order));
          } else if (data.latestSession?.event_type) {
            // Legacy fallback
            setChannelWidgets(deriveWidgetsFromEventType(data.latestSession.event_type));
          } else {
            setChannelWidgets([]);
          }

          setEventType(data.latestSession?.event_type || null);
        }
      } catch (e) {
        console.error(e);
        if (on) {
          setEventType(null);
          setChannelWidgets([]);
          setChannelData(null);
        }
      }
    })();
    return () => {
      on = false;
    };
  }, [channelId]);

  // fetch films whenever channel changes
  useEffect(() => {
    let on = true; (async () => {
      if (!channelId) { setFilms([]); return; }
      try {
        const res = await fetch(`/api/channels/${encodeURIComponent(channelId)}/films`);
        if (!res.ok) throw new Error("Failed to load films");
        const data = await res.json();
        if (on) {
          // normalize keys to Film
          const mapped: Film[] = (data || []).map((f: any) => ({
            id: String(f.id),
            title: f.title,
            creator: f.creator ?? undefined,
            thumbnail: f.thumbnail ?? undefined,
            duration: f.duration ?? undefined,
            synopsis: f.synopsis ?? undefined,
          }));
          setFilms(mapped);
          setIdx(0);
        }
      } catch (e) {
        console.error(e);
        if (on) { setFilms([]); setIdx(0); }
      }
    })();
    return () => { on = false; };
  }, [channelId]);

  const currentFilm: Film | null = films.length ? films[idx % films.length] : null;
  const [view, setView] = useState<"single" | "grid">("single");

  // Define widget type map
  const WIDGET_MAP: Record<string, {key: ModalKind, name: string, description: string}> = {
    voting_ballot: {
      key: "ballot",
      name: "Voting Ballot",
      description: "Rate and support your favorite entries."
    },
    leaderboard: {
      key: "leaderboard",
      name: "Leaderboard",
      description: "Top-ranked filmmakers."
    },
    battle_royale: {
      key: "battle",
      name: "Battle Royale",
      description: "Films go head-to-head. You decide the winner."
    },
    tournament_bracket: {
      key: "bracket",
      name: "Tournament Bracket",
      description: "See who's advancing in the competition."
    },
    about: {
      key: "about",
      name: "About",
      description: "Learn about this channel."
    },
    now_playing: {
      key: "now_playing",
      name: "Now Playing",
      description: "See what's on right now."
    },
    contributions: {
      key: "contributions",
      name: "Contributions",
      description: "Pitch a film to this channel's schedule."
    }
  };

  // Render widgets based on channel config
  const utilities = useMemo(() => {
    return channelWidgets
      .map(w => WIDGET_MAP[w.type])
      .filter(Boolean);
  }, [channelWidgets]);

  const submitVote = async (payload: BallotSubmit) => {
    if (!channelId) return;
    // ratings path (battle mode can use a different endpoint later)
    try {
      await fetch("/api/ratings", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          channel: channelId,         // slug or key
          film_id: payload.filmId,    // PK from films
          score: payload.score,       // 1..10
          tags: payload.tags,         // string[]
          comment: payload.comment,   // string | undefined
        }),
      });
    } catch (e) {
      console.error("vote failed", e);
    }
  };

  return (
    <>
      {/* === SIDEBAR === */}
      {/* Toggle button — hidden in mobile portrait inline mode */}
      {!mobileInline && (
        <button className={`toggle-button-left ${isOpen ? "open" : ""}`} onClick={toggleMenu}>
          <img src={RewindIcon} alt="Toggle" />
        </button>
      )}

      <div className={`utilities-container ${isOpen ? "open" : ""} ${isMobile ? "mobile" : ""} ${mobileInline ? "mobile-inline" : ""}`}>
        {/* Themes → Sidebar background (the lava lamp by default) */}
        <PluginSlot slot="sidebar.background" active={isOpen} />

        <div className={`utilities-menu ${isOpen ? "open" : ""}`}>
          {/* Mobile close button — only in sidebar mode, not inline */}
          {isMobile && !mobileInline && (
            <button className="mobile-close-button" onClick={() => setIsOpen(false)} aria-label="Close menu">
              ×
            </button>
          )}
          <h3>The Pit</h3>
          <button className="plugins-button" onClick={() => setActiveModal("plugins")}>
            <span aria-hidden="true">🧩</span> Plugins
          </button>
          <ul>
            {utilities.map((u) => (
              <li
                key={u.key}
                onClick={() => setActiveModal(u.key)}
                role="button"
                tabIndex={0}
                onKeyDown={(e) => (e.key === "Enter" || e.key === " ") && setActiveModal(u.key)}
              >
                <strong>{u.name}</strong>
                <p>{u.description}</p>
              </li>
            ))}
          </ul>

          {/* Plugins added by the channel or the viewer */}
          <PluginSlot slot="sidebar.section" active={isOpen} />

          {/* Trending Channels */}
          {trending.length > 0 && (
            <div className="trending-channels">
              <h4>Trending</h4>
              <ul>
                {trending.map((ch, i) => (
                  <li
                    key={ch.slug}
                    className={ch.slug === channelId ? "active" : ""}
                    onClick={() => navigate(`/channel/${ch.slug}`)}
                    role="button"
                    tabIndex={0}
                    onKeyDown={(e) => (e.key === "Enter" || e.key === " ") && navigate(`/channel/${ch.slug}`)}
                  >
                    <span className="trending-rank">{i + 1}</span>
                    <span className="trending-name">{ch.name}</span>
                    <span className="trending-viewers">{formatViewers(ch.viewers)} watching</span>
                  </li>
                ))}
              </ul>
            </div>
          )}

          {/* OG Channels – longest running */}
          {ogChannels.length > 0 && (
            <div className="trending-channels og-channels">
              <h4>OG Channels</h4>
              <ul>
                {ogChannels.map((ch, i) => (
                  <li
                    key={ch.slug}
                    className={ch.slug === channelId ? "active" : ""}
                    onClick={() => navigate(`/channel/${ch.slug}`)}
                    role="button"
                    tabIndex={0}
                    onKeyDown={(e) => (e.key === "Enter" || e.key === " ") && navigate(`/channel/${ch.slug}`)}
                  >
                    <span className="trending-rank">{i + 1}</span>
                    <span className="trending-name">{ch.name}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}

          {/* Saved Channels */}
          {isAuthenticated && (
            <div className="trending-channels saved-channels">
              <h4>
                Saved Channels
                <button
                  className={`save-star-btn ${isCurrentChannelSaved ? "saved" : ""}`}
                  onClick={toggleSaveChannel}
                  disabled={savingChannel || !channelId || (!isCurrentChannelSaved && savedChannels.length >= 5)}
                  title={
                    !channelId
                      ? "Navigate to a channel first"
                      : isCurrentChannelSaved
                      ? "Unsave this channel"
                      : savedChannels.length >= 5
                      ? "Max 5 saved channels"
                      : "Save this channel"
                  }
                  aria-label={isCurrentChannelSaved ? "Unsave channel" : "Save channel"}
                >
                  ★
                </button>
              </h4>
              {savedChannels.length > 0 ? (
                <ul>
                  {savedChannels.map((ch, i) => (
                    <li
                      key={ch.slug}
                      className={ch.slug === channelId ? "active" : ""}
                      onClick={() => navigate(`/channel/${ch.slug}`)}
                      role="button"
                      tabIndex={0}
                      onKeyDown={(e) => (e.key === "Enter" || e.key === " ") && navigate(`/channel/${ch.slug}`)}
                    >
                      <span className="trending-rank">{i + 1}</span>
                      <span className="trending-name">{ch.name}</span>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="saved-empty">No saved channels yet.</p>
              )}
            </div>
          )}

          {/* Optional quick nav between films when ballot open */}
          {activeModal === "ballot" && films.length > 1 && (
            <div className="film-stepper">
              <button onClick={() => setIdx((i) => (i - 1 + films.length) % films.length)}>Prev Film</button>
              <span>{films.length ? `${(idx % films.length) + 1} / ${films.length}` : "0 / 0"}</span>
              <button onClick={() => setIdx((i) => (i + 1) % films.length)}>Next Film</button>
            </div>
          )}
        </div>
      </div>

      {/* === MODALS === */}

      {/* Tournament Bracket Modal */}
      <Modal
        isOpen={activeModal === "bracket"}
        onClose={() => setActiveModal(null)}
        title="🏆 Tournament Bracket"
        width={1400}
      >
        <TournamentBracket
          channelId={channelId}
        />
      </Modal>

      {/* Voting Ballot Modal */}
      <Modal
        isOpen={activeModal === "ballot"}
        onClose={() => setActiveModal(null)}
        title={channelId ? `Voting Ballot • ${channelId}` : "Voting Ballot"}
        width={880}
      >
        <div className="ballot-wrap">
          {/* Topbar */}
          <div className="ballot-topbar">
            {view === "single" && films.length > 1 && (
              <div className="film-stepper">
                <button
                  className="btn-ghost"
                  onClick={() => setIdx((i) => (i - 1 + films.length) % films.length)}
                >
                  ◀ Prev
                </button>
                <span className="step-indicator">
                  {films.length ? `${(idx % films.length) + 1} / ${films.length}` : "0 / 0"}
                </span>
                <button
                  className="btn-ghost"
                  onClick={() => setIdx((i) => (i + 1) % films.length)}
                >
                  Next ▶
                </button>
              </div>
            )}
          </div>

          {/* Body */}
          {view === "grid" ? (
            <FilmGrid
              films={films}
              selectedIndex={idx}
              onPick={(i) => {
                setIdx(i);
                setView("single");
              }}
            />
          ) : (
            <VotingBallot
              film={currentFilm}
              onSubmit={async (payload) => {
                await submitVote(payload);
                setIdx((i) => (i + 1) % Math.max(1, films.length));
              }}
              onSeeAll={() => setView("grid")}
            />
          )}
        </div>
      </Modal>

      {/* About Widget Modal */}
      <Modal
        isOpen={activeModal === "about"}
        onClose={() => setActiveModal(null)}
        title="ℹ️ About This Channel"
        width={680}
      >
        <AboutWidget channelId={channelId || ""} />
      </Modal>

      {/* Now Playing Widget Modal */}
      <Modal
        isOpen={activeModal === "now_playing"}
        onClose={() => setActiveModal(null)}
        title="📺 Now Playing / Up Next"
        width={780}
      >
        <NowPlayingWidget channelId={channelId || ""} />
      </Modal>

      {/* Plugins */}
      <Modal
        isOpen={activeModal === "plugins"}
        onClose={() => setActiveModal(null)}
        title="🧩 Plugins"
        width={880}
      >
        <PluginsPanel />
      </Modal>

      {/* Contributions Widget Modal */}
      <Modal
        isOpen={activeModal === "contributions"}
        onClose={() => setActiveModal(null)}
        title="🤝 Contributions"
        width={720}
      >
        <ContributionsWidget channelId={channelId || ""} />
      </Modal>

    </>
  );
};

export default Utilities;
