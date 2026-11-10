import React, { useEffect, useState } from 'react';
import './NowPlayingWidget.scss';

interface Props {
  channelId: string;
}

interface ScheduleItem {
  id: number;
  film_id: number | null;
  film_title: string | null;
  title: string | null;
  scheduled_at: string;
  duration_seconds: number | null;
  status: 'scheduled' | 'airing' | 'completed';
  is_recurring_instance?: boolean;
  original_id?: number;
}

interface ScheduleData {
  now_playing: ScheduleItem | null;
  up_next: ScheduleItem[];
}

const NowPlayingWidget: React.FC<Props> = ({ channelId }) => {
  const [data, setData] = useState<ScheduleData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchSchedule = async () => {
      try {
        const res = await fetch(`/api/channels/${channelId}/schedule`);
        if (!res.ok) throw new Error('Failed to fetch');

        const scheduleData = await res.json();
        setData(scheduleData);
      } catch (error) {
        console.error('Error fetching schedule:', error);
        setData(null);
      } finally {
        setLoading(false);
      }
    };

    fetchSchedule();

    // Poll frequently so "Now Playing" tracks the airing clip closely (the
    // as-run row updates on every clip start).
    const interval = setInterval(fetchSchedule, 10000);
    return () => clearInterval(interval);
  }, [channelId]);

  if (loading) return <div className="schedule-loading">Loading schedule...</div>;
  if (!data) return <div className="schedule-error">No schedule available</div>;

  const formatTime = (dateString: string) => {
    const date = new Date(dateString);
    const now = new Date();
    const isToday = date.toDateString() === now.toDateString();
    const isTomorrow = date.toDateString() === new Date(now.getTime() + 86400000).toDateString();

    const timeStr = date.toLocaleTimeString('en-US', {
      hour: 'numeric',
      minute: '2-digit',
      hour12: true
    });

    if (isToday) return timeStr;
    if (isTomorrow) return `Tomorrow ${timeStr}`;

    const dayStr = date.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
    return `${dayStr} ${timeStr}`;
  };

  const formatDuration = (seconds: number | null) => {
    if (!seconds) return '';
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  return (
    <div className="now-playing-widget">
      {data.now_playing ? (
        <div className="now-playing-section">
          <h3>🔴 Now Playing</h3>
          <div className="schedule-item current">
            <div className="item-time">{formatTime(data.now_playing.scheduled_at)}</div>
            <div className="item-info">
              <strong>{data.now_playing.film_title || data.now_playing.title}</strong>
              {data.now_playing.duration_seconds && (
                <span className="duration">{formatDuration(data.now_playing.duration_seconds)}</span>
              )}
            </div>
          </div>
        </div>
      ) : (
        <div className="no-current">Nothing currently scheduled</div>
      )}

      {data.up_next && data.up_next.length > 0 && (
        <div className="up-next-section">
          <h3>⏭️ Up Next</h3>
          <div className="schedule-list">
            {data.up_next.map((item) => (
              <div key={item.is_recurring_instance ? `${item.original_id}-${item.scheduled_at}` : item.id} className="schedule-item">
                <div className="item-time">{formatTime(item.scheduled_at)}</div>
                <div className="item-info">
                  <strong>{item.film_title || item.title}</strong>
                  {item.duration_seconds && (
                    <span className="duration">{formatDuration(item.duration_seconds)}</span>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {(!data.now_playing && (!data.up_next || data.up_next.length === 0)) && (
        <div className="empty-schedule">
          <p>No schedule configured yet.</p>
          <p className="help-text">Channel owners can build a 24/7 loop from the Scheduler (in your profile → your channels).</p>
        </div>
      )}
    </div>
  );
};

export default NowPlayingWidget;
