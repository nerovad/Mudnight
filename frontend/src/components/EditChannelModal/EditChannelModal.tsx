// src/components/EditChannelModal/EditChannelModal.tsx
import React, { useEffect, useRef, useState } from "react";
import WidgetSelector from "../WidgetSelector/WidgetSelector";
import type { WidgetConfig } from "../WidgetSelector/WidgetSelector";
import "./EditChannelModal.scss";

interface Props {
  isOpen: boolean;
  onClose: () => void;
  channel: Channel | null;
  onUpdate: (updatedChannel: any) => void;
}

type Channel = {
  id: string;
  name: string;
  display_name?: string;
  channel_number?: number;
  slug?: string;
  description?: string;
  widgets?: WidgetConfig[];
  about_text?: string;
  first_live_at?: string | null;
  stream_key?: string;
  ingest_app?: string;
  playback_path?: string;
  thumbnail?: string | null;
  intermission_url?: string | null;
};

type Session = {
  id: number;
  title: string;
  starts_at: string;
  ends_at: string;
  status: string;
  event_type: string;
  created_at: string;
};

type VotingMode = "ratings" | "battle";
type EventType = "film_festival";

type NewFilm = {
  title: string;
  creator?: string;
  duration?: string;
  thumbnail?: string;
};

type RecurrenceType = 'once' | 'daily' | 'weekly' | 'weekdays' | 'weekends';

type ScheduleItem = {
  id?: number;
  film_id?: number | null;
  title: string;
  scheduled_at: string;
  duration_seconds?: number | null;
  durationInput?: string; // Raw input string for auto-formatting
  status?: string;
  recurrence_type: RecurrenceType;
  recurrence_days?: number[];  // For 'weekly': [0,1,2,3,4,5,6] where 0=Sun
  recurrence_end_date?: string; // Optional end date (YYYY-MM-DD)
  air_time?: string;           // HH:MM for recurring shows
};

const emptyFilm: NewFilm = { title: "", creator: "", duration: "", thumbnail: "" };

const emptyScheduleItem: ScheduleItem = {
  title: "",
  scheduled_at: "",
  duration_seconds: null,
  durationInput: "",
  recurrence_type: "once",
  recurrence_days: [],
  recurrence_end_date: "",
  air_time: "",
};

const DAY_LABELS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

// Convert seconds to timecode (HH:MM:SS)
const secondsToTimecode = (seconds: number | null | undefined): string => {
  if (!seconds) return "";
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  if (h > 0) {
    return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  }
  return `${m}:${s.toString().padStart(2, '0')}`;
};

// Convert timecode (HH:MM:SS or MM:SS) to seconds
const timecodeToSeconds = (timecode: string): number | null => {
  if (!timecode || !timecode.trim()) return null;
  const parts = timecode.split(':').map(p => parseInt(p, 10));
  if (parts.some(isNaN)) return null;

  if (parts.length === 3) {
    return parts[0] * 3600 + parts[1] * 60 + parts[2];
  } else if (parts.length === 2) {
    return parts[0] * 60 + parts[1];
  }
  return null;
};

// Auto-format timecode input: inserts colons as user types digits
// Input: raw digits like "12345" -> Output: "1:23:45"
const formatTimecodeInput = (value: string): string => {
  // Remove all non-digit characters
  const digits = value.replace(/\D/g, '');

  // Limit to 6 digits (HH:MM:SS)
  const limited = digits.slice(0, 6);

  // Insert colons from the right (SS first, then MM, then HH)
  const len = limited.length;
  if (len === 0) return '';
  if (len <= 2) return limited;
  if (len <= 4) {
    // MM:SS format
    return `${limited.slice(0, len - 2)}:${limited.slice(-2)}`;
  }
  // HH:MM:SS format
  return `${limited.slice(0, len - 4)}:${limited.slice(-4, -2)}:${limited.slice(-2)}`;
};

