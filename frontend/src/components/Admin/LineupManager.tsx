import React, { useEffect, useState } from "react";
import { api } from "../../api/client";
import "./LineupManager.scss";

type Entry = { entry_id: number; order_index: number; film_id: number; title: string };

export default function LineupManager({ sessionId }: { sessionId: number }) {
  const [lineup, setLineup] = useState<Entry[]>([]);
  const [filmTitle, setFilmTitle] = useState("");
  const [orderIndex, setOrderIndex] = useState<number | "">("");

  const refresh = async () => {
    const items = await api.lineup(sessionId);
    setLineup(items);
  };

  useEffect(() => { refresh().catch(console.error); }, [sessionId]);

  const add = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!filmTitle.trim()) return;
    await api.addEntry(sessionId, {
      filmTitle: filmTitle.trim(),
      order_index: orderIndex === "" ? undefined : Number(orderIndex),
    });
    setFilmTitle(""); setOrderIndex("");
    await refresh();
  };

  return (
    <div className="admin-lineupManager">
      <h3 className="admin-lineupManager__title">Lineup</h3>
      <form className="admin-lineupManager__form" onSubmit={add}>
        <label>
          <span>Film title</span>
          <input value={filmTitle} onChange={e => setFilmTitle(e.target.value)} />
        </label>
        <label>
          <span>Order (optional)</span>
          <input
            value={orderIndex}
            onChange={e => setOrderIndex(e.target.value === "" ? "" : Number(e.target.value))}
          />
        </label>
        <button type="submit">Add to Lineup</button>
      </form>

      <ol className="admin-lineupManager__list">
        {lineup.map(e => (
          <li key={e.entry_id}>
            <span className="admin-lineupManager__order">{e.order_index}.</span> {e.title}
          </li>
        ))}
      </ol>
    </div>
  );
}
