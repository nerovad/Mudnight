import React from "react";
import { View, Text, StyleSheet, StatusBar } from "react-native";

export default function App() {
  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="#0d0d1a" />
      <Text style={styles.title}>Cinezoo Mobile</Text>
      <Text style={styles.subtitle}>If you see this, the bundle works!</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#0d0d1a",
    alignItems: "center",
    justifyContent: "center",
  },
  title: {
    fontSize: 28,
    fontWeight: "bold",
    color: "#e0e0e0",
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 16,
    color: "#888",
  },
});
