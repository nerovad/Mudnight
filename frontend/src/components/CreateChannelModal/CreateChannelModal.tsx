import React, { useEffect, useRef, useState } from "react";
import "./CreateChannelModal.scss";

interface Props {
  isOpen: boolean;
  onClose: () => void;
  onChannelCreated?: (channel: any) => void;
  onEditChannel?: (channel: any) => void;
  excludeClickId?: string;
}

type RecurrenceType = 'once' | 'daily' | 'weekly' | 'weekdays' | 'weekends';

type ScheduleItem = {
  title: string;
  scheduled_at: string;        // Start date (and time for 'once')
  duration: string;            // Timecode format: HH:MM:SS or MM:SS
  recurrence_type: RecurrenceType;
  recurrence_days?: number[];  // For 'weekly': [0,1,2,3,4,5,6] where 0=Sun
  recurrence_end_date?: string; // Optional end date (YYYY-MM-DD)
  air_time?: string;           // HH:MM for recurring shows
};

type WidgetConfig = {
  type: string;
  order: number;
};

type WizardStep = {
  key: string;
  label: string;
  hint: string;
};

const emptyScheduleItem: ScheduleItem = {
  title: "",
  scheduled_at: "",
  duration: "",
  recurrence_type: "once",
  recurrence_days: [],
  recurrence_end_date: "",
  air_time: "",
};

const DAY_LABELS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

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

// General widgets available at channel creation. Now Playing is intentionally
// not here: it only makes sense once the channel has a schedule, so it's added
// later from Edit Channel (after building a loop in the Scheduler).
const GENERAL_WIDGETS = [
  { type: 'about', name: 'About', description: 'Channel info and description', icon: 'ℹ️' },
  { type: 'contributions', name: 'Contributions', description: 'Let viewers pitch films to your schedule', icon: '🤝' },
];

type ContributionPolicy = 'open' | 'invite' | 'closed';

// Policy options for the Contributions widget (mirrors ContributionsWidget)
const POLICY_OPTIONS: Array<{ value: ContributionPolicy; label: string; description: string }> = [
  { value: 'open', label: 'Open', description: 'Anyone can pitch films to your schedule' },
  { value: 'invite', label: 'Invite Only', description: 'Only contributors you invite can pitch' },
  { value: 'closed', label: 'Closed', description: 'Not accepting contributions right now' },
];

const RECURRENCE_LABELS: Record<RecurrenceType, string> = {
  once: 'Once',
  daily: 'Daily',
  weekly: 'Weekly',
  weekdays: 'Weekdays (Mon-Fri)',
  weekends: 'Weekends (Sat-Sun)',
};

// Human-readable one-liner for a schedule item in the success summary
const formatScheduleSummary = (item: ScheduleItem): string => {
  let when: string;
  if (item.recurrence_type === 'once') {
    when = item.scheduled_at ? new Date(item.scheduled_at).toLocaleString() : '';
  } else {
    when = RECURRENCE_LABELS[item.recurrence_type];
    if (item.recurrence_type === 'weekly' && item.recurrence_days?.length) {
      when += ` (${item.recurrence_days.map(d => DAY_LABELS[d]).join(', ')})`;
    }
    if (item.air_time) {
      when += ` at ${item.air_time}`;
    }
  }
  const duration = item.duration ? ` · ${item.duration}` : '';
  return `${item.title} — ${when}${duration}`;
};

// Snapshot of submitted values shown on the success screen (form state resets after create)
type CreatedSummary = {
  channelNumber: string;
  displayName: string;
  tags: string[];
  hasThumbnail: boolean;
  hasIntermission: boolean;
  widgetNames: string[];
  aboutText: string;
  scheduleItems: ScheduleItem[];
  contributionPolicy: ContributionPolicy | null;
};

