/// <reference path="../sdk/mudnight.d.ts" />
// Aurora: a starter theme plugin. Upload this file with manifest.json from
// the Build tab of the Plugins panel, or copy it as the base for your own.
//
// It runs in a sandboxed iframe that fills the sidebar, with `mudnight` (the
// SDK) as its only connection to the site. See docs/plugins.md.

const canvas = document.createElement("canvas");
canvas.style.cssText = "position:fixed;inset:0;width:100%;height:100%";
document.body.appendChild(canvas);
const g = canvas.getContext("2d");

let settings = {};
let active = false;
let reducedMotion = false;
let frame = 0;
let t = 0;

function hexToRgb(hex) {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

function fit() {
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  canvas.width = Math.round(innerWidth * dpr);
  canvas.height = Math.round(innerHeight * dpr);
  g.setTransform(dpr, 0, 0, dpr, 0, 0);
  draw();
}

function ribbon(rgb, phase, yBase, alpha) {
  const w = innerWidth;
  const h = innerHeight;
  const grad = g.createLinearGradient(0, yBase - h * 0.25, 0, yBase + h * 0.25);
  grad.addColorStop(0, `rgba(${rgb}, 0)`);
  grad.addColorStop(0.5, `rgba(${rgb}, ${alpha})`);
  grad.addColorStop(1, `rgba(${rgb}, 0)`);
  g.fillStyle = grad;
  g.beginPath();
  g.moveTo(0, h);
  for (let x = 0; x <= w; x += 8) {
    const y = yBase + Math.sin(x / 70 + t * 0.6 + phase) * 26 + Math.sin(x / 31 - t * 0.35 + phase * 2) * 12;
    g.lineTo(x, y);
  }
  g.lineTo(w, h);
  g.closePath();
  g.fill();
}

function draw() {
  const h = innerHeight;
  const a = hexToRgb(settings.colorA || "#3cf0c5").join(", ");
  const b = hexToRgb(settings.colorB || "#a259ff").join(", ");
  const k = Number(settings.intensity ?? 0.45);
  g.clearRect(0, 0, innerWidth, h);
  g.globalCompositeOperation = "lighter";
  ribbon(a, 0, h * 0.3, k);
  ribbon(b, 2.1, h * 0.55, k * 0.8);
  ribbon(a, 4.2, h * 0.8, k * 0.6);
  g.globalCompositeOperation = "source-over";
}

function loop() {
  t += 0.016 * Number(settings.speed ?? 1);
  draw();
  frame = requestAnimationFrame(loop);
}

// Only animate while the sidebar is open and the viewer is fine with motion
function sync() {
  cancelAnimationFrame(frame);
  if (active && !reducedMotion) frame = requestAnimationFrame(loop);
  else draw();
}

mudnight.ready((ctx) => {
  settings = ctx.settings;
  active = ctx.active;
  reducedMotion = ctx.reducedMotion;
  fit();
  sync();
});

mudnight.on("settings", (s) => { settings = s; draw(); });
mudnight.on("active", (a) => { active = a; sync(); });
mudnight.on("reducedMotion", (r) => { reducedMotion = r; sync(); });
addEventListener("resize", fit);
