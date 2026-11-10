import React, { useState, useRef } from "react";
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  Modal,
  FlatList,
  Pressable,
} from "react-native";
import { useAuth } from "../contexts/AuthContext";

export type VideoLink = {
  src: string;
  channel: string;
  channelNumber: number;
  displayName?: string;
  tags?: string[];
};

interface NavBarProps {
  currentIndex: number;
  videoLinks: VideoLink[];
  onChannelUp: () => void;
  onChannelDown: () => void;
  onSelectChannel: (index: number) => void;
  mobilePanel: "chat" | "pit";
  setMobilePanel: (panel: "chat" | "pit") => void;
  onLoginPress: () => void;
}

const NavBar: React.FC<NavBarProps> = ({
  currentIndex,
  videoLinks,
  onChannelUp,
  onChannelDown,
  onSelectChannel,
  mobilePanel,
  setMobilePanel,
  onLoginPress,
}) => {
  const { user, isAuthenticated, logout } = useAuth();
  const [showHamburger, setShowHamburger] = useState(false);
  const [channelInput, setChannelInput] = useState("");
  const [showSearch, setShowSearch] = useState(false);
  const [showProfile, setShowProfile] = useState(false);

  const currentChannel = videoLinks[currentIndex];
  const placeholderText = currentChannel
    ? `Ch ${currentChannel.channelNumber}${currentChannel.displayName ? ` - ${currentChannel.displayName}` : ""}`
    : "Search...";

  // Simple fuzzy search
  const searchResults = channelInput.trim()
    ? videoLinks
        .map((v, i) => {
          const term = channelInput.trim().toLowerCase();
          const num = parseInt(channelInput, 10);
          if (!isNaN(num) && v.channelNumber === num) return { v, i, score: 1000 };
          if (v.displayName?.toLowerCase().includes(term)) return { v, i, score: 100 };
          if (v.tags?.some((t) => t.toLowerCase().includes(term))) return { v, i, score: 50 };
          return null;
        })
        .filter(Boolean)
        .sort((a, b) => b!.score - a!.score)
    : [];

  return (
    <View style={styles.navbar}>
      {/* Hamburger menu */}
      <TouchableOpacity
        style={styles.hamburger}
        onPress={() => setShowHamburger(!showHamburger)}
      >
        <View style={styles.hamburgerLine} />
        <View style={styles.hamburgerLine} />
        <View style={styles.hamburgerLine} />
      </TouchableOpacity>

      {showHamburger && (
        <View style={styles.hamburgerDropdown}>
          <TouchableOpacity
            style={[styles.hamburgerItem, mobilePanel === "chat" && styles.hamburgerItemActive]}
            onPress={() => { setMobilePanel("chat"); setShowHamburger(false); }}
          >
            <Text style={[styles.hamburgerItemText, mobilePanel === "chat" && styles.hamburgerItemTextActive]}>
              Live Chat
            </Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.hamburgerItem, mobilePanel === "pit" && styles.hamburgerItemActive]}
            onPress={() => { setMobilePanel("pit"); setShowHamburger(false); }}
          >
            <Text style={[styles.hamburgerItemText, mobilePanel === "pit" && styles.hamburgerItemTextActive]}>
              The Pit
            </Text>
          </TouchableOpacity>
        </View>
      )}

      {/* Center controls */}
      <View style={styles.controlPill}>
        {/* Channel arrows */}
        <TouchableOpacity onPress={onChannelDown} style={styles.arrowBtn}>
          <Text style={styles.arrowText}>▼</Text>
        </TouchableOpacity>
        <TouchableOpacity onPress={onChannelUp} style={styles.arrowBtn}>
          <Text style={styles.arrowText}>▲</Text>
        </TouchableOpacity>

        <View style={styles.divider} />

        {/* Search input */}
        <View style={styles.searchContainer}>
          <TextInput
            style={styles.searchInput}
            value={channelInput}
            onChangeText={(t) => { setChannelInput(t); setShowSearch(t.trim().length > 0); }}
            placeholder={placeholderText}
            placeholderTextColor="#888"
            returnKeyType="go"
            onSubmitEditing={() => {
              if (searchResults.length > 0) {
                onSelectChannel(searchResults[0]!.i);
                setChannelInput("");
                setShowSearch(false);
              }
            }}
          />
        </View>
      </View>

      {/* Search dropdown */}
      {showSearch && searchResults.length > 0 && (
        <View style={styles.searchDropdown}>
          {searchResults.slice(0, 6).map((r) => (
            <TouchableOpacity
              key={r!.v.channel}
              style={styles.searchResult}
              onPress={() => {
                onSelectChannel(r!.i);
                setChannelInput("");
                setShowSearch(false);
              }}
            >
              <Text style={styles.searchResultNum}>{r!.v.channelNumber}</Text>
              <Text style={styles.searchResultName} numberOfLines={1}>
                {r!.v.displayName || r!.v.channel}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      )}

      {/* Right: login/profile */}
      {!isAuthenticated ? (
        <TouchableOpacity style={styles.loginBtn} onPress={onLoginPress}>
          <Text style={styles.loginText}>Login</Text>
        </TouchableOpacity>
      ) : (
        <TouchableOpacity style={styles.profileBtn} onPress={() => setShowProfile(!showProfile)}>
          <Text style={styles.profileIcon}>👤</Text>
          {showProfile && (
            <View style={styles.profileDropdown}>
              <Text style={styles.profileName}>{user?.username}</Text>
              <TouchableOpacity onPress={logout}>
                <Text style={styles.logoutText}>Log out</Text>
              </TouchableOpacity>
            </View>
          )}
        </TouchableOpacity>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  navbar: {
    height: 50,
    backgroundColor: "#0d0d1a",
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 8,
    borderBottomWidth: 1,
    borderBottomColor: "#2a2a4a",
    zIndex: 100,
  },
  hamburger: {
    width: 30,
    height: 30,
    justifyContent: "center",
    alignItems: "center",
    marginRight: 6,
  },
  hamburgerLine: {
    width: 18,
    height: 2,
    backgroundColor: "#e0e0e0",
    marginVertical: 1.5,
    borderRadius: 1,
  },
  hamburgerDropdown: {
    position: "absolute",
    top: 46,
    left: 8,
    backgroundColor: "#1a1a2e",
    borderRadius: 8,
    borderWidth: 1,
    borderColor: "#2a2a4a",
    zIndex: 200,
    overflow: "hidden",
    elevation: 10,
  },
  hamburgerItem: {
    paddingVertical: 10,
    paddingHorizontal: 20,
  },
  hamburgerItemActive: {
    backgroundColor: "#2a2a4a",
  },
  hamburgerItemText: {
    color: "#888",
    fontSize: 14,
  },
  hamburgerItemTextActive: {
    color: "#e0e0e0",
    fontWeight: "bold",
  },
  controlPill: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "#1a1a2e",
    borderRadius: 20,
    paddingHorizontal: 6,
    paddingVertical: 4,
    height: 34,
  },
  arrowBtn: {
    paddingHorizontal: 6,
    paddingVertical: 2,
  },
  arrowText: {
    color: "#e0e0e0",
    fontSize: 12,
  },
  divider: {
    width: 1,
    height: 18,
    backgroundColor: "#3a3a5a",
    marginHorizontal: 6,
  },
  searchContainer: {
    flex: 1,
  },
  searchInput: {
    color: "#e0e0e0",
    fontSize: 13,
    height: 26,
    paddingVertical: 0,
    paddingHorizontal: 6,
  },
  searchDropdown: {
    position: "absolute",
    top: 46,
    left: 50,
    right: 60,
    backgroundColor: "#1a1a2e",
    borderRadius: 8,
    borderWidth: 1,
    borderColor: "#2a2a4a",
    zIndex: 200,
    elevation: 10,
  },
  searchResult: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: 8,
    paddingHorizontal: 12,
    borderBottomWidth: 1,
    borderBottomColor: "#2a2a4a",
  },
  searchResultNum: {
    color: "#6a6aff",
    fontWeight: "bold",
    fontSize: 13,
    width: 30,
  },
  searchResultName: {
    color: "#e0e0e0",
    fontSize: 13,
    flex: 1,
  },
  loginBtn: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    backgroundColor: "#2a2a4a",
    borderRadius: 12,
    marginLeft: 8,
  },
  loginText: {
    color: "#e0e0e0",
    fontSize: 13,
  },
  profileBtn: {
    marginLeft: 8,
    position: "relative",
  },
  profileIcon: {
    fontSize: 22,
  },
  profileDropdown: {
    position: "absolute",
    top: 30,
    right: 0,
    backgroundColor: "#1a1a2e",
    borderRadius: 8,
    borderWidth: 1,
    borderColor: "#2a2a4a",
    padding: 12,
    zIndex: 200,
    elevation: 10,
    minWidth: 120,
  },
  profileName: {
    color: "#e0e0e0",
    fontWeight: "bold",
    marginBottom: 8,
  },
  logoutText: {
    color: "#ff6b6b",
    fontSize: 13,
  },
});

export default NavBar;
