// Thin wrapper around the self-hosted Umami tracker.
//
// The tracker is only loaded when both env vars are set, so local dev and any
// build made without them stay completely silent — no script fetched, no
// events sent. Every export below degrades to a no-op in that case, which
// means callers never have to guard.

declare global {
  interface Window {
    umami?: {
      track: {
        (eventName: string, eventData?: Record<string, unknown>): void;
        (payload: Record<string, unknown>): void;
      };
    };
  }
}

const SCRIPT_URL = import.meta.env.VITE_UMAMI_SCRIPT_URL ?? "";
const WEBSITE_ID = import.meta.env.VITE_UMAMI_WEBSITE_ID ?? "";

export const analyticsEnabled = Boolean(SCRIPT_URL && WEBSITE_ID);

/**
 * Inject the tracker script. Safe to call more than once.
 *
 * Auto-tracking is deliberately OFF. Umami's default behaviour patches
 * history.pushState/replaceState, and every channel flip in this app is a
 * `navigate(..., { replace: true })` — so holding the channel-up key would
 * log dozens of pageviews a minute. We send pageviews by hand instead, once
 * a viewer has actually settled on a channel. See usePageviews.
 */
export function initAnalytics(): void {
  if (!analyticsEnabled) return;
  if (document.querySelector("script[data-website-id]")) return;

  const script = document.createElement("script");
  script.async = true;
  script.defer = true;
  script.src = SCRIPT_URL;
  script.setAttribute("data-website-id", WEBSITE_ID);
  script.setAttribute("data-auto-track", "false");
  document.head.appendChild(script);
}

/** Record a custom event. No-ops if the tracker is disabled or blocked. */
export function track(eventName: string, eventData?: Record<string, unknown>): void {
  if (!analyticsEnabled) return;
  try {
    window.umami?.track(eventName, eventData);
  } catch {
    // Analytics must never break playback.
  }
}

/** Record a pageview for `url`. No-ops if the tracker is disabled or blocked. */
export function trackPageview(url: string): void {
  if (!analyticsEnabled) return;
  try {
    window.umami?.track({
      website: WEBSITE_ID,
      url,
      title: document.title,
      referrer: document.referrer,
    });
  } catch {
    // Analytics must never break playback.
  }
}
