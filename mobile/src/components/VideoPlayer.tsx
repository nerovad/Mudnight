import React, { useRef, useState, useEffect, useCallback } from "react";
import { View, Text, TouchableOpacity, StyleSheet, Image, Dimensions } from "react-native";
import { Video, ResizeMode, AVPlaybackStatus } from "expo-av";
import { useChatStore } from "@cinezoo/shared";
import { API_BASE_URL, HLS_BASE } from "../config";

export type VideoLink = {
  src: string;
  channel: string;
  channelNumber: number;
  displayName?: string;
  tags?: string[];
  isLive?: boolean;
  intermissionUrl?: string | null;
};

interface VideoPlayerProps {
  isLandscape: boolean;
  currentIndex: number;
  setCurrentIndex: (i: number) => void;
  videoLinks: VideoLink[];
  onChannelUp: () => void;
}

const VideoPlayer: React.FC<VideoPlayerProps> = ({
  isLandscape,
  currentIndex,
  setCurrentIndex,
  videoLinks,
  onChannelUp,
}) => {
  const videoRef = useRef<Video>(null);
  const [isMuted, setIsMuted] = useState(true);
  const [showMuteIcon, setShowMuteIcon] = useState(true);
  const [channelName, setChannelName] = useState("");
  const [showIntermission, setShowIntermission] = useState(false);
  const { setChannelId } = useChatStore();

  const currentLink = videoLinks[currentIndex];

  // Load video when index changes
  useEffect(() => {
    if (!currentLink) return;
    setShowIntermission(false);
    setChannelId(currentLink.channel);
    setChannelName(currentLink.displayName || currentLink.channel);

    const hide = setTimeout(() => setChannelName(""), 5000);
    return () => clearTimeout(hide);
  }, [currentIndex, currentLink?.channel]);

  const toggleMute = () => {
    setIsMuted((m) => !m);
    setShowMuteIcon((m) => !m);
  };

  const onPlaybackStatusUpdate = (status: AVPlaybackStatus) => {
    if (!status.isLoaded) {
      if (status.error) {
        console.log("Playback error:", status.error);
        setShowIntermission(true);
      }
      return;
    }
    if (status.didJustFinish) {
      onChannelUp();
    }
  };

  const screenWidth = Dimensions.get("window").width;
  const screenHeight = Dimensions.get("window").height;

  // Portrait: 16:9 aspect ratio, max 35% of screen height
  const portraitVideoHeight = Math.min(screenWidth * (9 / 16), screenHeight * 0.35);

  const videoStyle = isLandscape
    ? { width: screenWidth, height: screenHeight }
    : { width: screenWidth, height: portraitVideoHeight };

  const videoSource = currentLink
    ? { uri: currentLink.src }
    : undefined;

  return (
    <View style={[styles.container, isLandscape && styles.containerLandscape]}>
      <TouchableOpacity
        activeOpacity={1}
        style={[styles.tvContainer, videoStyle]}
        onPress={toggleMute}
      >
        {!showIntermission && videoSource ? (
          <Video
            ref={videoRef}
            source={videoSource}
            style={StyleSheet.absoluteFill}
            resizeMode={isLandscape ? ResizeMode.COVER : ResizeMode.CONTAIN}
            shouldPlay
            isMuted={isMuted}
            isLooping={false}
            onPlaybackStatusUpdate={onPlaybackStatusUpdate}
            onError={() => setShowIntermission(true)}
          />
        ) : (
          <View style={styles.intermission}>
            <Text style={styles.intermissionText}>Intermission</Text>
            <Text style={styles.intermissionSub}>Stream offline</Text>
          </View>
        )}

        {/* Channel name overlay */}
        {channelName !== "" && (
          <View style={styles.channelOverlay}>
            <Text style={styles.channelText}>{channelName}</Text>
          </View>
        )}

        {/* Mute icon overlay */}
        {showMuteIcon && !showIntermission && (
          <View style={styles.muteOverlay}>
            <Text style={styles.muteIcon}>🔇</Text>
          </View>
        )}
      </TouchableOpacity>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: "#000",
  },
  containerLandscape: {
    position: "absolute",
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    zIndex: 999,
  },
  tvContainer: {
    backgroundColor: "#000",
    justifyContent: "center",
    alignItems: "center",
  },
  intermission: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "#0d0d1a",
    justifyContent: "center",
    alignItems: "center",
  },
  intermissionText: {
    color: "#e0e0e0",
    fontSize: 22,
    fontWeight: "bold",
  },
  intermissionSub: {
    color: "#666",
    fontSize: 14,
    marginTop: 8,
  },
  channelOverlay: {
    position: "absolute",
    top: 12,
    right: 12,
    backgroundColor: "rgba(0,0,0,0.6)",
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 6,
  },
  channelText: {
    color: "#e0e0e0",
    fontSize: 14,
    fontWeight: "bold",
  },
  muteOverlay: {
    position: "absolute",
    bottom: 12,
    right: 12,
    backgroundColor: "rgba(0,0,0,0.5)",
    borderRadius: 20,
    width: 36,
    height: 36,
    justifyContent: "center",
    alignItems: "center",
  },
  muteIcon: {
    fontSize: 18,
  },
});

export default VideoPlayer;
