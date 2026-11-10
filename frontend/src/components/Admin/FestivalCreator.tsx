import React, { useState } from "react";
import { api } from "../../api/client";
import "./FestivalCreator.scss";

export default function FestivalCreator({ channelSlug, onCreated }: {
  channelSlug: string;
  onCreated: (session: any) => void;
}) {
  const [title, setTitle] = useState("");
  const [startsAt, setStartsAt] = useState("");
  const [timezone, setTimezone] = useState("");
  const [busy, setBusy] = useState(false);

  const create = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    try {
      const body: any = { channelSlug, title: title.trim() };
      if (startsAt) body.starts_at = new Date(startsAt).toISOString();
      if (timezone) body.timezone = timezone;
      const s = await api.createSession(body);
      onCreated(s);
      setTitle(""); setStartsAt(""); setTimezone("");
    } catch (err: any) {
      alert(err.message || "Failed to create session");
    } finally { setBusy(false); }
  };

  return (
    <div className="admin-festivalCreator">
      <h3 className="admin-festivalCreator__title">Create Festival/Session for: {channelSlug}</h3>
      <form className="admin-festivalCreator__form" onSubmit={create}>
        <label>
          <span>Session title</span>
          <input value={title} onChange={e => setTitle(e.target.value)} required />
        </label>
        <label>
          <span>Start time (optional)</span>
          <input type="datetime-local" value={startsAt} onChange={e => setStartsAt(e.target.value)} />
        </label>
        <label>
          <span>Timezone (optional, e.g. America/Los_Angeles)</span>
          <input value={timezone} onChange={e => setTimezone(e.target.value)} />
        </label>
        <button type="submit" disabled={busy}>{busy ? "Creating…" : "Create Session"}</button>
      </form>
    </div>
  );
}
