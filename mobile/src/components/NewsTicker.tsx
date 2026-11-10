import React, { useEffect, useRef } from "react";
import {
  View,
  Text,
  TouchableOpacity,
  Animated,
  StyleSheet,
  Dimensions,
} from "react-native";

const TICKER_TEXT =
  "Welcome to CineZoo! | Click anywhere on screen to navigate channels | Need to contact us? Email us at cinezoo@gmail.com | Check out channel 99 for Friday Night Rewind: Live!";

interface NewsTickerProps {
  isMinimized: boolean;
  onToggle: () => void;
}

const NewsTicker: React.FC<NewsTickerProps> = ({ isMinimized, onToggle }) => {
  const scrollAnim = useRef(new Animated.Value(0)).current;
  const screenWidth = Dimensions.get("window").width;
  // Approximate text width (rough estimate, 7px per char)
  const textWidth = TICKER_TEXT.length * 7;

  useEffect(() => {
    if (isMinimized) return;

    scrollAnim.setValue(screenWidth);

    const animation = Animated.loop(
      Animated.timing(scrollAnim, {
        toValue: -textWidth,
        duration: (screenWidth + textWidth) * 20,
        useNativeDriver: true,
      })
    );

    animation.start();
    return () => animation.stop();
  }, [isMinimized, screenWidth]);

  if (isMinimized) {
    return (
      <View style={styles.minimized}>
        <TouchableOpacity onPress={onToggle} style={styles.toggleBtn}>
          <Text style={styles.toggleText}>▲</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <TouchableOpacity onPress={onToggle} style={styles.toggleBtn}>
        <Text style={styles.toggleText}>▼</Text>
      </TouchableOpacity>
      <View style={styles.marqueeContainer}>
        <Animated.Text
          style={[styles.tickerText, { transform: [{ translateX: scrollAnim }] }]}
          numberOfLines={1}
        >
          {TICKER_TEXT}
        </Animated.Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    height: 28,
    backgroundColor: "#0d0d1a",
    flexDirection: "row",
    alignItems: "center",
    borderTopWidth: 1,
    borderTopColor: "#2a2a4a",
    overflow: "hidden",
  },
  minimized: {
    height: 18,
    backgroundColor: "#0d0d1a",
    alignItems: "center",
    justifyContent: "center",
    borderTopWidth: 1,
    borderTopColor: "#2a2a4a",
  },
  toggleBtn: {
    paddingHorizontal: 8,
    justifyContent: "center",
    alignItems: "center",
    zIndex: 2,
  },
  toggleText: {
    color: "#888",
    fontSize: 10,
  },
  marqueeContainer: {
    flex: 1,
    overflow: "hidden",
  },
  tickerText: {
    color: "#c0c0c0",
    fontSize: 12,
    position: "absolute",
  },
});

export default NewsTicker;
