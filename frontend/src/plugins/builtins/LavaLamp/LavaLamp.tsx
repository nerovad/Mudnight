import React, { useEffect, useId, useMemo, useRef } from "react";
import type { PluginManifest } from "@cinezoo/shared/plugins";
import type { BuiltinPluginProps } from "../types";
import "./LavaLamp.scss";

export const lavaLampManifest: PluginManifest = {
  id: "mudnight.lava-lamp",
  name: "Lava Lamp",
  version: "1.0.0",
  description: "Molten wax that rises, merges and sinks behind the sidebar.",
  author: "Mudnight",
  category: "theme",
  slot: "sidebar.background",
  policy: "viewer-global",
  settings: [
    { key: "color", label: "Wax color", type: "color", default: "#a259ff" },
    { key: "speed", label: "Speed", type: "number", default: 1, min: 0.25, max: 3, step: 0.05 },
    { key: "opacity", label: "Opacity", type: "number", default: 0.42, min: 0.1, max: 0.9, step: 0.01 },
    { key: "blobs", label: "Blobs", type: "number", default: 6, min: 1, max: 6, step: 1 },
    { key: "glow", label: "Bulb glow", type: "boolean", default: true },
  ],
};

// Each index maps to a .lava-blob--N size/position/tempo variant in
// LavaLamp.scss, largest-impact first so lower counts still look balanced
const BLOB_ORDER = [1, 3, 2, 4, 5, 6] as const;

type Rgb = [number, number, number];

function hexToRgb(hex: string): Rgb {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

// Sass's color.adjust($lightness/$saturation), which the original
// stylesheet used to derive the wax shades from one colour
function adjust([r, g, b]: Rgb, dLight: number, dSat = 0): Rgb {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  let h = 0;
  let s = 0;
  let l = (max + min) / 2;
  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    h = max === r ? (g - b) / d + (g < b ? 6 : 0) : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
    h /= 6;
  }
  l = Math.min(1, Math.max(0, l + dLight / 100));
  s = Math.min(1, Math.max(0, s + dSat / 100));

  const hue = (p: number, q: number, t: number) => {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  };
  if (s === 0) return [l, l, l].map((v) => Math.round(v * 255)) as Rgb;
  const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  const p = 2 * l - q;
  return [hue(p, q, h + 1 / 3), hue(p, q, h), hue(p, q, h - 1 / 3)].map((v) => Math.round(v * 255)) as Rgb;
}

const toHex = (rgb: Rgb) => `#${rgb.map((v) => v.toString(16).padStart(2, "0")).join("")}`;

const LavaLamp: React.FC<BuiltinPluginProps> = ({ settings, active }) => {
  const root = useRef<HTMLDivElement>(null);
  // Per instance, so a preview and the sidebar can both be on screen
  const filterId = `lava-goo-${useId().replace(/[^a-zA-Z0-9]/g, "")}`;

  const blobCount = Math.round(Number(settings.blobs ?? 6));
  const style = useMemo(() => {
    const body = hexToRgb(String(settings.color ?? "#a259ff"));
    const core = adjust(body, 20);
    const shade = adjust(body, -24, -10);
    return {
      "--lava-core": toHex(core),
      "--lava-body": toHex(body),
      "--lava-shade": toHex(shade),
      "--lava-core-rgb": core.join(", "),
      "--lava-body-rgb": body.join(", "),
      "--lava-speed": String(settings.speed ?? 1),
      "--lava-opacity": String(settings.opacity ?? 0.42),
    } as React.CSSProperties;
  }, [settings.color, settings.speed, settings.opacity]);

  // Drop each blob at a random point in its own cycle the first time the
  // lamp is shown, so it never looks like it just started up. Runs once per
  // blob — re-rolling on every open would visibly teleport the wax.
  useEffect(() => {
    if (!active || !root.current) return;
    root.current.querySelectorAll<HTMLElement>(".lava-blob:not([data-seeded])").forEach((blob) => {
      // A negative delay starts the animation already in progress
      const duration = parseFloat(getComputedStyle(blob).animationDuration) || 24;
      blob.style.setProperty("--delay", `${-Math.random() * duration}s`);
      blob.dataset.seeded = "";
    });
  }, [active, blobCount]);

  return (
    <div ref={root} className={`lava-lamp-bg ${active ? "is-active" : ""}`} style={style} aria-hidden="true">
      {/* Goo filter: blur, then crush the alpha ramp back to a hard edge.
          Blobs that overlap after blurring fuse into one silhouette, which
          is what gives the wax its surface tension. */}
      <svg className="lava-defs" aria-hidden="true" focusable="false">
        <defs>
          <filter id={filterId}>
            <feGaussianBlur in="SourceGraphic" stdDeviation="12" result="blur" />
            <feColorMatrix
              in="blur"
              mode="matrix"
              values="1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 24 -10"
            />
          </filter>
        </defs>
      </svg>

      {settings.glow !== false && <div className="lava-glow" />}

      <div className="lava-goo" style={{ filter: `url(#${filterId}) blur(2px)` }}>
        <div className="lava-pool" />
        <div className="lava-cap" />
        {BLOB_ORDER.slice(0, blobCount).map((n) => (
          <div key={n} className={`lava-blob lava-blob--${n}`} />
        ))}
      </div>
    </div>
  );
};

export default LavaLamp;
