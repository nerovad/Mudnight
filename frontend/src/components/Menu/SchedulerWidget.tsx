import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useAuth } from '../../store/AuthContext';
import './SchedulerWidget.scss';

interface Props {
  channelId: string; // slug
}

interface ChannelInfo {
  id: number;
  owner_id: number | null;
  display_name: string;
}

interface MediaItem {
  id: number;
  title: string;
  duration_ms: number;
  conform_status: 'pending' | 'ready' | 'failed';
  original_name: string | null;
}

interface Segment {
  id: number;
  media_id: number;
  position: number;
  in_ms: number;
  out_ms: number;
  playing_ms: number;
  title: string | null;
  media_duration_ms: number;
}

function fmt(ms: number): string {
  const total = Math.max(0, Math.round(ms / 1000));
  const s = total % 60;
  const m = Math.floor(total / 60) % 60;
  const h = Math.floor(total / 3600);
  const pad = (n: number) => String(n).padStart(2, '0');
  return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
}

function fmtBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  const units = ['KB', 'MB', 'GB', 'TB'];
  let value = bytes / 1024;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  return `${value.toFixed(value < 10 ? 1 : 0)} ${units[unit]}`;
}

const SchedulerWidget: React.FC<Props> = ({ channelId }) => {
  const { user, token } = useAuth();

  const [channel, setChannel] = useState<ChannelInfo | null>(null);
  const [media, setMedia] = useState<MediaItem[]>([]);
  const [segments, setSegments] = useState<Segment[]>([]);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [uploadPct, setUploadPct] = useState(0);
  const [uploadLabel, setUploadLabel] = useState('');
  const [notice, setNotice] = useState<string | null>(null);
  const [dragOver, setDragOver] = useState<number | null>(null);
  const [renamingId, setRenamingId] = useState<number | null>(null);
  const [renameValue, setRenameValue] = useState('');

  const dragIndex = useRef<number | null>(null);
  const fileRef = useRef<HTMLInputElement | null>(null);

  const authHeaders = useMemo<Record<string, string>>(() => {
    const headers: Record<string, string> = {};
    if (token) headers.Authorization = `Bearer ${token}`;
    return headers;
  }, [token]);
  const isOwner = !!user && !!channel && channel.owner_id === user.id;

  const loadChannel = useCallback(async () => {
    const res = await fetch(`/api/channels/${encodeURIComponent(channelId)}`);
    if (res.ok) {
      const d = await res.json();
      setChannel({ id: d.id, owner_id: d.owner_id ?? null, display_name: d.display_name || d.name });
    }
  }, [channelId]);

  const loadMedia = useCallback(async (): Promise<MediaItem[]> => {
    const res = await fetch(`/api/channels/${encodeURIComponent(channelId)}/media`, { headers: authHeaders });
    if (!res.ok) return [];
    const d = await res.json();
    const list: MediaItem[] = d.media || [];
    setMedia(list);
    return list;
  }, [channelId, authHeaders]);

  const loadSegments = useCallback(async () => {
    const res = await fetch(`/api/channels/${encodeURIComponent(channelId)}/segments`, { headers: authHeaders });
    if (res.ok) {
      const d = await res.json();
      setSegments(d.segments || []);
    }
  }, [channelId, authHeaders]);

  useEffect(() => {
    (async () => {
      setLoading(true);
      await loadChannel();
      await Promise.all([loadMedia(), loadSegments()]);
      setLoading(false);
    })();
  }, [loadChannel, loadMedia, loadSegments]);

  // Poll while anything is still conforming; the effect re-runs when `media`
  // changes and stops arming once nothing is pending.
  useEffect(() => {
    if (!media.some((m) => m.conform_status === 'pending')) return;
    const id = window.setInterval(() => { loadMedia(); }, 4000);
    return () => clearInterval(id);
  }, [media, loadMedia]);

  const onUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    setUploadPct(0);
    setUploadLabel(`0 B of ${fmtBytes(file.size)}`);
    setNotice(null);

    const fd = new FormData();
    fd.append('file', file);
    fd.append('title', file.name.replace(/\.[^.]+$/, ''));

    try {
      // XHR rather than fetch: fetch exposes no upload progress events, and a
      // multi-GB master is minutes of silence without them.
      await new Promise<void>((resolve, reject) => {
        const xhr = new XMLHttpRequest();
        xhr.open('POST', `/api/channels/${encodeURIComponent(channelId)}/media`);
        // Note: no Content-Type header — the browser sets the multipart boundary.
        Object.entries(authHeaders).forEach(([k, v]) => xhr.setRequestHeader(k, v));

        xhr.upload.onprogress = (ev) => {
          if (!ev.lengthComputable) return;
          setUploadPct(Math.round((ev.loaded / ev.total) * 100));
          setUploadLabel(`${fmtBytes(ev.loaded)} of ${fmtBytes(ev.total)}`);
        };
        // Bytes are all sent, but the server is still moving the file into place
        // and replying — hold the bar at full rather than letting it read as done.
        xhr.upload.onload = () => {
          setUploadPct(100);
          setUploadLabel('Finishing up…');
        };

        xhr.onload = () => {
          if (xhr.status >= 200 && xhr.status < 300) return resolve();
          let msg = 'Upload failed.';
          try {
            const body = JSON.parse(xhr.responseText);
            if (body?.error) msg = body.error;
          } catch {
            /* non-JSON error body (proxy 413 page, etc.) — keep the generic text */
          }
          reject(new Error(msg));
        };
        xhr.onerror = () =>
          reject(new Error('Upload failed — the connection dropped before the file finished.'));
        xhr.ontimeout = () => reject(new Error('Upload timed out.'));

        xhr.send(fd);
      });

      setNotice('Uploaded — conforming to broadcast format…');
      await loadMedia();
    } catch (err: any) {
      setNotice(err?.message || 'Upload failed.');
    } finally {
      setUploading(false);
      setUploadPct(0);
      setUploadLabel('');
      if (fileRef.current) fileRef.current.value = '';
    }
  };

  const beginRename = (m: MediaItem) => {
    setRenamingId(m.id);
    setRenameValue(m.title);
  };

  const commitRename = async (m: MediaItem) => {
    const title = renameValue.trim();
    setRenamingId(null);
    if (!title || title === m.title) return;
    // Optimistic; reload the (retitled, schedule-rev-bumped) media + segments.
    setMedia((prev) => prev.map((x) => (x.id === m.id ? { ...x, title } : x)));
    const res = await fetch(`/api/channels/${encodeURIComponent(channelId)}/media/${m.id}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', ...authHeaders },
      body: JSON.stringify({ title }),
    });
    if (res.ok) {
      await Promise.all([loadMedia(), loadSegments()]);
    } else {
      setNotice('Rename failed.');
      loadMedia();
    }
  };

  const addToSchedule = async (m: MediaItem) => {
    const res = await fetch(`/api/channels/${encodeURIComponent(channelId)}/segments`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...authHeaders },
      body: JSON.stringify({ media_id: m.id }),
    });
    if (res.ok) loadSegments();
    else setNotice('Could not add to schedule.');
  };

  const removeSegment = async (id: number) => {
    const res = await fetch(`/api/channels/${encodeURIComponent(channelId)}/segments/${id}`, {
      method: 'DELETE',
      headers: authHeaders,
    });
    if (res.ok || res.status === 204) loadSegments();
  };

  const commitReorder = async (ids: number[]) => {
    const res = await fetch(`/api/channels/${encodeURIComponent(channelId)}/segments/reorder`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...authHeaders },
      body: JSON.stringify({ ordered_ids: ids }),
    });
    if (res.ok) {
      const d = await res.json();
      setSegments(d.segments || []);
    } else {
      setNotice('Reorder failed.');
      loadSegments();
    }
  };

  const onDrop = (dropIndex: number) => {
    const from = dragIndex.current;
    dragIndex.current = null;
    setDragOver(null);
    if (from === null || from === dropIndex) return;
    const next = [...segments];
    const [moved] = next.splice(from, 1);
    next.splice(dropIndex, 0, moved);
    setSegments(next); // optimistic
    commitReorder(next.map((s) => s.id));
  };

  if (loading) return <div className="sched-status">Loading scheduler…</div>;
  if (!isOwner) return <div className="sched-status">Only the channel owner can edit programming.</div>;

  const totalMs = segments.reduce((sum, s) => sum + s.playing_ms, 0);
  const maxMs = Math.max(1, ...segments.map((s) => s.playing_ms));
  const heightFor = (ms: number) => Math.max(46, Math.round((ms / maxMs) * 110) + 46);

  return (
    <div className="scheduler-widget">
      {notice && <div className="sched-notice">{notice}</div>}

      <div className="sched-cols">
        {/* Media library */}
        <div className="sched-lib">
          <div className="sched-head">Media library</div>
          <input ref={fileRef} type="file" accept="video/*" hidden onChange={onUpload} />
          <button className="sched-upload" disabled={uploading} onClick={() => fileRef.current?.click()}>
            {uploading ? `Uploading… ${uploadPct}%` : '⬆ Upload master'}
          </button>
          {uploading && (
            <div className="sched-progress">
              <div
                className="sched-progress-track"
                role="progressbar"
                aria-valuemin={0}
                aria-valuemax={100}
                aria-valuenow={uploadPct}
                aria-label="Upload progress"
              >
                <div className="sched-progress-fill" style={{ width: `${uploadPct}%` }} />
              </div>
              <div className="sched-progress-label">{uploadLabel}</div>
            </div>
          )}
          <ul className="sched-media-list">
            {media.length === 0 && <li className="sched-empty">No media yet. Upload a film to begin.</li>}
            {media.map((m) => (
              <li key={m.id} className={`media-item status-${m.conform_status}`}>
                <div className="mi-main">
                  {renamingId === m.id ? (
                    <input
                      className="mi-rename"
                      autoFocus
                      value={renameValue}
                      onChange={(e) => setRenameValue(e.target.value)}
                      onBlur={() => commitRename(m)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') commitRename(m);
                        if (e.key === 'Escape') setRenamingId(null);
                      }}
                    />
                  ) : (
                    <span className="mi-title" title="Click ✎ to rename">
                      {m.title}
                      <button className="mi-rename-btn" title="Rename" onClick={() => beginRename(m)}>✎</button>
                    </span>
                  )}
                  <span className="mi-meta">
                    {m.conform_status === 'ready'
                      ? fmt(m.duration_ms)
                      : m.conform_status === 'pending'
                      ? 'conforming…'
                      : 'failed'}
                  </span>
                </div>
                <button className="mi-add" disabled={m.conform_status !== 'ready'} onClick={() => addToSchedule(m)}>
                  + add
                </button>
              </li>
            ))}
          </ul>
        </div>

        {/* Schedule timeline */}
        <div className="sched-timeline">
          <div className="sched-head">
            Schedule <span className="sched-total">{fmt(totalMs)} loop</span>
          </div>
          {segments.length === 0 && <div className="sched-empty">Add media on the left to build the loop.</div>}
          <ul className="sched-segments">
            {segments.map((s, i) => (
              <li
                key={s.id}
                className={`seg-block${dragOver === i ? ' drag-over' : ''}`}
                style={{ height: heightFor(s.playing_ms) }}
                draggable
                onDragStart={() => { dragIndex.current = i; }}
                onDragOver={(e) => { e.preventDefault(); if (dragOver !== i) setDragOver(i); }}
                onDragLeave={() => { if (dragOver === i) setDragOver(null); }}
                onDrop={() => onDrop(i)}
              >
                <span className="seg-grip">⠿</span>
                <span className="seg-title">{s.title || 'Untitled'}</span>
                <span className="seg-dur">{fmt(s.playing_ms)}</span>
                <button className="seg-remove" title="Remove" onClick={() => removeSegment(s.id)}>×</button>
              </li>
            ))}
          </ul>
          {segments.length > 0 && <div className="sched-foot">Loops to fill 24h · drag to reorder</div>}
        </div>
      </div>
    </div>
  );
};

export default SchedulerWidget;
