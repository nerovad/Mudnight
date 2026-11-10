import { useEffect, useState } from "react";
import { api } from "../../api/client";
import "./ChannelList.scss";

type Channel = { id: number; slug: string; name: string; stream_url: string | null };

export default function ChannelList({ onSelect }: { onSelect: (c: Channel) => void }) {
  const [channels, setChannels] = useState<Channel[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.listChannels().then(setChannels).catch(e => console.error(e)).finally(() => setLoading(false));
  }, []);

  return (
    <div className="admin-channelList">
      <h3 className="admin-channelList__title">Channels</h3>
      {loading ? (
        <div className="admin-channelList__empty">Loading channels…</div>
      ) : !channels.length ? (
        <div className="admin-channelList__empty">No channels yet.</div>
      ) : (
        <ul className="admin-channelList__list">
          {channels.map(c => (
            <li key={c.id} className="admin-channelList__item">
              <button onClick={() => onSelect(c)} className="admin-channelList__button">
                {c.name} <small>({c.slug})</small>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