const CreateChannelModal: React.FC<Props> = ({ isOpen, onClose, onChannelCreated, onEditChannel, excludeClickId }) => {
  const boxRef = useRef<HTMLDivElement>(null);
  const firstFieldRef = useRef<HTMLSelectElement>(null);

  // Wizard step navigation
  const [currentStep, setCurrentStep] = useState(0);

  // Channel fields
  const [channelNumber, setChannelNumber] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [success, setSuccess] = useState(false);
  const [channelInfo, setChannelInfo] = useState<any>(null);
  const [createdSummary, setCreatedSummary] = useState<CreatedSummary | null>(null);

  // Widgets
  const [selectedWidgets, setSelectedWidgets] = useState<WidgetConfig[]>([]);
  const [aboutText, setAboutText] = useState("");
  const [contributionPolicy, setContributionPolicy] = useState<ContributionPolicy>('open');

  // Schedule for Now Playing widget
  const [scheduleItems, setScheduleItems] = useState<ScheduleItem[]>([]);

  // Metadata tags
  const [tags, setTags] = useState<string[]>([]);
  const [tagInput, setTagInput] = useState("");

  // Thumbnail
  const [thumbnailFile, setThumbnailFile] = useState<File | null>(null);
  const [thumbnailPreview, setThumbnailPreview] = useState<string | null>(null);

  // Intermission screen
  const [intermissionFile, setIntermissionFile] = useState<File | null>(null);
  const [intermissionPreview, setIntermissionPreview] = useState<string | null>(null);

  // Track taken channel numbers
  const [takenChannelNumbers, setTakenChannelNumbers] = useState<Set<number>>(new Set());
  const [loadingChannels, setLoadingChannels] = useState(false);

  // Generate available channel numbers (2-101), excluding taken ones
  const availableChannels = Array.from({ length: 100 }, (_, i) => i + 2)
    .filter(num => !takenChannelNumbers.has(num));

  // Auto-generate internal name from channel number
  const generateInternalName = (num: string): string => {
    return num ? `channel_${num}` : "";
  };

  // Fetch existing channels to determine taken channel numbers
  useEffect(() => {
    if (!isOpen) return;

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
  }, [isOpen]);

  // Close on outside click
  useEffect(() => {
    if (!isOpen) return;
    const handleClickOutside = (event: MouseEvent) => {
      const excludeEl = excludeClickId ? document.getElementById(excludeClickId) : null;
      if (
        boxRef.current &&
        !boxRef.current.contains(event.target as Node) &&
        (!excludeEl || !excludeEl.contains(event.target as Node))
      ) {
        onClose();
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, [isOpen, onClose, excludeClickId]);

  // ESC to close + lock body scroll
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

  // On open only: reset to first step, clear stale success view, focus first input.
  // Must NOT depend on onClose — parent re-renders give it a new identity, and
  // re-running this mid-session wipes the success screen right after submit.
  useEffect(() => {
    if (!isOpen) return;
    setCurrentStep(0);
    setSuccess(false);
    setChannelInfo(null);
    setCreatedSummary(null);
    setTimeout(() => firstFieldRef.current?.focus(), 0);
  }, [isOpen]);

  const canSubmit = () => {
    return channelNumber && displayName.trim();
  };

  // Widget helpers
  const toggleWidget = (widgetType: string) => {
    const exists = selectedWidgets.find(w => w.type === widgetType);
    if (exists) {
      setSelectedWidgets(selectedWidgets.filter(w => w.type !== widgetType));
    } else {
      const maxOrder = Math.max(...selectedWidgets.map(w => w.order), -1);
      setSelectedWidgets([...selectedWidgets, { type: widgetType, order: maxOrder + 1 }]);
    }
  };

  const isWidgetSelected = (widgetType: string) => {
    return selectedWidgets.some(w => w.type === widgetType);
  };

  // Wizard steps: conditional steps appear only when their widget is selected
  const basicsComplete = Boolean(channelNumber && displayName.trim());

  const steps: WizardStep[] = [
    { key: 'basics', label: 'Basics', hint: 'Pick your channel number and give it a name. That\'s all you need!' },
    { key: 'branding', label: 'Look & Tags', hint: 'Add tags and artwork to help people find your channel. All optional.' },
    { key: 'widgets', label: 'Widgets', hint: 'Pick extras for your channel menu. All optional.' },
    ...(isWidgetSelected('about')
      ? [{ key: 'about', label: 'About', hint: 'Tell viewers what your channel is about.' }]
      : []),
    ...(isWidgetSelected('now_playing')
      ? [{ key: 'schedule', label: 'Schedule', hint: 'Add time slots so viewers know what\'s on.' }]
      : []),
    ...(isWidgetSelected('contributions')
      ? [{ key: 'contributions', label: 'Contributions', hint: 'Choose who can pitch films to your channel.' }]
      : []),
  ];

  const stepIndex = Math.min(currentStep, steps.length - 1);
  const activeStep = steps[stepIndex];
  const isLastStep = stepIndex === steps.length - 1;

  const goToStep = (i: number) => setCurrentStep(Math.max(0, Math.min(i, steps.length - 1)));
  const goPrevious = () => goToStep(stepIndex - 1);
  const goNext = () => goToStep(stepIndex + 1);

  // Schedule helpers
  const addScheduleRow = () => setScheduleItems(prev => [...prev, { ...emptyScheduleItem }]);
  const removeScheduleRow = (idx: number) => setScheduleItems(prev => prev.filter((_, i) => i !== idx));
  const updateScheduleItem = (idx: number, patch: Partial<ScheduleItem>) =>
    setScheduleItems(prev => prev.map((item, i) => (i === idx ? { ...item, ...patch } : item)));

  // Tag helpers
  const addTag = (tag: string) => {
    const trimmed = tag.trim().toLowerCase();
    if (trimmed && !tags.includes(trimmed)) {
      setTags(prev => [...prev, trimmed]);
    }
    setTagInput("");
  };

  const removeTag = (tagToRemove: string) => {
    setTags(prev => prev.filter(t => t !== tagToRemove));
  };

  const handleTagKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Enter") {
      e.preventDefault();
      addTag(tagInput);
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
    if (thumbnailPreview) {
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
    if (intermissionPreview) {
      URL.revokeObjectURL(intermissionPreview);
    }
    setIntermissionFile(null);
    setIntermissionPreview(null);
  };

  // Cleanup preview URLs on unmount
  useEffect(() => {
    return () => {
      if (thumbnailPreview) {
        URL.revokeObjectURL(thumbnailPreview);
      }
      if (intermissionPreview) {
        URL.revokeObjectURL(intermissionPreview);
      }
    };
  }, [thumbnailPreview, intermissionPreview]);

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
    // Pressing Enter on an intermediate step advances instead of submitting
    if (!isLastStep) {
      goNext();
      return;
    }
    if (!canSubmit()) return;

    setSubmitting(true);
    try {
      // Normalize schedule items for submission
      const normalizedSchedule = scheduleItems
        .filter(item => item.title.trim() && item.scheduled_at)
        .map(item => ({
          title: item.title.trim(),
          scheduled_at: new Date(item.scheduled_at).toISOString(),
          duration_seconds: timecodeToSeconds(item.duration),
          recurrence_type: item.recurrence_type || 'once',
          recurrence_days: item.recurrence_type === 'weekly' ? item.recurrence_days : null,
          recurrence_end_date: item.recurrence_end_date || null,
          air_time: item.recurrence_type !== 'once' ? item.air_time : null,
        }));

      // Convert thumbnail to base64 if present
      let thumbnailBase64: string | null = null;
      if (thumbnailFile) {
        thumbnailBase64 = await fileToBase64(thumbnailFile);
      }

      // Convert intermission to base64 if present
      let intermissionBase64: string | null = null;
      if (intermissionFile) {
        intermissionBase64 = await fileToBase64(intermissionFile);
      }

      const body: any = {
        name: generateInternalName(channelNumber),
        display_name: displayName,
        channel_number: parseInt(channelNumber),
        type: "channel",
        widgets: selectedWidgets.length > 0 ? selectedWidgets : null,
        about_text: aboutText || null,
        schedule: normalizedSchedule.length > 0 ? normalizedSchedule : null,
        tags: tags.length > 0 ? tags : null,
        thumbnail: thumbnailBase64,
        intermission: intermissionBase64,
        contribution_policy: isWidgetSelected('contributions') ? contributionPolicy : null,
      };

      const token = localStorage.getItem("token");
      const res = await fetch("/api/channels", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${token}`
        },
        credentials: "include",
        body: JSON.stringify(body),
      });

      if (!res.ok) {
        const msg = await res.text();
        throw new Error(`Failed to create channel: ${res.status} ${msg}`);
      }

      const data = await res.json();
      setChannelInfo(data);

      // Snapshot what was submitted for the success summary before clearing the form
      setCreatedSummary({
        channelNumber,
        displayName,
        tags: [...tags],
        hasThumbnail: !!thumbnailFile,
        hasIntermission: !!intermissionFile,
        widgetNames: selectedWidgets.map(w => GENERAL_WIDGETS.find(g => g.type === w.type)?.name ?? w.type),
        aboutText,
        scheduleItems: scheduleItems.filter(item => item.title.trim() && item.scheduled_at),
        contributionPolicy: isWidgetSelected('contributions') ? contributionPolicy : null,
      });

      // Reset form
      setChannelNumber("");
      setDisplayName("");
      setSelectedWidgets([]);
      setAboutText("");
      setContributionPolicy('open');
      setScheduleItems([]);
      setTags([]);
      setTagInput("");
      removeThumbnail();
      removeIntermission();
      setCurrentStep(0);
      setSuccess(true);

      // Notify parent
      if (onChannelCreated) {
        onChannelCreated(data);
      }
    } catch (err) {
      console.error("Error submitting channel", err);
    } finally {
      setSubmitting(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="create-channel-overlay" role="dialog" aria-modal="true" aria-labelledby="create-channel-title">
      <div className="create-channel-content" ref={boxRef}>
        <button className="close-btn" onClick={onClose} aria-label="Close create channel">X</button>

        <h2 id="create-channel-title">{success ? "Channel Created" : "Create Channel"}</h2>

        {!success && (
        <form className="create-channel-form" onSubmit={handleSubmit}>
          {/* Step legend: click to jump to any step */}
          <ol className="wizard-legend" aria-label="Form steps">
            {steps.map((step, i) => (
              <li key={step.key}>
                <button
                  type="button"
                  className={`legend-step ${i === stepIndex ? 'active' : ''} ${step.key === 'basics' && basicsComplete ? 'complete' : ''}`}
                  onClick={() => goToStep(i)}
                  disabled={i > 0 && !basicsComplete}
                  aria-current={i === stepIndex ? 'step' : undefined}
                >
                  <span className="step-num">{step.key === 'basics' && basicsComplete && i !== stepIndex ? '✓' : i + 1}</span>
                  <span className="step-label">{step.label}</span>
                </button>
              </li>
            ))}
          </ol>

          <p className="wizard-step-hint">{activeStep.hint}</p>

          <div className="wizard-step">
            {/* Step: Basics — Channel Number + Display Name */}
            {activeStep.key === 'basics' && (
              <div className="row channel-name-row">
                <div className="channel-number-field">
                  <label htmlFor="channel-number">Channel #</label>
                  <select
                    ref={firstFieldRef}
                    id="channel-number"
                    value={channelNumber}
                    onChange={(e) => setChannelNumber(e.target.value)}
                    required
                    disabled={loadingChannels}
                  >
                    <option value="">{loadingChannels ? "..." : "#"}</option>
                    {availableChannels.map(num => (
                      <option key={num} value={num}>{num}</option>
                    ))}
                  </select>
                  {!loadingChannels && availableChannels.length === 0 && (
                    <small className="form-hint" style={{ color: '#ff6b6b' }}>
                      All taken
                    </small>
                  )}
                </div>
                <div className="display-name-field">
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
              </div>
            )}

            {/* Step: Look & Tags — Tags + Thumbnail + Intermission */}
            {activeStep.key === 'branding' && (
              <>
                {/* Tags */}
                <div className="row">
                  <label htmlFor="tag-input">Tags</label>
                  <div className="tag-input-container">
                    <input
                      id="tag-input"
                      type="text"
                      placeholder="Type a tag and press Enter..."
                      value={tagInput}
                      onChange={(e) => setTagInput(e.target.value)}
                      onKeyDown={handleTagKeyDown}
                    />
                    <button
                      type="button"
                      className="btn-secondary small"
                      onClick={() => addTag(tagInput)}
                      disabled={!tagInput.trim()}
                    >
                      Add
                    </button>
                  </div>
                  {tags.length > 0 && (
                    <div className="tags-list">
                      {tags.map(tag => (
                        <span key={tag} className="tag-chip">
                          {tag}
                          <button
                            type="button"
                            className="tag-remove"
                            onClick={() => removeTag(tag)}
                            aria-label={`Remove ${tag}`}
                          >
                            ×
                          </button>
                        </span>
                      ))}
                    </div>
                  )}
                  <small className="form-hint">Add tags to help categorize your channel (e.g., horror, comedy, indie)</small>
                </div>

                {/* Thumbnail Upload */}
                <div className="row">
                  <label htmlFor="thumbnail-upload">Channel Thumbnail</label>
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
                        id="thumbnail-upload"
                        type="file"
                        accept="image/*"
                        onChange={handleThumbnailChange}
                        className="thumbnail-input"
                      />
                      <label htmlFor="thumbnail-upload" className="thumbnail-upload-label">
                        <span className="upload-icon">📷</span>
                        <span>Click to upload thumbnail</span>
                      </label>
                    </div>
                  )}
                  <small className="form-hint">Optional. Recommended size: 320x180 pixels</small>
                </div>

                {/* Intermission Screen Upload */}
                <div className="row">
                  <label htmlFor="intermission-upload">Intermission Screen</label>
                  {intermissionPreview ? (
                    <div className="thumbnail-preview">
                      <img src={intermissionPreview} alt="Intermission preview" />
                      <button
                        type="button"
                        className="thumbnail-remove"
                        onClick={removeIntermission}
                        aria-label="Remove intermission screen"
                      >
                        x
                      </button>
                    </div>
                  ) : (
                    <div className="thumbnail-upload-area">
                      <input
                        id="intermission-upload"
                        type="file"
                        accept="image/*,video/mp4,video/webm"
                        onChange={handleIntermissionChange}
                        className="thumbnail-input"
                      />
                      <label htmlFor="intermission-upload" className="thumbnail-upload-label">
                        <span className="upload-icon">TV</span>
                        <span>Upload custom intermission screen</span>
                      </label>
                    </div>
                  )}
                  <small className="form-hint">Optional. Shown when your channel is offline. A default screen is used if none is uploaded. Recommended: 1920x1080</small>
                </div>
              </>
            )}

            {/* Step: Widgets — General widgets only */}
            {activeStep.key === 'widgets' && (
              <div className="widget-selector">
                <h4>Channel Widgets</h4>
                <p className="help-text">Select which widgets to display in your channel menu.</p>

                <div className="widget-grid">
                  {GENERAL_WIDGETS.map(widget => (
                    <label
                      key={widget.type}
                      className={`widget-option ${isWidgetSelected(widget.type) ? 'selected' : ''}`}
                    >
                      <input
                        type="checkbox"
                        checked={isWidgetSelected(widget.type)}
                        onChange={() => toggleWidget(widget.type)}
                      />
                      <div className="widget-card">
                        <span className="widget-icon">{widget.icon}</span>
                        <div className="widget-info">
                          <strong>{widget.name}</strong>
                          <p>{widget.description}</p>
                        </div>
                      </div>
                    </label>
                  ))}
                </div>

                <p className="help-text event-hint">
                  Event widgets (Voting, Leaderboard, Bracket) are automatically added when you create an event.
                </p>
              </div>
            )}

            {/* Step: About widget textarea (conditional) */}
            {activeStep.key === 'about' && (
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

            {/* Step: Now Playing schedule editor (conditional) */}
            {activeStep.key === 'schedule' && (
              <div className="schedule-editor">
                <div className="schedule-header">
                  <h4>Now Playing / Up Next Schedule</h4>
                  <button type="button" className="btn-secondary small" onClick={addScheduleRow}>
                    + Add Time Slot
                  </button>
                </div>

                {scheduleItems.length === 0 ? (
                  <p className="schedule-hint">
                    Add time slots to show what's playing and coming up next on your channel.
                  </p>
                ) : (
                  <div className="schedule-table">
                    {scheduleItems.map((item, idx) => (
                      <div key={idx} className="schedule-row">
                        <button
                          type="button"
                          className="schedule-remove-btn"
                          aria-label="Remove time slot"
                          onClick={() => removeScheduleRow(idx)}
                        >
                          ✕
                        </button>
                        <div className="schedule-fields-grid">
                          <div className="schedule-field">
                            <label>Program Title</label>
                            <input
                              type="text"
                              placeholder="e.g., Movie Night"
                              value={item.title}
                              onChange={(e) => updateScheduleItem(idx, { title: e.target.value })}
                            />
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
                              value={item.duration}
                              onChange={(e) => {
                                const formatted = formatTimecodeInput(e.target.value);
                                updateScheduleItem(idx, { duration: formatted });
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
                )}
              </div>
            )}

            {/* Step: Contribution policy (conditional) */}
            {activeStep.key === 'contributions' && (
              <div className="row">
                <label>Contribution Policy</label>
                <div className="policy-options">
                  {POLICY_OPTIONS.map(opt => (
                    <label
                      key={opt.value}
                      className={`policy-option ${contributionPolicy === opt.value ? 'selected' : ''}`}
                    >
                      <input
                        type="radio"
                        name="contribution-policy"
                        value={opt.value}
                        checked={contributionPolicy === opt.value}
                        onChange={() => setContributionPolicy(opt.value)}
                      />
                      <div className="policy-card">
                        <strong>{opt.label}</strong>
                        <p>{opt.description}</p>
                      </div>
                    </label>
                  ))}
                </div>
                <small className="form-hint">You can change this anytime from the Contributions widget on your channel.</small>
              </div>
            )}
          </div>

          {/* Wizard navigation */}
          <div className="wizard-nav">
            <span className="wizard-progress">Step {stepIndex + 1} of {steps.length}</span>
            <div className="wizard-nav-buttons">
              <button
                type="button"
                className="btn-secondary"
                onClick={goPrevious}
                disabled={stepIndex === 0}
              >
                ← Previous
              </button>
              {isLastStep ? (
                // key forces a fresh DOM node: without it React reuses the Next
                // button's element and the click's default action submits the form
                <button key="submit" type="submit" disabled={submitting || !canSubmit()}>
                  {submitting ? "Creating..." : "Create Channel"}
                </button>
              ) : (
                <button
                  key="next"
                  type="button"
                  className="wizard-next-btn"
                  onClick={goNext}
                  disabled={activeStep.key === 'basics' && !basicsComplete}
                >
                  Next →
                </button>
              )}
            </div>
          </div>
        </form>
        )}

        {success && (
          <div className="create-success">
            <p className="create-channel-message">Channel created successfully!</p>

            {createdSummary && (
              <div className="success-summary">
                <div className="summary-row">
                  <span className="summary-label">Channel</span>
                  <span className="summary-value">#{createdSummary.channelNumber} — {createdSummary.displayName}</span>
                </div>
                <div className="summary-row">
                  <span className="summary-label">Tags</span>
                  <span className="summary-value">{createdSummary.tags.length > 0 ? createdSummary.tags.join(', ') : 'None'}</span>
                </div>
                <div className="summary-row">
                  <span className="summary-label">Thumbnail</span>
                  <span className="summary-value">
                    {channelInfo?.thumbnail ? (
                      <img className="summary-thumb" src={channelInfo.thumbnail} alt="Channel thumbnail" />
                    ) : createdSummary.hasThumbnail ? 'Uploaded' : 'Default'}
                  </span>
                </div>
                <div className="summary-row">
                  <span className="summary-label">Intermission</span>
                  <span className="summary-value">{createdSummary.hasIntermission ? 'Custom screen uploaded' : 'Default screen'}</span>
                </div>
                <div className="summary-row">
                  <span className="summary-label">Widgets</span>
                  <span className="summary-value">{createdSummary.widgetNames.length > 0 ? createdSummary.widgetNames.join(', ') : 'None'}</span>
                </div>
                {createdSummary.aboutText && (
                  <div className="summary-row">
                    <span className="summary-label">About</span>
                    <span className="summary-value summary-about">{createdSummary.aboutText}</span>
                  </div>
                )}
                {createdSummary.scheduleItems.length > 0 && (
                  <div className="summary-row">
                    <span className="summary-label">Schedule</span>
                    <div className="summary-value">
                      <ul className="summary-schedule">
                        {createdSummary.scheduleItems.map((item, idx) => (
                          <li key={idx}>{formatScheduleSummary(item)}</li>
                        ))}
                      </ul>
                    </div>
                  </div>
                )}
                {createdSummary.contributionPolicy && (
                  <div className="summary-row">
                    <span className="summary-label">Contributions</span>
                    <span className="summary-value">
                      {POLICY_OPTIONS.find(o => o.value === createdSummary.contributionPolicy)?.label}
                      {' — '}
                      {POLICY_OPTIONS.find(o => o.value === createdSummary.contributionPolicy)?.description.toLowerCase()}
                    </span>
                  </div>
                )}
              </div>
            )}

            {channelInfo && (
              <div className="channel-details">
                <p><strong>Stream Key:</strong> {channelInfo.stream_key}</p>
                <p><strong>Ingest URL for OBS:</strong> rtmp://cinezoo.tv/live/{channelInfo.stream_key}</p>
                <p><strong>Playback URL (HLS):</strong> {channelInfo.playback_path}</p>

                <div className="channel-actions">
                  <button onClick={() => navigator.clipboard.writeText(channelInfo.stream_key)}>
                    Copy Stream Key
                  </button>
                  <button onClick={() => navigator.clipboard.writeText(`rtmp://cinezoo.tv/live/${channelInfo.stream_key}`)}>
                    Copy Ingest URL
                  </button>
                  <button onClick={() => navigator.clipboard.writeText(channelInfo.playback_path)}>
                    Copy Playback URL
                  </button>
                </div>
              </div>
            )}

            <div className="success-actions">
              {onEditChannel && channelInfo && (
                <button
                  type="button"
                  className="btn-secondary"
                  onClick={() => onEditChannel(channelInfo)}
                >
                  Edit Channel
                </button>
              )}
              <button type="button" className="success-done-btn" onClick={onClose}>
                Done
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default CreateChannelModal;
