import { useEffect, useRef } from "react";
import { useLocation } from "react-router-dom";
import { analyticsEnabled, track, trackPageview } from "./umami";

/**
 * How long a viewer has to stay put before the route counts as a pageview.
 * Channel surfing generates a route change per flip; without this threshold a
 * single pass up the dial would register as ~100 views and the numbers would
 * be worthless to anyone buying against them.
 */
const PAGEVIEW_DWELL_MS = 3_000;

/** One heartbeat == one minute watched, by one viewer, with the tab visible. */
const HEARTBEAT_INTERVAL_MS = 60_000;

/**
 * Send a pageview once the viewer has settled on a route for PAGEVIEW_DWELL_MS.
 * Must be rendered inside the Router.
 */
export function usePageviews(): void {
  const location = useLocation();
  const url = location.pathname + location.search;

  useEffect(() => {
    if (!analyticsEnabled) return;
    const timer = window.setTimeout(() => trackPageview(url), PAGEVIEW_DWELL_MS);
    return () => window.clearTimeout(timer);
  }, [url]);
}

/**
 * Emit a heartbeat every minute the tab is visible.
 *
 * This is the number that sells sponsorship. Umami's built-in realtime view
 * only ever shows *right now*; counting heartbeats gives the historical shape:
 *
 *   viewer-minutes in a period      = heartbeat events in that period
 *   average concurrent viewers      = heartbeats in an hour / 60
 *
 * Heartbeats stop while the tab is hidden, so a forgotten background tab does
 * not inflate the figure. That understates slightly — audio-only listening in
 * a background tab is real viewing that goes uncounted — but a number a buyer
 * can trust is worth more than a flattering one.
 */
export function useViewingHeartbeat(channel: string | undefined): void {
  // Held in a ref so a channel flip doesn't tear down and restart the
  // interval — a viewer flipping every 45s would otherwise never tick over
  // the one-minute mark and would register as zero watch time.
  const channelRef = useRef(channel);
  channelRef.current = channel;

  useEffect(() => {
    if (!analyticsEnabled) return;

    let timer: number | undefined;

    const stop = () => {
      if (timer !== undefined) {
        window.clearInterval(timer);
        timer = undefined;
      }
    };

    const start = () => {
      if (timer !== undefined) return;
      timer = window.setInterval(() => {
        track("heartbeat", { channel: channelRef.current ?? "unknown" });
      }, HEARTBEAT_INTERVAL_MS);
    };

    const sync = () => (document.visibilityState === "visible" ? start() : stop());

    sync();
    document.addEventListener("visibilitychange", sync);
    return () => {
      stop();
      document.removeEventListener("visibilitychange", sync);
    };
  }, []);
}

/**
 * Record each channel change along with how long the previous channel held the
 * viewer. Gives per-channel stickiness, which is what makes individual channel
 * sponsorships priceable — and shows which channels are pass-throughs.
 */
export function useChannelDwell(channel: string | undefined): void {
  const previous = useRef<{ channel: string; enteredAt: number } | null>(null);

  useEffect(() => {
    if (!analyticsEnabled || !channel) return;

    const now = Date.now();
    const last = previous.current;

    if (last && last.channel !== channel) {
      track("channel-change", {
        from: last.channel,
        to: channel,
        dwellSeconds: Math.round((now - last.enteredAt) / 1000),
      });
    }

    previous.current = { channel, enteredAt: now };
  }, [channel]);
}
