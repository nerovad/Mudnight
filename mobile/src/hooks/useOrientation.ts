import { useState, useEffect } from "react";
import * as ScreenOrientation from "expo-screen-orientation";

export type Orientation = "PORTRAIT" | "LANDSCAPE";

export function useOrientation(): Orientation {
  const [orientation, setOrientation] = useState<Orientation>("PORTRAIT");

  useEffect(() => {
    // Get initial orientation
    ScreenOrientation.getOrientationAsync().then((o) => {
      setOrientation(isLandscape(o) ? "LANDSCAPE" : "PORTRAIT");
    });

    // Listen for changes
    const sub = ScreenOrientation.addOrientationChangeListener((event) => {
      setOrientation(
        isLandscape(event.orientationInfo.orientation) ? "LANDSCAPE" : "PORTRAIT"
      );
    });

    return () => ScreenOrientation.removeOrientationChangeListener(sub);
  }, []);

  return orientation;
}

function isLandscape(o: ScreenOrientation.Orientation): boolean {
  return (
    o === ScreenOrientation.Orientation.LANDSCAPE_LEFT ||
    o === ScreenOrientation.Orientation.LANDSCAPE_RIGHT
  );
}
