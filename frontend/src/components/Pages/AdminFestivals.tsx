import { useState } from "react";
import "./AdminFestivals.scss";
import ChannelCreator from "../Admin/ChannelCreator";
import ChannelList from "../Admin/ChannelList";
import FestivalCreator from "../Admin/FestivalCreator";
import LineupManager from "../Admin/LineupManager";
import SessionControls from "../Admin/SessionControls";

type Channel = { id: number; slug: string; name: string; stream_url: string | null };

export default function AdminFestivals() {
  const [selectedChannel, setSelectedChannel] = useState<Channel | null>(null);
  const [currentSession, setCurrentSession] = useState<any | null>(null);

  return (
    <div className="page-adminFestivals">
      <h2 className="page-adminFestivals__title">Channel & Festival Admin</h2>

      <ChannelCreator />
      <ChannelList onSelect={(c) => { setSelectedChannel(c); setCurrentSession(null); }} />

      {selectedChannel && (
        <>
          <div className="page-adminFestivals__sectionHeader">
            Selected: <strong>{selectedChannel.name}</strong> <span className="page-adminFestivals__slug">({selectedChannel.slug})</span>
          </div>
          <FestivalCreator
            channelSlug={selectedChannel.slug}
            onCreated={(s) => setCurrentSession(s)}
          />
        </>
      )}

      {currentSession && (
        <>
          <div className="page-adminFestivals__sectionHeader">
            Session: <strong>{currentSession.title}</strong> <span>(id: {currentSession.id})</span>
          </div>
          <LineupManager sessionId={currentSession.id} />
          <SessionControls sessionId={currentSession.id} />
        </>
      )}
    </div>
  );
}

