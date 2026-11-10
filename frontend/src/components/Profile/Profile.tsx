import React, { useEffect, useMemo, useState } from "react";
import "./Profile.scss";
import AvatarPicker from "./AvatarPicker";
import CreateChannelModal from "../CreateChannelModal/CreateChannelModal";
import Messages from "./Messages";
import EditChannelModal from "../EditChannelModal/EditChannelModal";
import SchedulerModal from "../SchedulerModal/SchedulerModal";
import EventModal from "../EventModal/EventModal";
import TournamentConsole from "./TournamentConsole";
import AnalyticsModal from "../AnalyticsModal/AnalyticsModal";
import { useApi } from "../../utils/useApi";
import Logo from "../../assets/cinezoo_logo_neon_7.svg";

// Try to import your chat store if available; fall back gracefully.
let useChatStore: any = null;
try {
  // @ts-ignore
  useChatStore = require("../../store/useChatStore").useChatStore;
} catch { /* optional */ }

type Channel = {
  id: string;
  name: string;
  display_name?: string;
  channel_number?: number;
  slug?: string;
  description?: string;
  isLive?: boolean;
  thumbnail?: string;
  event_type?: string;
  session_id?: string;
};

type Award = {
  id: string;
  name: string;
  year?: number | string;
  work?: string;
  position?: number;
};

type ProfileData = {
  id: string;
  handle: string;
  displayName: string;
  bannerUrl?: string;
  avatarUrl?: string;
  bio?: string;
  location?: string;
  website?: string;
  socials?: { label: string; url: string }[];
  stats: {
    followers: number;
    following: number;
    films: number;
    awards: number;
  };
};

type TabKey = "overview" | "channels" | "films" | "messages" | "companies" | "settings";

const DEFAULT_PROFILE: ProfileData = {
  id: "me",
  handle: "@username",
  displayName: "@username",
  bannerUrl: "",
  avatarUrl: "",
  bio: "",
  location: "",
  website: "",
  socials: [],
  stats: { followers: 0, following: 0, films: 0, awards: 0 },
};

