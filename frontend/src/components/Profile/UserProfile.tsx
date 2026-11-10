import React, { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import "./Profile.scss";
import Logo from "../../assets/cinezoo_logo_neon_7.svg";
import { useApi } from "../../utils/useApi";

type Channel = {
  id: string;
  name: string;
  display_name?: string;
  channel_number?: number;
  slug?: string;
  description?: string;
  thumbnail?: string;
};

type PublicProfileData = {
  id: string;
  handle: string;
  displayName: string;
  bannerUrl?: string;
  avatarUrl?: string;
  bio?: string;
  location?: string;
  website?: string;
  stats: {
    followers: number;
    following: number;
    films: number;
    awards: number;
  };
  channels: Channel[];
};

const UserProfile: React.FC = () => {
  const { handle } = useParams<{ handle: string }>();
  const api = useApi();
  const [profile, setProfile] = useState<PublicProfileData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // User search state
  const [userSearch, setUserSearch] = useState("");
  const [searchResults, setSearchResults] = useState<{ userId: string; userHandle: string; userAvatar?: string }[]>([]);
  const [searching, setSearching] = useState(false);
  const searchTimeoutRef = React.useRef<NodeJS.Timeout | null>(null);

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
      } catch (err) {
        console.error("Failed to search users:", err);
      } finally {
        setSearching(false);
      }
    }, 300);
  };

  useEffect(() => {
    if (!handle) return;
    setLoading(true);
    setError(null);

    const cleanHandle = handle.startsWith('@') ? handle.slice(1) : handle;

    fetch(`/api/profile/user/${encodeURIComponent(cleanHandle)}`)
      .then(async (res) => {
        if (!res.ok) throw new Error(res.status === 404 ? "User not found" : "Failed to load profile");
        return res.json();
      })
      .then((data) => {
        setProfile(data);
        setLoading(false);
      })
      .catch((err) => {
        setError(err.message);
        setLoading(false);
      });
  }, [handle]);

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

  if (error || !profile) {
    return (
      <div className="profile-page">
        <div className="auth-required">
          <h2>{error || "User not found"}</h2>
          <button onClick={() => window.location.href = '/'}>Go Home</button>
        </div>
      </div>
    );
  }

  const statItems = [
    { label: "Channels", value: profile.channels.length },
  ];

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

      {/* Bio */}
      {profile.bio && (
        <section className="panel" style={{ marginTop: 18 }}>
          <h2>About</h2>
          <div className="bio-display">
            <div className="bio-text">{profile.bio}</div>
          </div>
        </section>
      )}

      {/* Channels */}
      {profile.channels.length > 0 && (
        <section className="panel" style={{ marginTop: 12 }}>
          <h2>Channels</h2>
          <div className="card-grid">
            {profile.channels.map((ch) => (
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
                </div>
                <div className="card-body">
                  <div className="card-title">
                    {ch.channel_number && <div className="channel-number">Channel {ch.channel_number}</div>}
                    <div className="channel-display-name">{ch.display_name || ch.name}</div>
                  </div>
                  {ch.description && <p className="card-desc">{ch.description}</p>}
                  <div className="card-actions">
                    <a
                      className="btn ghost"
                      href={ch.slug ? `/channel/${ch.slug}` : `/channel/${ch.id}`}
                    >
                      Watch
                    </a>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </section>
      )}
    </div>
  );
};

export default UserProfile;
