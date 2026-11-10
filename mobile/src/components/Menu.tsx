import React, { useEffect, useState } from "react";
import {
  View,
  Text,
  TouchableOpacity,
  ScrollView,
  StyleSheet,
} from "react-native";
import io from "@cinezoo/shared/realtime";
import { useChatStore } from "@cinezoo/shared";
import { SOCKET_URL, API_BASE_URL } from "../config";

type TrendingChannel = {
  slug: string;
  name: string;
  channelNumber: number | null;
  viewers: number;
};

type WidgetInfo = {
  type: string;
  order: number;
};

function formatViewers(n: number): string {
  if (n < 100) return String(n);
  if (n < 1000) return String(Math.round(n / 50) * 50);
  const rounded = Math.round(n / 100) * 100;
  const k = rounded / 1000;
  return `${k % 1 === 0 ? k.toFixed(0) : k.toFixed(1)}k`;
}

const WIDGET_MAP: Record<string, { name: string; description: string }> = {
  voting_ballot: { name: "Voting Ballot", description: "Rate and support your favorite entries." },
  leaderboard: { name: "Leaderboard", description: "Top-ranked filmmakers." },
  battle_royale: { name: "Battle Royale", description: "Films go head-to-head." },
  tournament_bracket: { name: "Tournament Bracket", description: "See who's advancing." },
  about: { name: "About", description: "Learn about this channel." },
  now_playing: { name: "Now Playing", description: "See what's on right now." },
};

interface MenuProps {
  onNavigateToChannel: (slug: string) => void;
}

const Menu: React.FC<MenuProps> = ({ onNavigateToChannel }) => {
  const { channelId } = useChatStore();
  const [trending, setTrending] = useState<TrendingChannel[]>([]);
  const [widgets, setWidgets] = useState<WidgetInfo[]>([]);

  // Trending channels via socket
  useEffect(() => {
    const sock = io(SOCKET_URL, { transports: ["websocket"] });
    sock.on("viewerCounts", (data: TrendingChannel[]) => setTrending(data));
    return () => { sock.disconnect(); };
  }, []);

  // Fetch channel widgets
  useEffect(() => {
    if (!channelId) { setWidgets([]); return; }
    let alive = true;
    (async () => {
      try {
        const res = await fetch(`${API_BASE_URL}/api/channels/${encodeURIComponent(channelId)}`);
        if (!res.ok) return;
        const data = await res.json();
        if (alive) {
          if (data.widgets?.length > 0) {
            setWidgets(data.widgets.sort((a: WidgetInfo, b: WidgetInfo) => a.order - b.order));
          } else {
            setWidgets([]);
          }
        }
      } catch {
        if (alive) setWidgets([]);
      }
    })();
    return () => { alive = false; };
  }, [channelId]);

  const resolvedWidgets = widgets
    .map((w) => WIDGET_MAP[w.type])
    .filter(Boolean);

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.title}>The Pit</Text>

      {/* Widgets */}
      {resolvedWidgets.length > 0 && (
        <View style={styles.section}>
          {resolvedWidgets.map((w, i) => (
            <TouchableOpacity key={i} style={styles.widgetCard}>
              <Text style={styles.widgetName}>{w.name}</Text>
              <Text style={styles.widgetDesc}>{w.description}</Text>
            </TouchableOpacity>
          ))}
        </View>
      )}

      {/* Trending */}
      {trending.length > 0 && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Trending</Text>
          {trending.map((ch, i) => (
            <TouchableOpacity
              key={ch.slug}
              style={[styles.trendingItem, ch.slug === channelId && styles.trendingActive]}
              onPress={() => onNavigateToChannel(ch.slug)}
            >
              <Text style={styles.trendingRank}>{i + 1}</Text>
              <Text style={styles.trendingName} numberOfLines={1}>{ch.name}</Text>
              <Text style={styles.trendingViewers}>{formatViewers(ch.viewers)}</Text>
            </TouchableOpacity>
          ))}
        </View>
      )}
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#12122a",
  },
  content: {
    padding: 12,
  },
  title: {
    color: "#e0e0e0",
    fontSize: 17,
    fontWeight: "bold",
    marginBottom: 12,
  },
  section: {
    marginBottom: 16,
  },
  sectionTitle: {
    color: "#888",
    fontSize: 13,
    fontWeight: "bold",
    textTransform: "uppercase",
    letterSpacing: 1,
    marginBottom: 8,
  },
  widgetCard: {
    backgroundColor: "#1a1a2e",
    borderRadius: 8,
    padding: 12,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: "#2a2a4a",
  },
  widgetName: {
    color: "#e0e0e0",
    fontSize: 14,
    fontWeight: "bold",
    marginBottom: 4,
  },
  widgetDesc: {
    color: "#888",
    fontSize: 12,
  },
  trendingItem: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: 10,
    paddingHorizontal: 8,
    borderRadius: 6,
    marginBottom: 2,
  },
  trendingActive: {
    backgroundColor: "#2a2a4a",
  },
  trendingRank: {
    color: "#6a6aff",
    fontWeight: "bold",
    fontSize: 14,
    width: 24,
  },
  trendingName: {
    color: "#e0e0e0",
    fontSize: 13,
    flex: 1,
    marginHorizontal: 8,
  },
  trendingViewers: {
    color: "#888",
    fontSize: 12,
  },
});

export default Menu;
