import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { useAuth } from '../../store/AuthContext';
import './ContributionsWidget.scss';

interface Props {
  channelId: string; // slug
}

type Policy = 'open' | 'invite' | 'closed';

interface ChannelInfo {
  id: number;
  owner_id: number | null;
  contribution_policy: Policy;
  display_name: string;
}

interface Contribution {
  id: number;
  film_id: number;
  film_title: string;
  contributor_id: number;
  contributor_name?: string;
  proposed_slot: { scheduled_at?: string; duration_seconds?: number } | null;
  pitch_text: string | null;
  status: 'pending' | 'accepted' | 'declined' | 'withdrawn';
  review_note: string | null;
  created_at: string;
  reviewed_at: string | null;
}

interface Credit {
  id: number;
  username: string;
  accepted_count: number;
}

interface RosterEntry {
  user_id: number;
  username: string;
  role: 'contributor' | 'trusted';
}

interface MyFilm {
  id: number;
  title: string;
  duration: string | null;
}

const POLICY_LABELS: Record<Policy, string> = {
  open: 'Open to contributions',
  invite: 'Contributions by invite',
  closed: 'Closed to contributions',
};

const STATUS_LABELS: Record<Contribution['status'], string> = {
  pending: 'Pending review',
  accepted: 'Accepted',
  declined: 'Declined',
  withdrawn: 'Withdrawn',
};

function durationToSeconds(s?: string | null): number | null {
  if (!s) return null;
  const parts = s.split(':').map(Number);
  if (parts.some(Number.isNaN)) return null;
  if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  if (parts.length === 2) return parts[0] * 60 + parts[1];
  return parts[0];
}

function formatSlot(slot: Contribution['proposed_slot']): string | null {
  if (!slot?.scheduled_at) return null;
  return new Date(slot.scheduled_at).toLocaleString(undefined, {
    month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit',
  });
}