const Profile: React.FC = () => {
  const api = useApi();
  const [active, setActive] = useState<TabKey>("overview");
  const [loading, setLoading] = useState(true);

  // Use your existing auth pattern
  const [isLoggedIn, setIsLoggedIn] = useState(!!localStorage.getItem("token"));

  const [profile, setProfile] = useState<ProfileData>(DEFAULT_PROFILE);
  const [channels, setChannels] = useState<Channel[]>([]);
  const [, setAwards] = useState<Award[]>([]);
  const [isEditingBio, setIsEditingBio] = useState(false);
  const [isCreateChannelOpen, setIsCreateChannelOpen] = useState(false);
  const [showAvatarPicker, setShowAvatarPicker] = useState(false);

  // Editable fields
  const [bioDraft, setBioDraft] = useState("");
  const [isSaving, setIsSaving] = useState(false);

  // Password change state
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [passwordError, setPasswordError] = useState("");
  const [passwordSuccess, setPasswordSuccess] = useState("");
  const [isChangingPassword, setIsChangingPassword] = useState(false);

  // User search state
  const [userSearch, setUserSearch] = useState("");
  const [searchResults, setSearchResults] = useState<{ userId: string; userHandle: string; userAvatar?: string }[]>([]);
  const [searching, setSearching] = useState(false);
  const searchTimeoutRef = React.useRef<NodeJS.Timeout | null>(null);

  const [editingChannel, setEditingChannel] = useState<Channel | null>(null);
  const [schedulerChannel, setSchedulerChannel] = useState<Channel | null>(null);
  const [deletingChannelId, setDeletingChannelId] = useState<string | null>(null);

  // Event modal state
  const [addingEventToChannel, setAddingEventToChannel] = useState<Channel | null>(null);

  // Tournament Console modal state
  const [tournamentConsoleChannel, setTournamentConsoleChannel] = useState<Channel | null>(null);

  // Analytics modal state
  const [analyticsChannel, setAnalyticsChannel] = useState<Channel | null>(null);

  // Pull channels from your store if available
  const storeChannels = useMemo(() => {
    try {
      return useChatStore ? useChatStore.getState?.().channels ?? [] : [];
    } catch {
      return [];
    }
  }, []);

  const handleAvatarSelect = async (avatarUrl: string) => {
    try {
      await api.post("/api/profile/avatar", { avatarUrl });
      setProfile(prev => ({ ...prev, avatarUrl }));
    } catch (error) {
      console.error('Failed to update avatar:', error);
    }
  };

  const handleUserSearch = (query: string) => {
    setUserSearch(query);
    if (searchTimeoutRef.current) clearTimeout(searchTimeoutRef.current);
    if (query.length < 2) {
      setSearchResults([]);
      return;
    }
    setSearching(true);
    searchTimeoutRef.current = setTimeout(async () => {
      try {
        const results = await api.get(`/api/messages/users/search?q=${encodeURIComponent(query)}`, []);
        setSearchResults(results);
      } catch (error) {
        console.error("Failed to search users:", error);
      } finally {
        setSearching(false);
      }
    }, 300);
  };

  // Listen for storage changes (like your App.tsx does)
  useEffect(() => {
    const checkLogin = () => setIsLoggedIn(!!localStorage.getItem("token"));
    window.addEventListener("storage", checkLogin);
    return () => window.removeEventListener("storage", checkLogin);
  }, []);

  // Auth required check
  if (!isLoggedIn) {
    return (
      <div className="profile-page">
        <div className="auth-required">
          <h2>Please log in to view your profile</h2>
          <button onClick={() => window.location.href = '/'}>
            Go to Login
          </button>
        </div>
      </div>
    );
  }

  useEffect(() => {
    let mounted = true;

    const loadProfileData = async () => {
      setLoading(true);
      try {
        // Load all profile data
        const [profileData, , awardsData] = await Promise.all([
          api.get("/api/profile/me", DEFAULT_PROFILE),
          api.get("/api/films/mine", []),
          api.get("/api/awards/mine", []),
          api.get("/api/companies/mine", [])
        ]);

        if (mounted) {
          setProfile({ ...DEFAULT_PROFILE, ...profileData });
          setAwards(awardsData);
          setBioDraft(profileData?.bio ?? "");
        }

        // Load channels (from store or API)
        if (storeChannels && storeChannels.length > 0) {
          if (mounted) setChannels(storeChannels);
        } else {
          const channelsData = await api.get("/api/channels/mine", []);
          if (mounted) setChannels(channelsData);
        }
      } catch (error) {
        console.error('Failed to load profile data:', error);
        if (error instanceof Error && error.message === 'Authentication expired') {
          setIsLoggedIn(false);
        }
      } finally {
        if (mounted) setLoading(false);
      }
    };

    if (isLoggedIn) {
      loadProfileData();
    }

    return () => {
      mounted = false;
    };
  }, [isLoggedIn]); // Simple dependency on login status

  const onSaveBio = async () => {
    setIsSaving(true);
    try {
      await api.post("/api/profile/bio", { bio: bioDraft });
      setProfile((prev) => ({ ...prev, bio: bioDraft }));
      setIsEditingBio(false); // Exit edit mode after saving
    } catch (error) {
      console.error('Failed to save bio:', error);
      if (error instanceof Error && error.message === 'Authentication expired') {
        setIsLoggedIn(false);
      }
    } finally {
      setIsSaving(false);
    }
  };

  const onChangePassword = async () => {
    setPasswordError("");
    setPasswordSuccess("");

    if (newPassword.length < 6) {
      setPasswordError("New password must be at least 6 characters.");
      return;
    }
    if (newPassword !== confirmPassword) {
      setPasswordError("New passwords do not match.");
      return;
    }

    setIsChangingPassword(true);
    try {
      await api.post("/api/auth/change-password", { currentPassword, newPassword });
      setPasswordSuccess("Password updated successfully.");
      setCurrentPassword("");
      setNewPassword("");
      setConfirmPassword("");
    } catch (error: any) {
      setPasswordError(error?.message || "Failed to change password.");
    } finally {
      setIsChangingPassword(false);
    }
  };

  const statItems = [
    { label: "Channels", value: channels.length },
  ];

  if (loading) {
    return (
      <div className="profile-page">
        <div className="profile-skeleton">
          <div className="skeleton banner" />
          <div className="skeleton row" />
          <div className="skeleton block" />
        </div>
      </div>
    );
  }

  const handleChannelCreated = (newChannel: any) => {
    setChannels(prev => [...prev, newChannel]);
    // For convenience, drop the owner straight into the Scheduler for the new
    // channel so they can upload and build a loop right away.
    setIsCreateChannelOpen(false);
    setSchedulerChannel(newChannel);
  };

  const handleChannelUpdate = (updatedChannel: any) => {
    setChannels(prev => prev.map(ch =>
      ch.id === updatedChannel.id ? { ...ch, ...updatedChannel } : ch
    ));
  };

  const handleDeleteChannel = async (channelId: string, channelName: string) => {
    if (!window.confirm(`Are you sure you want to delete "${channelName}"? This action cannot be undone.`)) {
      return;
    }

    setDeletingChannelId(channelId);
    try {
      const token = localStorage.getItem("token");
      const res = await fetch(`/api/channels/${channelId}`, {
        method: "DELETE",
        headers: {
          "Authorization": `Bearer ${token}`
        },
        credentials: "include",
      });

      if (!res.ok) throw new Error('Delete failed');

      setChannels(prev => prev.filter(ch => ch.id !== channelId));
    } catch (error) {
      console.error('Failed to delete channel:', error);
      alert('Failed to delete channel. Please try again.');
    } finally {
      setDeletingChannelId(null);
    }
  };

  return (
    <div className="profile-page">
      {/* Header */}
      <div className="profile-header">
        <div className="profile-header-content">
          <div className="user-search-bar">
            <input
              type="text"
              className="user-search-input"
              placeholder="Search for a user..."
              value={userSearch}
              onChange={(e) => handleUserSearch(e.target.value)}
            />
            {searching && <div className="search-loading">Searching...</div>}
            {searchResults.length > 0 && (
              <div className="search-results">
                {searchResults.map((user) => (
                  <a
                    key={user.userId}
                    className="search-result-item"
                    href={`/profile/${user.userHandle}`}
                  >
                    <div className="result-avatar">
                      {user.userAvatar ? (
                        <img src={user.userAvatar} alt={user.userHandle} />
                      ) : (
                        <div className="avatar-placeholder">
                          {user.userHandle[0].toUpperCase()}
                        </div>
                      )}
                    </div>
                    <span className="result-handle">{user.userHandle}</span>
                  </a>
                ))}
              </div>
            )}
            {userSearch.length >= 2 && !searching && searchResults.length === 0 && (
              <div className="no-results">No users found</div>
            )}
          </div>

          <div className="profile-home-button">
            <a href="/">
              <img src={Logo} alt="Cinezoo" className="profile-home-logo" />
            </a>
          </div>
          <div className="avatar-wrap">
            {profile.avatarUrl ? (
              <img className="avatar" src={profile.avatarUrl} alt="Avatar" />
            ) : (
              <div className="avatar placeholder">{profile.displayName?.[0] || "U"}</div>
            )}
            <button
              className="avatar-edit-btn"
              onClick={() => setShowAvatarPicker(true)}
            >
              ✏️
            </button>
          </div>

          <div className="identity">
            <div className="handle">{profile.handle}</div>
            {(profile.location || profile.website) && (
              <div className="meta">
                {profile.location && <span className="chip">{profile.location}</span>}
                {profile.website && (
                  <a className="chip link" href={profile.website} target="_blank" rel="noreferrer">
                    Website
                  </a>
                )}
              </div>
            )}
          </div>

        </div>
        <div className="stats-row">
          {statItems.map((s) => (
            <div key={s.label} className="stat">
              <div className="value">{s.value}</div>
              <div className="label">{s.label}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Tabs */}
      <div className="profile-tabs">
        {[
          ["overview", "Overview"],
          ["channels", "Channels"],
          ["messages", "Messages"],
          ["settings", "Settings"],
        ].map(([key, label]) => (
          <button
            key={key}
            className={`tab ${active === key ? "active" : ""}`}
            onClick={() => setActive(key as TabKey)}
          >
            {label}
          </button>
        ))}
      </div>

      {/* Content */}
      <div className="tab-content">
        {active === "overview" && (
          <section className="panel">
            <h2>About</h2>
            <div className="about-grid">
              <div className="about-left">
                <label className="field-label">Bio</label>
                {!isEditingBio ? (
                  // Read-only bio display
                  <div className="bio-display">
                    <div className="bio-text">
                      {profile.bio || "No bio yet. Click Edit to add one."}
                    </div>
                    <div className="row-actions">
                      <button className="btn primary" onClick={() => setIsEditingBio(true)}>
                        Edit Bio
                      </button>
                    </div>
                  </div>
                ) : (
                  // Edit mode
                  <>
                    <textarea
                      className="input textarea"
                      rows={6}
                      value={bioDraft}
                      onChange={(e) => setBioDraft(e.target.value)}
                      placeholder="Tell the world who you are, your style, and what you're working on."
                    />
                    <div className="row-actions">
                      <button
                        className="btn ghost"
                        onClick={() => {
                          setBioDraft(profile.bio || "");
                          setIsEditingBio(false);
                        }}
                      >
                        Cancel
                      </button>
                      <button className="btn primary" onClick={onSaveBio} disabled={isSaving}>
                        {isSaving ? "Saving..." : "Save Bio"}
                      </button>
                    </div>
                  </>
                )}
              </div>
              <div className="about-right">
                {/* Social links section stays the same */}
              </div>
            </div>
          </section>
        )}

        {active === "channels" && (
          <section className="panel">
            <div className="panel-head">
              <h2>Your Channels</h2>
              <button
                className="btn primary"
                onClick={() => setIsCreateChannelOpen(true)}
              >
                Create Channel
              </button>
            </div>

            {channels.length === 0 ? (
              <p className="muted">You have no channels yet.</p>
            ) : (
              <div className="card-grid">
                {channels.map((ch) => (
                  <div className="card channel" key={ch.id}>
                    <div className="thumb">
                      {ch.thumbnail ? (
                        <img src={ch.thumbnail} alt={ch.name} />
                      ) : (
                        <div className="thumb-fallback">
                          <div className="channel-placeholder">
                            <span className="channel-icon">📺</span>
                          </div>
                        </div>
                      )}
                      {ch.isLive && <span className="live-pill">LIVE</span>}
                    </div>
                    <div className="card-body">
                      <div className="card-title">
                        {ch.channel_number && <div className="channel-number">Channel {ch.channel_number}</div>}
                        <div className="channel-display-name">{ch.display_name || ch.name}</div>
                      </div>
                      {ch.description && <p className="card-desc">{ch.description}</p>}
                      <div className="card-actions">
                        <a className="btn ghost"
                          href={ch.slug ? `/channel/${ch.slug}` : `/channel/${ch.id}`}
                        >
                          View
                        </a>
                        <button
                          className="btn"
                          onClick={() => setEditingChannel(ch)}
                        >
                          Edit
                        </button>
                        <button
                          className="btn"
                          onClick={() => setSchedulerChannel(ch)}
                        >
                          Scheduler
                        </button>
                        <button
                          className="btn"
                          onClick={() => setAddingEventToChannel(ch)}
                        >
                          Add Event
                        </button>

                        {/* Manager button - opens modal instead of navigating */}
                        {ch.event_type?.toLowerCase() === 'tournament' && ch.session_id && (
                          <button
                            className="btn"
                            onClick={() => setTournamentConsoleChannel(ch)}
                          >
                            Manage Event
                          </button>
                        )}

                        <button
                          className="btn"
                          onClick={() => setAnalyticsChannel(ch)}
                        >
                          Analytics
                        </button>
                        <button
                          className="btn danger"
                          onClick={() => handleDeleteChannel(ch.id, ch.display_name || ch.name)}
                          disabled={deletingChannelId === ch.id}
                        >
                          {deletingChannelId === ch.id ? "Deleting..." : "Delete"}
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </section>
        )}

        {active === "messages" && (
          <section className="panel">
            <Messages />
          </section>
        )}

        {active === "settings" && (
          <section className="panel">
            <h2>Settings</h2>
            <div className="settings-grid">
              <div className="setting">
                <div className="setting-title">Privacy</div>
                <div className="setting-desc">Control who can see your profile details.</div>
                <div className="toggle-row">
                  <label className="switch">
                    <input type="checkbox" />
                    <span className="slider" />
                  </label>
                  <span>Make profile discoverable</span>
                </div>
              </div>

              <div className="setting password-setting">
                <div className="setting-title">Change Password</div>
                <div className="setting-desc">Update your account password.</div>
                <div className="password-form">
                  <input
                    type="password"
                    className="input"
                    placeholder="Current password"
                    value={currentPassword}
                    onChange={(e) => setCurrentPassword(e.target.value)}
                  />
                  <input
                    type="password"
                    className="input"
                    placeholder="New password"
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                  />
                  <input
                    type="password"
                    className="input"
                    placeholder="Confirm new password"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                  />
                  {passwordError && <div className="password-error">{passwordError}</div>}
                  {passwordSuccess && <div className="password-success">{passwordSuccess}</div>}
                  <button
                    className="btn primary"
                    onClick={onChangePassword}
                    disabled={isChangingPassword || !currentPassword || !newPassword || !confirmPassword}
                  >
                    {isChangingPassword ? "Updating..." : "Update Password"}
                  </button>
                </div>
              </div>

              <div className="setting">
                <div className="setting-title">Email Notifications</div>
                <div className="setting-desc">New messages, festival updates, no spam.</div>
                <div className="toggle-row">
                  <label className="switch">
                    <input type="checkbox" defaultChecked />
                    <span className="slider" />
                  </label>
                  <span>Send me updates</span>
                </div>
              </div>
            </div>
          </section>
        )}
      </div>

      {/* Modals */}
      <CreateChannelModal
        isOpen={isCreateChannelOpen}
        onClose={() => setIsCreateChannelOpen(false)}
        onChannelCreated={handleChannelCreated}
        onEditChannel={(channel) => {
          setIsCreateChannelOpen(false);
          setEditingChannel(channel);
        }}
      />

      <EditChannelModal
        isOpen={!!editingChannel}
        onClose={() => setEditingChannel(null)}
        channel={editingChannel}
        onUpdate={handleChannelUpdate}
      />

      <SchedulerModal
        isOpen={!!schedulerChannel}
        onClose={() => setSchedulerChannel(null)}
        channelSlug={schedulerChannel?.slug || String(schedulerChannel?.id || "")}
        channelName={schedulerChannel?.display_name || schedulerChannel?.name}
      />

      <AvatarPicker
        isOpen={showAvatarPicker}
        onClose={() => setShowAvatarPicker(false)}
        onSelect={handleAvatarSelect}
        currentAvatar={profile.avatarUrl}
      />

      <EventModal
        isOpen={!!addingEventToChannel}
        onClose={() => setAddingEventToChannel(null)}
        channel={addingEventToChannel}
        onEventCreated={(event) => {
          // Refresh channel data to show new event
          console.log("Event created:", event);
          // Optionally update the channel in state to reflect the new event
          if (addingEventToChannel) {
            setChannels(prev => prev.map(ch =>
              ch.id === addingEventToChannel.id
                ? { ...ch, event_type: event.kind, session_id: event.id }
                : ch
            ));
          }
        }}
      />

      <AnalyticsModal
        isOpen={!!analyticsChannel}
        onClose={() => setAnalyticsChannel(null)}
        apiUrl={analyticsChannel ? `/api/channels/${analyticsChannel.id}/analytics` : ""}
      />

      {/* Tournament Console Modal */}
      {
        tournamentConsoleChannel && (
          <TournamentConsole
            channelId={tournamentConsoleChannel.id}
            sessionId={tournamentConsoleChannel.session_id!}
            onClose={() => setTournamentConsoleChannel(null)}
          />
        )
      }
    </div >
  );
};

export default Profile;