const EditChannelModal: React.FC<Props> = ({ isOpen, onClose, channel, onUpdate }) => {
  const boxRef = useRef<HTMLDivElement>(null);

  // Channel fields
  const [displayName, setDisplayName] = useState("");
  const [submitting, setSubmitting] = useState(false);

  // Stream info (read-only)
  const [streamKey, setStreamKey] = useState("");
  const [ingestApp, setIngestApp] = useState("live");
  const [playbackPath, setPlaybackPath] = useState("");

  // Widgets
  const [selectedWidgets, setSelectedWidgets] = useState<WidgetConfig[]>([]);
  const [channelScheduled, setChannelScheduled] = useState(false);
  const [aboutText, setAboutText] = useState("");

  // Event/festival
  const [addEvent, setAddEvent] = useState(false);
  const [eventType] = useState<EventType>("film_festival");
  const [eventTitle, setEventTitle] = useState("");
  const [startsAt, setStartsAt] = useState<string>("");
  const [endsAt, setEndsAt] = useState<string>("");
  const [votingMode, setVotingMode] = useState<VotingMode>("ratings");
  const [requireLogin, setRequireLogin] = useState<boolean>(true);

  // Films
  const [films, setFilms] = useState<NewFilm[]>([{ ...emptyFilm }]);

  // Historical events
  const [existingSessions, setExistingSessions] = useState<Session[]>([]);

  // Schedule management
  const [scheduleItems, setScheduleItems] = useState<ScheduleItem[]>([]);
  const [channelFilms, setChannelFilms] = useState<any[]>([]);

  // Thumbnail
  const [thumbnailFile, setThumbnailFile] = useState<File | null>(null);
  const [thumbnailPreview, setThumbnailPreview] = useState<string | null>(null);

  // Intermission screen
  const [intermissionFile, setIntermissionFile] = useState<File | null>(null);
  const [intermissionPreview, setIntermissionPreview] = useState<string | null>(null);

  // Load channel data when modal opens
  useEffect(() => {
    if (channel && isOpen) {
      // Fetch full channel data including widgets and sessions
      const fetchChannelData = async () => {
        try {
          // Fetch channel details (includes sessions now)
          const channelRes = await fetch(`/api/channels/${channel.slug || channel.id}`);
          if (channelRes.ok) {
            const channelData = await channelRes.json();
            setDisplayName(channelData.display_name || "");
            setSelectedWidgets(channelData.widgets || []);
            setChannelScheduled(channelData.playout_mode === "scheduled");
            setAboutText(channelData.about_text || "");
            setExistingSessions(channelData.sessions || []);
            setStreamKey(channelData.stream_key || "");
            setIngestApp(channelData.ingest_app || "live");
            setPlaybackPath(channelData.playback_path || "");
            // Load existing thumbnail/intermission previews
            setThumbnailPreview(channelData.thumbnail || null);
            setThumbnailFile(null);
            setIntermissionPreview(channelData.intermission_url || null);
            setIntermissionFile(null);
          }

          // Fetch schedule if Now Playing widget is selected
          const scheduleRes = await fetch(`/api/channels/${channel.slug || channel.id}/schedule`);
          if (scheduleRes.ok) {
            const scheduleData = await scheduleRes.json();
            // Use schedule array which contains all raw items (not expanded)
            const rawItems = scheduleData.schedule || [];
            const allItems = rawItems.map((item: any) => ({
              ...item,
              // Convert ISO string to datetime-local format (YYYY-MM-DDTHH:mm)
              scheduled_at: item.scheduled_at ? new Date(item.scheduled_at).toISOString().slice(0, 16) : "",
              // Initialize durationInput from stored seconds
              durationInput: secondsToTimecode(item.duration_seconds),
              // Ensure recurrence fields have defaults
              recurrence_type: item.recurrence_type || 'once',
              recurrence_days: item.recurrence_days || [],
              recurrence_end_date: item.recurrence_end_date || '',
              air_time: item.air_time || '',
            }));
            setScheduleItems(allItems.length > 0 ? allItems : []);
          } else {
            setScheduleItems([]);
          }

          // Fetch films for this channel
          const filmsRes = await fetch(`/api/channels/${channel.slug || channel.id}/films`);
          if (filmsRes.ok) {
            const filmsData = await filmsRes.json();
            setChannelFilms(filmsData || []);
          }
        } catch (error) {
          console.error("Error fetching channel data:", error);
          // Fall back to the channel prop so the form (and Save) still works
          // when the API is unreachable
          setDisplayName(channel.display_name || "");
          setSelectedWidgets(channel.widgets || []);
          setAboutText(channel.about_text || "");
        }
      };

      fetchChannelData();

      // Reset event fields for adding NEW event
      setAddEvent(false);
      setEventTitle("");
      setStartsAt("");
      setEndsAt("");
      setVotingMode("ratings");
      setRequireLogin(true);
      setFilms([{ ...emptyFilm }]);
    }
  }, [channel, isOpen]);

  // Auto-add one empty schedule row when Now Playing widget is selected and no items exist
  useEffect(() => {
    const hasNowPlayingWidget = selectedWidgets.some(w => w.type === 'now_playing');
    console.log('Now Playing widget check:', { hasNowPlayingWidget, itemCount: scheduleItems.length });

    if (hasNowPlayingWidget && scheduleItems.length === 0 && isOpen) {
      console.log('Auto-adding first schedule row');
      setScheduleItems([{ ...emptyScheduleItem }]);
    }
  }, [selectedWidgets, isOpen]);

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

  // ESC key
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
    if (!displayName.trim()) return false;
    if (!addEvent) return true;
    if (!eventTitle.trim()) return false;
    if (!startsAt || !endsAt) return false;
    if (new Date(startsAt) >= new Date(endsAt)) return false;
    const validFilms = films.filter(f => f.title.trim().length > 0);
    return validFilms.length > 0;
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

  // Schedule item management
  const addScheduleRow = () => {
    console.log('Adding schedule row, current items:', scheduleItems.length);
    const newItem = { ...emptyScheduleItem };
    console.log('New item:', newItem);
    setScheduleItems(prev => {
      const updated = [...prev, newItem];
      console.log('Updated schedule items:', updated);
      return updated;
    });
  };

  const removeScheduleRow = (idx: number) => {
    console.log('Removing schedule row:', idx);
    setScheduleItems(prev => prev.filter((_, i) => i !== idx));
  };

  const updateScheduleItem = (idx: number, patch: Partial<ScheduleItem>) => {
    console.log('Updating schedule item', idx, 'with:', patch);
    setScheduleItems(prev => prev.map((item, i) => (i === idx ? { ...item, ...patch } : item)));
  };

  const saveSchedule = async () => {
    if (!channel) return;

    console.log('=== SAVE SCHEDULE CLICKED ===');
    console.log('Current scheduleItems state:', scheduleItems);
    console.log('Number of items:', scheduleItems.length);

    if (scheduleItems.length === 0) {
      alert("Please add at least one schedule item before saving.");
      return;
    }

    try {
      const token = localStorage.getItem("token");
      const validItems = scheduleItems
        .filter(item => {
          // Valid if has scheduled_at AND either a film_id or a title
          const hasIdentifier = item.film_id || item.title?.trim();
          const isValid = hasIdentifier && item.scheduled_at;
          console.log('Item validation:', { item, isValid });
          return isValid;
        })
        .map(item => {
          // If we have a film_id but no title, get the title from channelFilms
          let title = item.title;
          if (item.film_id && !title?.trim()) {
            const film = channelFilms.find(f => f.id === item.film_id);
            title = film?.title || '';
          }
          return {
            film_id: item.film_id || null,
            title: title,
            scheduled_at: new Date(item.scheduled_at).toISOString(),
            duration_seconds: item.duration_seconds || null,
            recurrence_type: item.recurrence_type || 'once',
            recurrence_days: item.recurrence_type === 'weekly' ? item.recurrence_days : null,
            recurrence_end_date: item.recurrence_end_date || null,
            air_time: item.recurrence_type !== 'once' ? item.air_time : null,
          };
        });

      console.log("Valid items to save:", validItems);

      if (validItems.length === 0) {
        alert("Please fill in title and scheduled time for at least one item.");
        return;
      }

      console.log("Sending to backend:", validItems);

      const res = await fetch(`/api/channels/${channel.slug || channel.id}/schedule`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${token}`
        },
        credentials: "include",
        body: JSON.stringify({ schedule: validItems })
      });

      if (res.ok) {
        const result = await res.json();
        console.log("Schedule saved:", result);
        alert("Schedule saved successfully!");
      } else {
        const errorText = await res.text();
        console.error("Save failed:", res.status, errorText);
        throw new Error(`Failed to save schedule: ${res.status} ${errorText}`);
      }
    } catch (error) {
      console.error("Error saving schedule:", error);
      alert(`Failed to save schedule: ${error}`);
    }
  };

  // Thumbnail handlers
  const handleThumbnailChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setThumbnailFile(file);
      const previewUrl = URL.createObjectURL(file);
      setThumbnailPreview(previewUrl);
    }
  };

  const removeThumbnail = () => {
    if (thumbnailPreview && thumbnailFile) {
      URL.revokeObjectURL(thumbnailPreview);
    }
    setThumbnailFile(null);
    setThumbnailPreview(null);
  };

  // Intermission handlers
  const handleIntermissionChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setIntermissionFile(file);
      const previewUrl = URL.createObjectURL(file);
      setIntermissionPreview(previewUrl);
    }
  };

  const removeIntermission = () => {
    if (intermissionPreview && intermissionFile) {
      URL.revokeObjectURL(intermissionPreview);
    }
    setIntermissionFile(null);
    setIntermissionPreview(null);
  };

  // Cleanup preview URLs on unmount
  useEffect(() => {
    return () => {
      if (thumbnailPreview && thumbnailFile) {
        URL.revokeObjectURL(thumbnailPreview);
      }
      if (intermissionPreview && intermissionFile) {
        URL.revokeObjectURL(intermissionPreview);
      }
    };
  }, [thumbnailPreview, intermissionPreview, thumbnailFile, intermissionFile]);

  // Convert file to base64
  const fileToBase64 = (file: File): Promise<string> => {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.readAsDataURL(file);
      reader.onload = () => resolve(reader.result as string);
      reader.onerror = reject;
    });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!canSubmit() || !channel) return;

    setSubmitting(true);
    try {
      const token = localStorage.getItem("token");

      // Convert thumbnail to base64 if a new file was selected
      let thumbnailBase64: string | null = null;
      if (thumbnailFile) {
        thumbnailBase64 = await fileToBase64(thumbnailFile);
      }

      // Convert intermission to base64 if a new file was selected
      let intermissionBase64: string | null = null;
      if (intermissionFile) {
        intermissionBase64 = await fileToBase64(intermissionFile);
      }

      const body: any = {
        display_name: displayName,
        widgets: selectedWidgets.length > 0 ? selectedWidgets : null,
        about_text: aboutText || null,
        thumbnail: thumbnailBase64,
        intermission: intermissionBase64,
      };

      if (addEvent) {
        body.event = {
          kind: eventType,
          title: eventTitle,
          starts_at: new Date(startsAt).toISOString(),
          ends_at: new Date(endsAt).toISOString(),
          voting_mode: votingMode,
          require_login: requireLogin,
        };
        body.films = normalizeFilms();
      }

      const res = await fetch(`/api/channels/${channel.id}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${token}`
        },
        credentials: "include",
        body: JSON.stringify(body),
      });

      if (!res.ok) {
        const msg = await res.text();
        throw new Error(`Failed to update channel: ${res.status} ${msg}`);
      }

      const data = await res.json();
      onUpdate(data);
      onClose();
    } catch (err) {
      console.error("Error updating channel", err);
      alert("Failed to update channel. Please try again.");
    } finally {
      setSubmitting(false);
    }
  };

  if (!isOpen || !channel) return null;

  return (
    <div className="edit-channel-overlay" role="dialog" aria-modal="true">
      <div className="edit-channel-content" ref={boxRef}>
        <button className="close-btn" onClick={onClose} aria-label="Close">X</button>

        <h2>Edit Channel {channel.channel_number}</h2>

        {streamKey && (
          <div className="stream-info">
            <h3>Stream Configuration</h3>
            <p><strong>Stream Key:</strong> {streamKey}</p>
            <p><strong>Ingest URL for OBS:</strong> rtmp://cinezoo.tv/{ingestApp}/{streamKey}</p>
            <p><strong>Playback URL (HLS):</strong> {playbackPath}</p>
            <div className="stream-info-actions">
              <button type="button" onClick={() => navigator.clipboard.writeText(streamKey)}>
                Copy Stream Key
              </button>
              <button type="button" onClick={() => navigator.clipboard.writeText(`rtmp://cinezoo.tv/${ingestApp}/${streamKey}`)}>
                Copy Ingest URL
              </button>
              <button type="button" onClick={() => navigator.clipboard.writeText(playbackPath)}>
                Copy Playback URL
              </button>
            </div>
          </div>
        )}

        <form className="edit-channel-form" onSubmit={handleSubmit}>
          <div className="row">
            <label htmlFor="display-name">Channel Display Name</label>
            <input
              id="display-name"
              type="text"
              placeholder="e.g., Cinema, Horror Marathon..."
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value.slice(0, 20))}
              maxLength={20}
              required
            />
            <small className="form-hint">{displayName.length}/20 characters</small>
          </div>

          {/* Thumbnail Upload */}
          <div className="row">
            <label htmlFor="edit-thumbnail-upload">Channel Thumbnail</label>
            {thumbnailPreview ? (
              <div className="thumbnail-preview">
                <img src={thumbnailPreview} alt="Thumbnail preview" />
                <button
                  type="button"
                  className="thumbnail-remove"
                  onClick={removeThumbnail}
                  aria-label="Remove thumbnail"
                >
                  ×
                </button>
              </div>
            ) : (
              <div className="thumbnail-upload-area">
                <input
                  id="edit-thumbnail-upload"
                  type="file"
                  accept="image/*"
                  onChange={handleThumbnailChange}
                  className="thumbnail-input"
                />
                <label htmlFor="edit-thumbnail-upload" className="thumbnail-upload-label">
                  <span className="upload-icon">📷</span>
                  <span>Click to upload thumbnail</span>
                </label>
              </div>
            )}
            <small className="form-hint">Optional. Recommended size: 320x180 pixels</small>
          </div>

          {/* Intermission Screen Upload */}
          <div className="row">
            <label htmlFor="edit-intermission-upload">Intermission Screen</label>
            {intermissionPreview ? (
              <div className="thumbnail-preview">
                <img src={intermissionPreview} alt="Intermission preview" />
                <button
                  type="button"
                  className="thumbnail-remove"
                  onClick={removeIntermission}
                  aria-label="Remove intermission screen"
                >
                  ×
                </button>
              </div>
            ) : (
              <div className="thumbnail-upload-area">
                <input
                  id="edit-intermission-upload"
                  type="file"
                  accept="image/*,video/mp4,video/webm"
                  onChange={handleIntermissionChange}
                  className="thumbnail-input"
                />
                <label htmlFor="edit-intermission-upload" className="thumbnail-upload-label">
                  <span className="upload-icon">TV</span>
                  <span>Upload custom intermission screen</span>
                </label>
              </div>
            )}
            <small className="form-hint">Optional. Shown when your channel is offline. A default screen is used if none is uploaded. Recommended: 1920x1080</small>
          </div>

          {/* Widget Selector */}
          <div className="section-divider">
            <h3>Menu Widgets</h3>
          </div>
          <WidgetSelector
            eventType="film_festival"
            addEvent={existingSessions.length > 0 || addEvent}
            selectedWidgets={selectedWidgets}
            onChange={setSelectedWidgets}
            channelScheduled={channelScheduled}
          />

          {/* About widget textarea (conditional) */}
          {selectedWidgets.some(w => w.type === 'about') && (
            <div className="row">
              <label htmlFor="about-text">About Text (Markdown supported)</label>
              <textarea
                id="about-text"
                value={aboutText}
                onChange={(e) => setAboutText(e.target.value)}
                placeholder="Describe your channel... You can use **bold**, _italic_, and [links](https://example.com)"
                rows={6}
              />
            </div>
          )}

          {/* Schedule Editor (conditional) */}
          {selectedWidgets.some(w => w.type === 'now_playing') && (
            <div className="schedule-editor">
              <div className="section-divider">
                <h3>Now Playing / Up Next Schedule</h3>
              </div>

              {scheduleItems.length > 0 ? (
                <>
                  <div className="schedule-table">
                    {scheduleItems.map((item, idx) => (
                      <div key={idx} className="schedule-row">
                        <button
                          type="button"
                          className="schedule-remove-btn"
                          aria-label="Remove schedule item"
                          onClick={() => removeScheduleRow(idx)}
                        >
                          ✕
                        </button>
                        <div className="schedule-fields-grid">
                          <div className="schedule-field">
                            <label>Film/Title</label>
                            {channelFilms.length > 0 ? (
                              <select
                                value={item.film_id || ""}
                                onChange={(e) => {
                                  const filmId = e.target.value ? parseInt(e.target.value) : null;
                                  const film = channelFilms.find(f => f.id === filmId);
                                  const durationSecs = film?.runtime_seconds || item.duration_seconds;
                                  updateScheduleItem(idx, {
                                    film_id: filmId,
                                    title: film?.title || item.title,
                                    duration_seconds: durationSecs,
                                    durationInput: secondsToTimecode(durationSecs)
                                  });
                                }}
                              >
                                <option value="">-- Select Film --</option>
                                {channelFilms.map(film => (
                                  <option key={film.id} value={film.id}>
                                    {film.title}
                                  </option>
                                ))}
                              </select>
                            ) : (
                              <input
                                type="text"
                                placeholder="Title"
                                value={item.title}
                                onChange={(e) => updateScheduleItem(idx, { title: e.target.value })}
                              />
                            )}
                          </div>

                          <div className="schedule-field">
                            <label>Recurrence</label>
                            <select
                              value={item.recurrence_type}
                              onChange={(e) => updateScheduleItem(idx, {
                                recurrence_type: e.target.value as RecurrenceType,
                                recurrence_days: e.target.value === 'weekly' ? [] : undefined
                              })}
                            >
                              <option value="once">Once</option>
                              <option value="daily">Daily</option>
                              <option value="weekly">Weekly</option>
                              <option value="weekdays">Weekdays (Mon-Fri)</option>
                              <option value="weekends">Weekends (Sat-Sun)</option>
                            </select>
                          </div>

                          <div className="schedule-field duration-field">
                            <label>Duration</label>
                            <input
                              type="text"
                              placeholder="HH:MM:SS"
                              value={item.durationInput ?? secondsToTimecode(item.duration_seconds)}
                              onChange={(e) => {
                                const formatted = formatTimecodeInput(e.target.value);
                                updateScheduleItem(idx, {
                                  durationInput: formatted
                                });
                              }}
                              onBlur={(e) => {
                                // Convert to seconds when user leaves the field
                                const seconds = timecodeToSeconds(e.target.value);
                                updateScheduleItem(idx, {
                                  duration_seconds: seconds,
                                  durationInput: seconds ? secondsToTimecode(seconds) : e.target.value
                                });
                              }}
                              title="Format: HH:MM:SS or MM:SS"
                            />
                          </div>
                        </div>

                        {/* Weekly day selector */}
                        {item.recurrence_type === 'weekly' && (
                          <div className="recurrence-days">
                            <label>Days:</label>
                            <div className="day-checkboxes">
                              {DAY_LABELS.map((day, dayIdx) => (
                                <label key={dayIdx} className="day-checkbox">
                                  <input
                                    type="checkbox"
                                    checked={item.recurrence_days?.includes(dayIdx) || false}
                                    onChange={(e) => {
                                      const days = item.recurrence_days || [];
                                      const newDays = e.target.checked
                                        ? [...days, dayIdx].sort()
                                        : days.filter(d => d !== dayIdx);
                                      updateScheduleItem(idx, { recurrence_days: newDays });
                                    }}
                                  />
                                  <span>{day}</span>
                                </label>
                              ))}
                            </div>
                          </div>
                        )}

                        <div className="schedule-fields-grid">
                          <div className="schedule-field">
                            <label>{item.recurrence_type === 'once' ? 'Air Date & Time' : 'Start Date'}</label>
                            <input
                              type={item.recurrence_type === 'once' ? 'datetime-local' : 'date'}
                              value={item.recurrence_type === 'once' ? item.scheduled_at : item.scheduled_at.split('T')[0]}
                              onChange={(e) => updateScheduleItem(idx, { scheduled_at: e.target.value })}
                            />
                          </div>
                          {item.recurrence_type !== 'once' && (
                            <>
                              <div className="schedule-field">
                                <label>Air Time</label>
                                <input
                                  type="time"
                                  value={item.air_time || ''}
                                  onChange={(e) => updateScheduleItem(idx, { air_time: e.target.value })}
                                />
                              </div>
                              <div className="schedule-field">
                                <label>End Date (optional)</label>
                                <input
                                  type="date"
                                  value={item.recurrence_end_date || ''}
                                  onChange={(e) => updateScheduleItem(idx, { recurrence_end_date: e.target.value })}
                                />
                              </div>
                            </>
                          )}
                        </div>

                      </div>
                    ))}
                  </div>

                  <div className="schedule-actions">
                    <button type="button" className="btn-secondary small" onClick={addScheduleRow}>
                      + Add Time Slot
                    </button>
                    <button type="button" className="btn-primary small" onClick={saveSchedule}>
                      Save Schedule
                    </button>
                  </div>
                </>
              ) : (
                <div className="empty-schedule-message">
                  <p>No schedule items yet. Add time slots to configure what's playing.</p>
                  <button type="button" className="btn-secondary" onClick={addScheduleRow}>
                    + Add First Time Slot
                  </button>
                </div>
              )}
            </div>
          )}

          {/* Historical Events Section */}
          {existingSessions.length > 0 && (
            <div className="historical-events">
              <div className="section-divider">
                <h3>Event History</h3>
              </div>
              <div className="events-list">
                {existingSessions.map((session) => (
                  <div key={session.id} className="event-card">
                    <div className="event-header">
                      <strong>{session.title}</strong>
                      <span className={`status-badge ${session.status}`}>
                        {session.status}
                      </span>
                    </div>
                    <div className="event-details">
                      <span>Type: {session.event_type?.replace('_', ' ')}</span>
                      <span>
                        {new Date(session.starts_at).toLocaleDateString()} - {new Date(session.ends_at).toLocaleDateString()}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Add Event Toggle */}
          <div className="section-divider">
            <h3>Add New Event</h3>
          </div>
          <button
            type="button"
            className={`toggle-btn ${addEvent ? "active" : ""}`}
            onClick={() => setAddEvent(!addEvent)}
          >
            {addEvent ? "✓ Event Form Open" : "+ Add New Event"}
          </button>

          {addEvent && (
            <div className="festival-block">
              <div className="row">
                <label>Type</label>
                <select value={eventType} disabled>
                  <option value="film_festival">Film Festival</option>
                </select>
              </div>

              <div className="row">
                <label>Event Name</label>
                <input
                  type="text"
                  placeholder="e.g. DBTV Summer Shorts 2025"
                  value={eventTitle}
                  onChange={(e) => setEventTitle(e.target.value)}
                  required
                />
              </div>

              <div className="row cols-2">
                <div>
                  <label>Starts</label>
                  <input
                    type="datetime-local"
                    value={startsAt}
                    onChange={(e) => setStartsAt(e.target.value)}
                    required
                  />
                </div>
                <div>
                  <label>Ends</label>
                  <input
                    type="datetime-local"
                    value={endsAt}
                    onChange={(e) => setEndsAt(e.target.value)}
                    required
                  />
                </div>
              </div>

              <div className="row cols-2">
                <div>
                  <label>Voting Mode</label>
                  <select value={votingMode} onChange={(e) => setVotingMode(e.target.value as VotingMode)}>
                    <option value="ratings">Ratings (1–10)</option>
                    <option value="battle">Battle (head‑to‑head)</option>
                  </select>
                </div>
                <label className="checkbox-row" style={{ alignSelf: "end" }}>
                  <input
                    type="checkbox"
                    checked={requireLogin}
                    onChange={(e) => setRequireLogin(e.target.checked)}
                  />
                  <span>Require login to vote</span>
                </label>
              </div>

              <div className="films-header">
                <h4>Films in this festival</h4>
                <button type="button" className="btn-secondary small" onClick={addFilmRow}>+ Add Film</button>
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
                      placeholder="Creator (optional)"
                      value={f.creator || ""}
                      onChange={(e) => updateFilm(idx, { creator: e.target.value })}
                    />
                    <input
                      type="text"
                      placeholder="Duration (e.g. 07:42)"
                      value={f.duration || ""}
                      onChange={(e) => updateFilm(idx, { duration: e.target.value })}
                    />
                    <input
                      type="url"
                      placeholder="Thumbnail URL (optional)"
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
          )}

          <button type="submit" disabled={submitting || !canSubmit()}>
            {submitting ? "Saving..." : "Save Changes"}
          </button>
        </form>
      </div>
    </div>
  );
};

export default EditChannelModal;