const ContributionsWidget: React.FC<Props> = ({ channelId }) => {
  const { user, token, isAuthenticated } = useAuth();

  const [channel, setChannel] = useState<ChannelInfo | null>(null);
  const [credits, setCredits] = useState<Credit[]>([]);
  const [contributions, setContributions] = useState<Contribution[]>([]);
  const [roster, setRoster] = useState<RosterEntry[]>([]);
  const [myFilms, setMyFilms] = useState<MyFilm[]>([]);
  const [loading, setLoading] = useState(true);
  const [notice, setNotice] = useState<string | null>(null);

  // Pitch form
  const [showPitchForm, setShowPitchForm] = useState(false);
  const [filmMode, setFilmMode] = useState<'existing' | 'new'>('existing');
  const [filmId, setFilmId] = useState<string>('');
  const [newFilmTitle, setNewFilmTitle] = useState('');
  const [newFilmDuration, setNewFilmDuration] = useState('');
  const [slotAt, setSlotAt] = useState(''); // datetime-local
  const [pitchText, setPitchText] = useState('');
  const [rightsConfirmed, setRightsConfirmed] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  // Owner review state
  const [decliningId, setDecliningId] = useState<number | null>(null);
  const [declineNote, setDeclineNote] = useState('');

  // Owner roster form
  const [inviteName, setInviteName] = useState('');
  const [inviteRole, setInviteRole] = useState<'contributor' | 'trusted'>('contributor');

  const isOwner = !!user && !!channel && channel.owner_id === user.id;

  const authHeaders = useMemo<Record<string, string>>(() => {
    const headers: Record<string, string> = {};
    if (token) headers.Authorization = `Bearer ${token}`;
    return headers;
  }, [token]);

  const loadAll = useCallback(async () => {
    try {
      const [chRes, creditsRes] = await Promise.all([
        fetch(`/api/channels/${encodeURIComponent(channelId)}`),
        fetch(`/api/channels/${encodeURIComponent(channelId)}/contributors`),
      ]);
      if (chRes.ok) {
        const data = await chRes.json();
        setChannel({
          id: data.id,
          owner_id: data.owner_id ?? null,
          contribution_policy: data.contribution_policy || 'closed',
          display_name: data.display_name || data.name,
        });
      }
      if (creditsRes.ok) {
        const data = await creditsRes.json();
        setCredits(data.contributors || []);
      }

      if (isAuthenticated && token) {
        const [pitchRes, filmsRes] = await Promise.all([
          fetch(`/api/channels/${encodeURIComponent(channelId)}/contributions`, { headers: authHeaders }),
          fetch('/api/films/mine', { headers: authHeaders }),
        ]);
        if (pitchRes.ok) {
          const data = await pitchRes.json();
          setContributions(data.contributions || []);
          setRoster(data.roster || []);
        }
        if (filmsRes.ok) setMyFilms(await filmsRes.json());
      }
    } catch (e) {
      console.error('Error loading contributions:', e);
    } finally {
      setLoading(false);
    }
  }, [channelId, isAuthenticated, token, authHeaders]);

  useEffect(() => {
    setLoading(true);
    loadAll();
  }, [loadAll]);

  const flash = (msg: string) => {
    setNotice(msg);
    setTimeout(() => setNotice(null), 4000);
  };

  /* ---------- Viewer actions ---------- */

  const submitPitch = async () => {
    if (!rightsConfirmed || submitting) return;
    setSubmitting(true);
    try {
      // Resolve film: existing pick, or create a new entry first
      let pitchedFilmId: number | null = filmMode === 'existing' && filmId ? Number(filmId) : null;
      if (filmMode === 'new') {
        if (!newFilmTitle.trim()) { flash('Film title is required.'); return; }
        const res = await fetch('/api/films', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', ...authHeaders },
          body: JSON.stringify({ title: newFilmTitle.trim(), duration: newFilmDuration || undefined }),
        });
        if (!res.ok) { flash('Could not create film.'); return; }
        pitchedFilmId = (await res.json()).id;
      }
      if (!pitchedFilmId) { flash('Pick a film to pitch.'); return; }

      const selected = myFilms.find((f) => f.id === pitchedFilmId);
      const durationSeconds = durationToSeconds(filmMode === 'new' ? newFilmDuration : selected?.duration);
      const proposed_slot = slotAt
        ? { scheduled_at: new Date(slotAt).toISOString(), ...(durationSeconds ? { duration_seconds: durationSeconds } : {}) }
        : undefined;

      const res = await fetch(`/api/channels/${encodeURIComponent(channelId)}/contributions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...authHeaders },
        body: JSON.stringify({
          film_id: pitchedFilmId,
          proposed_slot,
          pitch_text: pitchText.trim() || undefined,
          rights_confirmed: rightsConfirmed,
        }),
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        flash(err.error || 'Pitch failed.');
        return;
      }
      const created = await res.json();
      flash(created.auto_accepted ? 'Pitch auto-accepted - you have commit access!' : 'Pitch submitted for review.');
      setShowPitchForm(false);
      setFilmId(''); setNewFilmTitle(''); setNewFilmDuration(''); setSlotAt(''); setPitchText(''); setRightsConfirmed(false);
      loadAll();
    } catch (e) {
      console.error('Pitch failed:', e);
      flash('Pitch failed.');
    } finally {
      setSubmitting(false);
    }
  };

  const withdraw = async (id: number) => {
    const res = await fetch(`/api/contributions/${id}/withdraw`, { method: 'POST', headers: authHeaders });
    if (res.ok) { flash('Pitch withdrawn.'); loadAll(); }
  };

  /* ---------- Owner actions ---------- */

  const review = async (id: number, action: 'accept' | 'decline', note?: string) => {
    const res = await fetch(`/api/contributions/${id}/review`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...authHeaders },
      body: JSON.stringify({ action, review_note: note || undefined }),
    });
    if (res.ok) {
      flash(action === 'accept' ? 'Pitch accepted and scheduled.' : 'Pitch declined.');
      setDecliningId(null);
      setDeclineNote('');
      loadAll();
    } else {
      const err = await res.json().catch(() => ({}));
      flash(err.error || 'Review failed.');
    }
  };

  const savePolicy = async (policy: Policy) => {
    if (!channel) return;
    const res = await fetch(`/api/channels/${channel.id}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', ...authHeaders },
      body: JSON.stringify({ contribution_policy: policy }),
    });
    if (res.ok) {
      setChannel({ ...channel, contribution_policy: policy });
      flash(`Channel is now: ${POLICY_LABELS[policy].toLowerCase()}.`);
    }
  };

  const addContributor = async () => {
    if (!inviteName.trim()) return;
    const res = await fetch(`/api/channels/${encodeURIComponent(channelId)}/contributors`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...authHeaders },
      body: JSON.stringify({ username: inviteName.trim(), role: inviteRole }),
    });
    if (res.ok) { setInviteName(''); flash('Contributor added.'); loadAll(); }
    else {
      const err = await res.json().catch(() => ({}));
      flash(err.error || 'Could not add contributor.');
    }
  };

  const removeContributor = async (userId: number) => {
    const res = await fetch(`/api/channels/${encodeURIComponent(channelId)}/contributors/${userId}`, {
      method: 'DELETE',
      headers: authHeaders,
    });
    if (res.ok) { flash('Contributor removed.'); loadAll(); }
  };

  /* ---------- Render ---------- */

  if (loading) return <div className="contrib-loading">Loading...</div>;
  if (!channel) return <div className="contrib-error">Failed to load channel info</div>;

  const policy = channel.contribution_policy;
  const onRoster = !!user && roster.some((r) => r.user_id === user.id);
  const canPitch = isAuthenticated && (isOwner || policy === 'open' || (policy === 'invite' && onRoster));
  const pending = contributions.filter((c) => c.status === 'pending');
  const decided = contributions.filter((c) => c.status !== 'pending');

  return (
    <div className="contributions-widget">
      <div className="contrib-header">
        <span className={`policy-badge policy-${policy}`}>{POLICY_LABELS[policy]}</span>
        {notice && <div className="contrib-notice">{notice}</div>}
      </div>

      {/* === Owner: policy + roster controls === */}
      {isOwner && (
        <section className="contrib-section owner-controls">
          <h4>Channel Settings</h4>
          <label className="policy-row">
            Contribution policy
            <select value={policy} onChange={(e) => savePolicy(e.target.value as Policy)}>
              <option value="open">Open - anyone can pitch</option>
              <option value="invite">Invite only</option>
              <option value="closed">Closed</option>
            </select>
          </label>

          <div className="roster">
            <h5>Contributors &amp; trusted programmers</h5>
            <p className="hint">Trusted contributors skip review - their pitches air automatically.</p>
            <div className="roster-add">
              <input
                type="text"
                placeholder="username"
                value={inviteName}
                onChange={(e) => setInviteName(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && addContributor()}
              />
              <select value={inviteRole} onChange={(e) => setInviteRole(e.target.value as 'contributor' | 'trusted')}>
                <option value="contributor">Contributor</option>
                <option value="trusted">Trusted</option>
              </select>
              <button className="btn-secondary" onClick={addContributor}>Add</button>
            </div>
            {roster.length > 0 && (
              <ul className="roster-list">
                {roster.map((r) => (
                  <li key={r.user_id}>
                    <span className="roster-name">{r.username}</span>
                    <span className={`role-chip role-${r.role}`}>{r.role}</span>
                    <button className="linklike" onClick={() => removeContributor(r.user_id)}>remove</button>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </section>
      )}

      {/* === Owner: review queue === */}
      {isOwner && (
        <section className="contrib-section">
          <h4>Pending Pitches {pending.length > 0 && <span className="count-badge">{pending.length}</span>}</h4>
          {pending.length === 0 ? (
            <p className="empty">No pitches waiting for review.</p>
          ) : (
            <ul className="pitch-list">
              {pending.map((c) => (
                <li key={c.id} className="pitch-card">
                  <div className="pitch-main">
                    <strong>{c.film_title}</strong>
                    <span className="pitch-byline">pitched by {c.contributor_name}</span>
                    {formatSlot(c.proposed_slot) && (
                      <span className="pitch-slot">proposed: {formatSlot(c.proposed_slot)}</span>
                    )}
                    {c.pitch_text && <p className="pitch-text">{c.pitch_text}</p>}
                    <span className="rights-note">✓ rights confirmed</span>
                  </div>
                  <div className="pitch-actions">
                    <button className="btn-primary" onClick={() => review(c.id, 'accept')}>Accept</button>
                    <button className="btn-secondary" onClick={() => { setDecliningId(c.id); setDeclineNote(''); }}>Decline</button>
                  </div>
                  {decliningId === c.id && (
                    <div className="decline-box">
                      <textarea
                        placeholder="Reason (optional - but kind)"
                        value={declineNote}
                        onChange={(e) => setDeclineNote(e.target.value)}
                        rows={2}
                      />
                      <div className="decline-actions">
                        <button className="btn-secondary" onClick={() => setDecliningId(null)}>Cancel</button>
                        <button className="btn-danger" onClick={() => review(c.id, 'decline', declineNote)}>Confirm Decline</button>
                      </div>
                    </div>
                  )}
                </li>
              ))}
            </ul>
          )}
        </section>
      )}

      {/* === Viewer: pitch a film === */}
      {!isOwner && (
        <section className="contrib-section">
          <h4>Pitch a Film</h4>
          {!isAuthenticated ? (
            <p className="empty">Log in to pitch a film to this channel.</p>
          ) : !canPitch ? (
            <p className="empty">
              {policy === 'closed'
                ? 'This channel is not accepting contributions right now.'
                : 'This channel accepts contributions by invite only.'}
            </p>
          ) : !showPitchForm ? (
            <button className="btn-primary" onClick={() => setShowPitchForm(true)}>+ Pitch a Film</button>
          ) : (
            <div className="pitch-form">
              <div className="film-mode-row">
                <label>
                  <input type="radio" checked={filmMode === 'existing'} onChange={() => setFilmMode('existing')} />
                  One of my films
                </label>
                <label>
                  <input type="radio" checked={filmMode === 'new'} onChange={() => setFilmMode('new')} />
                  A new film
                </label>
              </div>

              {filmMode === 'existing' ? (
                myFilms.length === 0 ? (
                  <p className="hint">You have no films yet - add one as "a new film".</p>
                ) : (
                  <select value={filmId} onChange={(e) => setFilmId(e.target.value)}>
                    <option value="">Select a film…</option>
                    {myFilms.map((f) => (
                      <option key={f.id} value={f.id}>
                        {f.title}{f.duration ? ` (${f.duration})` : ''}
                      </option>
                    ))}
                  </select>
                )
              ) : (
                <div className="new-film-row">
                  <input
                    type="text"
                    placeholder="Film title"
                    value={newFilmTitle}
                    onChange={(e) => setNewFilmTitle(e.target.value)}
                  />
                  <input
                    type="text"
                    placeholder="Duration (MM:SS or HH:MM:SS)"
                    value={newFilmDuration}
                    onChange={(e) => setNewFilmDuration(e.target.value)}
                  />
                </div>
              )}

              <label className="slot-row">
                Proposed air time (optional - the owner can also slot it themselves)
                <input type="datetime-local" value={slotAt} onChange={(e) => setSlotAt(e.target.value)} />
              </label>

              <label className="pitch-text-row">
                Your pitch (optional)
                <textarea
                  placeholder="Why does this film belong on this channel?"
                  value={pitchText}
                  onChange={(e) => setPitchText(e.target.value)}
                  rows={3}
                />
              </label>

              <label className="rights-row">
                <input
                  type="checkbox"
                  checked={rightsConfirmed}
                  onChange={(e) => setRightsConfirmed(e.target.checked)}
                />
                <span>
                  I confirm I hold the rights to this film and grant {channel.display_name} permission to broadcast it.
                </span>
              </label>

              <div className="form-actions">
                <button className="btn-secondary" onClick={() => setShowPitchForm(false)}>Cancel</button>
                <button className="btn-primary" disabled={!rightsConfirmed || submitting} onClick={submitPitch}>
                  {submitting ? 'Submitting…' : 'Submit Pitch'}
                </button>
              </div>
            </div>
          )}
        </section>
      )}

      {/* === Viewer: my pitches on this channel === */}
      {!isOwner && isAuthenticated && contributions.length > 0 && (
        <section className="contrib-section">
          <h4>Your Pitches</h4>
          <ul className="pitch-list">
            {contributions.map((c) => (
              <li key={c.id} className="pitch-card">
                <div className="pitch-main">
                  <strong>{c.film_title}</strong>
                  <span className={`status-chip status-${c.status}`}>{STATUS_LABELS[c.status]}</span>
                  {formatSlot(c.proposed_slot) && (
                    <span className="pitch-slot">proposed: {formatSlot(c.proposed_slot)}</span>
                  )}
                  {c.review_note && <p className="review-note">Owner: “{c.review_note}”</p>}
                </div>
                {c.status === 'pending' && (
                  <div className="pitch-actions">
                    <button className="linklike" onClick={() => withdraw(c.id)}>Withdraw</button>
                  </div>
                )}
              </li>
            ))}
          </ul>
        </section>
      )}

      {/* === Owner: decision history === */}
      {isOwner && decided.length > 0 && (
        <section className="contrib-section">
          <h4>Decision History</h4>
          <ul className="pitch-list compact">
            {decided.slice(0, 10).map((c) => (
              <li key={c.id} className="pitch-card">
                <div className="pitch-main">
                  <strong>{c.film_title}</strong>
                  <span className="pitch-byline">by {c.contributor_name}</span>
                  <span className={`status-chip status-${c.status}`}>{STATUS_LABELS[c.status]}</span>
                </div>
              </li>
            ))}
          </ul>
        </section>
      )}

      {/* === Everyone: credits === */}
      <section className="contrib-section credits">
        <h4>Programmed By</h4>
        {credits.length === 0 ? (
          <p className="empty">No outside contributions have aired yet. Be the first.</p>
        ) : (
          <ul className="credits-list">
            {credits.map((c) => (
              <li key={c.id}>
                <span className="credit-name">{c.username}</span>
                <span className="credit-count">
                  {c.accepted_count} {c.accepted_count === 1 ? 'pick' : 'picks'} aired
                </span>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
};

export default ContributionsWidget;
