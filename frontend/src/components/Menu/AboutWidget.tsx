import React, { useEffect, useState } from 'react';
import ReactMarkdown from 'react-markdown';
import './AboutWidget.scss';

interface Props {
  channelId: string;
}

interface ChannelAbout {
  about_text: string | null;
  owner_name: string | null;
  first_live_at: string | null;
  created_at: string;
  display_name: string;
  thumbnail: string | null;
}

const AboutWidget: React.FC<Props> = ({ channelId }) => {
  const [data, setData] = useState<ChannelAbout | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      try {
        const res = await fetch(`/api/channels/${channelId}`);
        if (!res.ok) throw new Error('Failed to fetch');

        const channelData = await res.json();
        setData({
          about_text: channelData.about_text,
          owner_name: channelData.owner_name || 'Unknown',
          first_live_at: channelData.first_live_at,
          created_at: channelData.created_at,
          display_name: channelData.display_name || channelData.name,
          thumbnail: channelData.thumbnail || null
        });
      } catch (error) {
        console.error('Error fetching about data:', error);
      } finally {
        setLoading(false);
      }
    })();
  }, [channelId]);

  if (loading) return <div className="about-loading">Loading...</div>;
  if (!data) return <div className="about-error">Failed to load channel info</div>;

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
  };

  return (
    <div className="about-widget">
      {data.thumbnail && (
        <div className="about-thumbnail">
          <img src={data.thumbnail} alt={data.display_name} />
        </div>
      )}
      <h2>{data.display_name}</h2>

      {data.about_text && (
        <div className="about-content">
          <ReactMarkdown>{data.about_text}</ReactMarkdown>
        </div>
      )}

      <div className="about-meta">
        <div className="meta-item">
          <strong>Channel Owner:</strong>
          <span>{data.owner_name}</span>
        </div>

        <div className="meta-item">
          <strong>First Aired:</strong>
          <span>
            {data.first_live_at
              ? formatDate(data.first_live_at)
              : formatDate(data.created_at)}
          </span>
        </div>
      </div>
    </div>
  );
};

export default AboutWidget;
