import React, { useState, useEffect } from "react";
import { useAuth, UserGroup } from "../../store/AuthContext";
import { useNavigate } from "react-router-dom";
import AnalyticsModal from "../AnalyticsModal/AnalyticsModal";
import TickerManager from "../Admin/TickerManager";
import "./Admin.scss";

interface UserRow {
  id: number;
  username: string;
  email: string;
  user_group: UserGroup;
  created_at: string;
}

interface ChannelRow {
  id: number;
  slug: string;
  name: string;
  display_name: string | null;
  channel_number: number | null;
  owner_id: number | null;
  owner_name: string | null;
  created_at: string;
}

const GROUP_LABELS: Record<UserGroup, string> = {
  super_admin: "Super Admin",
  network: "Network",
  general_user: "General User",
};

const Admin: React.FC = () => {
  const { user, token } = useAuth();
  const navigate = useNavigate();
  const [users, setUsers] = useState<UserRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [updatingId, setUpdatingId] = useState<number | null>(null);

  const [channels, setChannels] = useState<ChannelRow[]>([]);
  const [channelsLoading, setChannelsLoading] = useState(true);
  const [editingChannel, setEditingChannel] = useState<number | null>(null);
  const [editForm, setEditForm] = useState({ name: "", display_name: "", channel_number: "" });
  const [deletingId, setDeletingId] = useState<number | null>(null);
  const [confirmDeleteId, setConfirmDeleteId] = useState<number | null>(null);
  const [deletingUserId, setDeletingUserId] = useState<number | null>(null);
  const [confirmDeleteUserId, setConfirmDeleteUserId] = useState<number | null>(null);

  // Analytics state
  const [analyticsChannelId, setAnalyticsChannelId] = useState<number | null>(null);
  const [analyticsSearch, setAnalyticsSearch] = useState("");

  useEffect(() => {
    if (!user || user.userGroup !== "super_admin") {
      navigate("/");
      return;
    }
    fetchUsers();
    fetchChannels();
  }, [user]);

  const fetchUsers = async () => {
    try {
      const res = await fetch("/api/admin/users", {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) throw new Error("Failed to fetch users");
      const data = await res.json();
      setUsers(data);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleGroupChange = async (userId: number, newGroup: UserGroup) => {
    setUpdatingId(userId);
    setError(null);
    try {
      const res = await fetch(`/api/admin/users/${userId}/group`, {
        method: "PUT",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ userGroup: newGroup }),
      });
      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || "Failed to update group");
      }
      setUsers((prev) =>
        prev.map((u) => (u.id === userId ? { ...u, user_group: newGroup } : u))
      );
    } catch (err: any) {
      setError(err.message);
    } finally {
      setUpdatingId(null);
    }
  };

  const deleteUser = async (userId: number) => {
    setDeletingUserId(userId);
    setError(null);
    try {
      const res = await fetch(`/api/admin/users/${userId}`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || "Failed to delete user");
      }
      setUsers((prev) => prev.filter((u) => u.id !== userId));
      setConfirmDeleteUserId(null);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setDeletingUserId(null);
    }
  };

  const fetchChannels = async () => {
    try {
      const res = await fetch("/api/admin/channels", {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) throw new Error("Failed to fetch channels");
      const data = await res.json();
      setChannels(data);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setChannelsLoading(false);
    }
  };

  const startEditing = (ch: ChannelRow) => {
    setEditingChannel(ch.id);
    setEditForm({
      name: ch.name,
      display_name: ch.display_name || "",
      channel_number: ch.channel_number?.toString() || "",
    });
  };

  const cancelEditing = () => {
    setEditingChannel(null);
    setEditForm({ name: "", display_name: "", channel_number: "" });
  };

  const saveChannel = async (channelId: number) => {
    setError(null);
    try {
      const res = await fetch(`/api/admin/channels/${channelId}`, {
        method: "PUT",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          name: editForm.name || undefined,
          display_name: editForm.display_name || undefined,
          channel_number: editForm.channel_number ? parseInt(editForm.channel_number) : undefined,
        }),
      });
      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || "Failed to update channel");
      }
      const updated = await res.json();
      setChannels((prev) =>
        prev.map((ch) => (ch.id === channelId ? { ...ch, ...updated } : ch))
      );
      setEditingChannel(null);
    } catch (err: any) {
      setError(err.message);
    }
  };

  const deleteChannel = async (channelId: number) => {
    setDeletingId(channelId);
    setError(null);
    try {
      const res = await fetch(`/api/admin/channels/${channelId}`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || "Failed to delete channel");
      }
      setChannels((prev) => prev.filter((ch) => ch.id !== channelId));
      setConfirmDeleteId(null);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setDeletingId(null);
    }
  };

  if (!user || user.userGroup !== "super_admin") return null;

  return (
    <div className="admin-page">
      <div className="admin-page__header">
        <h1>Admin Panel</h1>
        <button className="admin-page__back" onClick={() => navigate(-1)}>
          Back
        </button>
      </div>

      <section className="admin-page__section">
        <h2>Access Control</h2>
        <p className="admin-page__description">
          Manage user roles and permissions. <strong>Super Admin</strong> can see and do everything.{" "}
          <strong>Network</strong> can create channels but cannot access admin.{" "}
          <strong>General User</strong> cannot create channels or access admin.
        </p>

        {error && <div className="admin-page__error">{error}</div>}

        {loading ? (
          <div className="admin-page__loading">Loading users...</div>
        ) : (
          <table className="admin-page__table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Username</th>
                <th>Email</th>
                <th>Group</th>
                <th>Joined</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {users.map((u) => (
                <tr key={u.id} className={u.id === user.id ? "admin-page__current-user" : ""}>
                  <td>{u.id}</td>
                  <td>{u.username}</td>
                  <td>{u.email}</td>
                  <td>
                    <select
                      value={u.user_group}
                      onChange={(e) => handleGroupChange(u.id, e.target.value as UserGroup)}
                      disabled={updatingId === u.id}
                      className={`admin-page__group-select admin-page__group-select--${u.user_group}`}
                    >
                      {Object.entries(GROUP_LABELS).map(([value, label]) => (
                        <option key={value} value={value}>
                          {label}
                        </option>
                      ))}
                    </select>
                  </td>
                  <td>{new Date(u.created_at).toLocaleDateString()}</td>
                  <td className="admin-page__actions">
                    {u.id === user.id ? null : confirmDeleteUserId === u.id ? (
                      <>
                        <button
                          className="admin-page__btn admin-page__btn--confirm-delete"
                          onClick={() => deleteUser(u.id)}
                          disabled={deletingUserId === u.id}
                        >
                          {deletingUserId === u.id ? "..." : "Confirm"}
                        </button>
                        <button
                          className="admin-page__btn admin-page__btn--cancel"
                          onClick={() => setConfirmDeleteUserId(null)}
                        >
                          Cancel
                        </button>
                      </>
                    ) : (
                      <button
                        className="admin-page__btn admin-page__btn--delete"
                        onClick={() => setConfirmDeleteUserId(u.id)}
                      >
                        Delete
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>

      <section className="admin-page__section admin-page__section--channels">
        <h2>Channel Management</h2>
        <p className="admin-page__description">
          View, edit, and delete all channels across the platform.
        </p>

        {channelsLoading ? (
          <div className="admin-page__loading">Loading channels...</div>
        ) : channels.length === 0 ? (
          <div className="admin-page__loading">No channels found.</div>
        ) : (
          <table className="admin-page__table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Name</th>
                <th>Display Name</th>
                <th>#</th>
                <th>Slug</th>
                <th>Owner</th>
                <th>Created</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {channels.map((ch) => (
                <tr key={ch.id}>
                  <td>{ch.id}</td>
                  {editingChannel === ch.id ? (
                    <>
                      <td>
                        <input
                          className="admin-page__edit-input"
                          value={editForm.name}
                          onChange={(e) => setEditForm((f) => ({ ...f, name: e.target.value }))}
                        />
                      </td>
                      <td>
                        <input
                          className="admin-page__edit-input"
                          value={editForm.display_name}
                          onChange={(e) => setEditForm((f) => ({ ...f, display_name: e.target.value }))}
                          placeholder="Display name"
                        />
                      </td>
                      <td>
                        <input
                          className="admin-page__edit-input admin-page__edit-input--small"
                          type="number"
                          value={editForm.channel_number}
                          onChange={(e) => setEditForm((f) => ({ ...f, channel_number: e.target.value }))}
                          placeholder="#"
                        />
                      </td>
                    </>
                  ) : (
                    <>
                      <td>{ch.name}</td>
                      <td>{ch.display_name || "—"}</td>
                      <td>{ch.channel_number ?? "—"}</td>
                    </>
                  )}
                  <td className="admin-page__slug">{ch.slug}</td>
                  <td>{ch.owner_name || "—"}</td>
                  <td>{new Date(ch.created_at).toLocaleDateString()}</td>
                  <td className="admin-page__actions">
                    {editingChannel === ch.id ? (
                      <>
                        <button
                          className="admin-page__btn admin-page__btn--save"
                          onClick={() => saveChannel(ch.id)}
                        >
                          Save
                        </button>
                        <button
                          className="admin-page__btn admin-page__btn--cancel"
                          onClick={cancelEditing}
                        >
                          Cancel
                        </button>
                      </>
                    ) : confirmDeleteId === ch.id ? (
                      <>
                        <button
                          className="admin-page__btn admin-page__btn--confirm-delete"
                          onClick={() => deleteChannel(ch.id)}
                          disabled={deletingId === ch.id}
                        >
                          {deletingId === ch.id ? "..." : "Confirm"}
                        </button>
                        <button
                          className="admin-page__btn admin-page__btn--cancel"
                          onClick={() => setConfirmDeleteId(null)}
                        >
                          Cancel
                        </button>
                      </>
                    ) : (
                      <>
                        <button
                          className="admin-page__btn admin-page__btn--edit"
                          onClick={() => startEditing(ch)}
                        >
                          Edit
                        </button>
                        <button
                          className="admin-page__btn admin-page__btn--analytics"
                          onClick={() => setAnalyticsChannelId(ch.id)}
                        >
                          Analytics
                        </button>
                        <button
                          className="admin-page__btn admin-page__btn--delete"
                          onClick={() => setConfirmDeleteId(ch.id)}
                        >
                          Delete
                        </button>
                      </>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
      <section className="admin-page__section admin-page__section--analytics">
        <h2>Channel Analytics</h2>
        <p className="admin-page__description">
          Search for a channel by name to view its analytics.
        </p>
        <div className="admin-page__analytics-search">
          <input
            className="admin-page__edit-input"
            type="text"
            placeholder="Search channels..."
            value={analyticsSearch}
            onChange={(e) => setAnalyticsSearch(e.target.value)}
          />
        </div>
        {analyticsSearch.length > 0 && (
          <div className="admin-page__analytics-results">
            {channels
              .filter((ch) => {
                const q = analyticsSearch.toLowerCase();
                return (
                  ch.name.toLowerCase().includes(q) ||
                  (ch.display_name || "").toLowerCase().includes(q) ||
                  ch.slug.toLowerCase().includes(q) ||
                  (ch.owner_name || "").toLowerCase().includes(q)
                );
              })
              .map((ch) => (
                <button
                  key={ch.id}
                  className="admin-page__analytics-item"
                  onClick={() => setAnalyticsChannelId(ch.id)}
                >
                  <span className="admin-page__analytics-item-name">
                    {ch.display_name || ch.name}
                  </span>
                  {ch.channel_number && (
                    <span className="admin-page__analytics-item-num">
                      Ch. {ch.channel_number}
                    </span>
                  )}
                  <span className="admin-page__analytics-item-owner">
                    {ch.owner_name || "No owner"}
                  </span>
                </button>
              ))}
          </div>
        )}
      </section>

      <TickerManager token={token} />

      <AnalyticsModal
        isOpen={analyticsChannelId !== null}
        onClose={() => setAnalyticsChannelId(null)}
        apiUrl={analyticsChannelId ? `/api/admin/channels/${analyticsChannelId}/analytics` : ""}
      />
    </div>
  );
};

export default Admin;
