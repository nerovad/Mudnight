import React, { useState } from "react";
import { api } from "../../api/client";
import "./ChannelCreator.scss";

export default function ChannelCreator() {
  const [name, setName] = useState("");
  const [slug, setSlug] = useState("");
  const [streamUrl, setStreamUrl] = useState("");
  const [busy, setBusy] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    try {
      const ch = await api.createChannel({
        name: name.trim(),
        slug: slug.trim() || undefined,
        stream_url: streamUrl.trim() || undefined,
      });
      alert(`Channel saved: ${ch.name} (${ch.slug})`);
      setName(""); setSlug(""); setStreamUrl("");
    } catch (err: any) {
      alert(err.message || "Failed to create channel");
    } finally { setBusy(false); }
  };

  return (
    <div className="admin-channelCreator">
      <h3 className="admin-channelCreator__title">Create / Update Channel</h3>
      <form className="admin-channelCreator__form" onSubmit={submit}>
        <label>
          <span>Channel name</span>
          <input value={name} onChange={e => setName(e.target.value)} required />
        </label>
        <label>
          <span>Custom slug (optional)</span>
          <input value={slug} onChange={e => setSlug(e.target.value)} />
        </label>
        <label>
          <span>Stream URL (optional)</span>
          <input value={streamUrl} onChange={e => setStreamUrl(e.target.value)} />
        </label>
        <button type="submit" disabled={busy}>
          {busy ? "Saving…" : "Save Channel"}
        </button>
      </form>
    </div>
  );
}
