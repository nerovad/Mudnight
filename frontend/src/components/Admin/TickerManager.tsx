import React, { useCallback, useEffect, useMemo, useState } from "react";

export interface TickerRow {
  id: number;
  kind: "editorial" | "sponsor";
  body: string;
  sponsor_name: string | null;
  link_url: string | null;
  priority: number;
  active: boolean;
  starts_at: string | null;
  ends_at: string | null;
}

interface Props {
  token: string | null;
}

type FormState = {
  kind: "editorial" | "sponsor";
  body: string;
  sponsorName: string;
  linkUrl: string;
  priority: string;
  active: boolean;
  startsAt: string;
  endsAt: string;
};

const EMPTY_FORM: FormState = {
  kind: "editorial",
  body: "",
  sponsorName: "",
  linkUrl: "",
  priority: "0",
  active: true,
  startsAt: "",
  endsAt: "",
};

function errorMessage(err: unknown): string {
  return err instanceof Error ? err.message : "Something went wrong";
}

/** `datetime-local` wants `YYYY-MM-DDTHH:mm`; Postgres hands back an ISO string. */
function toLocalInput(iso: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function rowToForm(row: TickerRow): FormState {
  return {
    kind: row.kind,
    body: row.body,
    sponsorName: row.sponsor_name ?? "",
    linkUrl: row.link_url ?? "",
    priority: String(row.priority),
    active: row.active,
    startsAt: toLocalInput(row.starts_at),
    endsAt: toLocalInput(row.ends_at),
  };
}

/** A row is live when switched on and now sits inside its flight window —
 *  the same rule the public endpoint applies. */
function isLive(row: TickerRow, now: number): boolean {
  if (!row.active) return false;
  if (row.starts_at && new Date(row.starts_at).getTime() > now) return false;
  if (row.ends_at && new Date(row.ends_at).getTime() <= now) return false;
  return true;
}

/**
 * Sponsor exclusivity is not a database constraint — flights have to be
 * queueable while the current one runs, so overlap is caught here instead.
 * Two active sponsors whose windows intersect means someone who was sold
 * exclusivity is about to share the strip.
 */
function findSponsorOverlaps(rows: TickerRow[]): string[] {
  const sponsors = rows.filter((r) => r.kind === "sponsor" && r.active);
  const warnings: string[] = [];

  for (let i = 0; i < sponsors.length; i++) {
    for (let j = i + 1; j < sponsors.length; j++) {
      const a = sponsors[i];
      const b = sponsors[j];
      const aStart = a.starts_at ? new Date(a.starts_at).getTime() : -Infinity;
      const aEnd = a.ends_at ? new Date(a.ends_at).getTime() : Infinity;
      const bStart = b.starts_at ? new Date(b.starts_at).getTime() : -Infinity;
      const bEnd = b.ends_at ? new Date(b.ends_at).getTime() : Infinity;

      if (aStart < bEnd && bStart < aEnd) {
        warnings.push(
          `"${a.sponsor_name}" and "${b.sponsor_name}" have overlapping flights. ` +
            `Only the higher priority one will run.`
        );
      }
    }
  }
  return warnings;
}

const TickerManager: React.FC<Props> = ({ token }) => {
  const [rows, setRows] = useState<TickerRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [saving, setSaving] = useState(false);
  const [confirmDeleteId, setConfirmDeleteId] = useState<number | null>(null);

  const authHeaders = useMemo(
    () => ({ Authorization: `Bearer ${token}`, "Content-Type": "application/json" }),
    [token]
  );

  const fetchRows = useCallback(async () => {
    try {
      const res = await fetch("/api/ticker/all", {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) throw new Error("Failed to load ticker messages");
      setRows(await res.json());
      setError(null);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, [token]);

  useEffect(() => {
    if (token) fetchRows();
  }, [token, fetchRows]);

  const resetForm = () => {
    setEditingId(null);
    setForm(EMPTY_FORM);
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError(null);

    const payload = {
      kind: form.kind,
      body: form.body,
      sponsorName: form.kind === "sponsor" ? form.sponsorName : null,
      linkUrl: form.linkUrl || null,
      priority: Number(form.priority) || 0,
      active: form.active,
      // datetime-local has no zone; new Date() reads it as local time, which
      // is what the person filling the form meant.
      startsAt: form.startsAt ? new Date(form.startsAt).toISOString() : null,
      endsAt: form.endsAt ? new Date(form.endsAt).toISOString() : null,
    };

    try {
      const res = await fetch(editingId ? `/api/ticker/${editingId}` : "/api/ticker", {
        method: editingId ? "PUT" : "POST",
        headers: authHeaders,
        body: JSON.stringify(payload),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.error || "Failed to save");
      }
      resetForm();
      await fetchRows();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  const toggleActive = async (row: TickerRow) => {
    setError(null);
    try {
      const res = await fetch(`/api/ticker/${row.id}`, {
        method: "PUT",
        headers: authHeaders,
        body: JSON.stringify({
          kind: row.kind,
          body: row.body,
          sponsorName: row.sponsor_name,
          linkUrl: row.link_url,
          priority: row.priority,
          active: !row.active,
          startsAt: row.starts_at,
          endsAt: row.ends_at,
        }),
      });
      if (!res.ok) throw new Error("Failed to update");
      await fetchRows();
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  const remove = async (id: number) => {
    setError(null);
    try {
      const res = await fetch(`/api/ticker/${id}`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) throw new Error("Failed to delete");
      setConfirmDeleteId(null);
      if (editingId === id) resetForm();
      await fetchRows();
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  const now = Date.now();
  const overlaps = useMemo(() => findSponsorOverlaps(rows), [rows]);

  return (
    <section className="admin-page__section">
      <h2>News Ticker</h2>
      <p className="admin-page__description">
        Segments loop left to right in priority order, highest first. The player re-reads
        this every 5 minutes, so edits reach people already watching without a reload.{" "}
        <strong>Sponsor</strong> segments render with a "Sponsored by" label and are
        click-tracked. Only one sponsor runs at a time — if two are live, the higher
        priority wins.
      </p>

      {error && <div className="admin-page__error">{error}</div>}

      {overlaps.map((warning) => (
        <div key={warning} className="admin-page__error">
          Booking conflict: {warning}
        </div>
      ))}

      <form className="admin-page__ticker-form" onSubmit={submit}>
        <div className="admin-page__ticker-form-row">
          <select
            value={form.kind}
            onChange={(e) =>
              setForm({ ...form, kind: e.target.value as "editorial" | "sponsor" })
            }
          >
            <option value="editorial">Editorial</option>
            <option value="sponsor">Sponsor</option>
          </select>

          <input
            type="text"
            placeholder="Message text"
            value={form.body}
            onChange={(e) => setForm({ ...form, body: e.target.value })}
            required
          />

          <input
            type="number"
            placeholder="Priority"
            title="Higher sorts earlier in the loop"
            value={form.priority}
            onChange={(e) => setForm({ ...form, priority: e.target.value })}
          />
        </div>

        {form.kind === "sponsor" && (
          <div className="admin-page__ticker-form-row">
            <input
              type="text"
              placeholder="Sponsor name (advertiser of record)"
              value={form.sponsorName}
              onChange={(e) => setForm({ ...form, sponsorName: e.target.value })}
              required
            />
            <input
              type="url"
              placeholder="Link URL (optional, https://)"
              value={form.linkUrl}
              onChange={(e) => setForm({ ...form, linkUrl: e.target.value })}
            />
          </div>
        )}

        <div className="admin-page__ticker-form-row">
          <label>
            Starts
            <input
              type="datetime-local"
              value={form.startsAt}
              onChange={(e) => setForm({ ...form, startsAt: e.target.value })}
            />
          </label>
          <label>
            Ends
            <input
              type="datetime-local"
              value={form.endsAt}
              onChange={(e) => setForm({ ...form, endsAt: e.target.value })}
            />
          </label>
          <label>
            <input
              type="checkbox"
              checked={form.active}
              onChange={(e) => setForm({ ...form, active: e.target.checked })}
            />
            Active
          </label>

          <button type="submit" disabled={saving}>
            {saving ? "Saving..." : editingId ? "Save changes" : "Add segment"}
          </button>
          {editingId && (
            <button type="button" onClick={resetForm}>
              Cancel
            </button>
          )}
        </div>
      </form>

      {loading ? (
        <div className="admin-page__loading">Loading ticker...</div>
      ) : rows.length === 0 ? (
        <div className="admin-page__loading">No ticker segments yet.</div>
      ) : (
        <table className="admin-page__table">
          <thead>
            <tr>
              <th>Status</th>
              <th>Kind</th>
              <th>Message</th>
              <th>Sponsor</th>
              <th>Priority</th>
              <th>Flight</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.id}>
                <td>{isLive(row, now) ? "On air" : row.active ? "Scheduled" : "Off"}</td>
                <td>{row.kind === "sponsor" ? "Sponsor" : "Editorial"}</td>
                <td>{row.body}</td>
                <td>{row.sponsor_name ?? "—"}</td>
                <td>{row.priority}</td>
                <td>
                  {row.starts_at || row.ends_at
                    ? `${row.starts_at ? new Date(row.starts_at).toLocaleDateString() : "now"} → ${
                        row.ends_at ? new Date(row.ends_at).toLocaleDateString() : "open"
                      }`
                    : "always"}
                </td>
                <td>
                  <button
                    onClick={() => {
                      setEditingId(row.id);
                      setForm(rowToForm(row));
                    }}
                  >
                    Edit
                  </button>
                  <button onClick={() => toggleActive(row)}>
                    {row.active ? "Deactivate" : "Activate"}
                  </button>
                  {confirmDeleteId === row.id ? (
                    <>
                      <button onClick={() => remove(row.id)}>Confirm</button>
                      <button onClick={() => setConfirmDeleteId(null)}>Cancel</button>
                    </>
                  ) : (
                    <button onClick={() => setConfirmDeleteId(row.id)}>Delete</button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  );
};

export default TickerManager;
