import { useEffect, useState } from "react";
import { api } from "../../api/client";
import "./SessionControls.scss";

type LeaderItem = { entry_id: number; title: string; weighted_avg: number; votes: number };

export default function SessionControls({ sessionId }: { sessionId: number }) {
  const [leader, setLeader] = useState<LeaderItem[]>([]);
  const [statusMsg, setStatusMsg] = useState("");

  const refresh = async () => {
    const rows = await api.leaderboard(sessionId);
    setLeader(rows);
  };

  useEffect(() => { refresh().catch(console.error); }, [sessionId]);

  const start = async () => {
    const s = await api.startSession(sessionId);
    setStatusMsg(`Session status: ${s.status}`);
  };

  const close = async () => {
    const s = await api.closeSession(sessionId);
    setStatusMsg(`Session status: ${s.status}`);
    await refresh();
  };

  return (
    <div className="admin-sessionControls">
      <h3 className="admin-sessionControls__title">Session Controls</h3>

      <div className="admin-sessionControls__actions">
        <button onClick={start}>Start</button>
        <button onClick={close}>Close</button>
      </div>

      {statusMsg && <p className="admin-sessionControls__status">{statusMsg}</p>}

      <h4 className="admin-sessionControls__subtitle">Leaderboard</h4>
      <table className="admin-sessionControls__table">
        <thead>
          <tr><th>Title</th><th>Avg</th><th>Votes</th></tr>
        </thead>
        <tbody>
          {leader.map(r => (
            <tr key={r.entry_id}>
              <td>{r.title}</td>
              <td>{r.weighted_avg}</td>
              <td>{r.votes}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <button className="admin-sessionControls__refresh" onClick={refresh}>Refresh Leaderboard</button>
    </div>
  );
}
