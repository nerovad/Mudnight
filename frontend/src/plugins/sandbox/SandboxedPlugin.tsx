import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { PluginManifest, PluginSlotId, SettingsValues } from "@cinezoo/shared/plugins";
import { SDK_VERSION, buildSrcdoc } from "./runtime";

// Host side of the plugin sandbox (the plugin side is in runtime.ts).
//
// The iframe gets sandbox="allow-scripts" only: no same-origin, forms,
// popups, top navigation or modals. Every message from it is checked to come
// from this frame, and requests are answered only for permissions its
// manifest declared.

const STORAGE_LIMIT_BYTES = 64 * 1024;
const MIN_HEIGHT = 24;
const MAX_HEIGHT = 800;

interface Props {
  manifest: PluginManifest;
  code: string;
  settings: SettingsValues;
  slot: PluginSlotId;
  channelSlug: string | null;
  active: boolean;
  className?: string;
}

const storageKey = (pluginId: string) => `mudnight.plugin-storage.${pluginId}`;

function readStore(pluginId: string): Record<string, unknown> {
  try {
    return JSON.parse(localStorage.getItem(storageKey(pluginId)) || "{}");
  } catch {
    return {};
  }
}

function prefersReducedMotion() {
  return typeof window !== "undefined" && window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
}

const SandboxedPlugin: React.FC<Props> = ({ manifest, code, settings, slot, channelSlug, active, className }) => {
  const frame = useRef<HTMLIFrameElement>(null);
  const loads = useRef(0);
  const [ready, setReady] = useState(false);
  const [height, setHeight] = useState<number | null>(null);
  const [failure, setFailure] = useState<string | null>(null);

  const srcDoc = useMemo(() => buildSrcdoc(code), [code]);
  const permissions = useMemo(() => new Set(manifest.permissions ?? []), [manifest.permissions]);
  const channel = permissions.has("channel:read") && channelSlug ? { slug: channelSlug } : null;

  // Latest values for the message handler without re-binding it
  const latest = useRef({ settings, channel, active });
  latest.current = { settings, channel, active };

  const post = useCallback((msg: Record<string, unknown>) => {
    frame.current?.contentWindow?.postMessage({ ...msg, __mudnight: SDK_VERSION }, "*");
  }, []);

  // A fresh document means a fresh handshake
  useEffect(() => {
    setReady(false);
    setFailure(null);
    loads.current = 0;
  }, [srcDoc]);

  useEffect(() => {
    const onMessage = (e: MessageEvent) => {
      if (!frame.current || e.source !== frame.current.contentWindow) return;
      const m = e.data;
      if (!m || m.__mudnight !== SDK_VERSION) return;

      switch (m.type) {
        case "hello":
          post({
            type: "init",
            context: {
              pluginId: manifest.id,
              version: manifest.version,
              slot,
              permissions: [...permissions],
              settings: latest.current.settings,
              channel: latest.current.channel,
              active: latest.current.active,
              reducedMotion: prefersReducedMotion(),
            },
          });
          setReady(true);
          break;
        case "resize":
          if (slot !== "sidebar.background") {
            setHeight(Math.min(MAX_HEIGHT, Math.max(MIN_HEIGHT, Math.round(Number(m.height) || 0))));
          }
          break;
        case "error":
          console.warn(`[plugin ${manifest.id}]`, m.message);
          break;
        case "request":
          handleRequest(m.id, String(m.method), m.params ?? {});
          break;
      }
    };

    const handleRequest = (id: number, method: string, params: Record<string, unknown>) => {
      const reply = (result?: unknown, error?: string) => post({ type: "response", id, result, error });

      if (method.startsWith("storage.")) {
        if (!permissions.has("storage")) return reply(undefined, 'This plugin needs the "storage" permission');
        const key = String(params.key ?? "");
        if (!key) return reply(undefined, "storage key is required");
        const store = readStore(manifest.id);
        if (method === "storage.get") return reply(store[key] ?? null);
        if (method === "storage.remove") delete store[key];
        if (method === "storage.set") store[key] = params.value;
        try {
          const json = JSON.stringify(store);
          if (json.length > STORAGE_LIMIT_BYTES) return reply(undefined, "plugin storage is full (64 KB)");
          localStorage.setItem(storageKey(manifest.id), json);
          return reply(true);
        } catch {
          return reply(undefined, "storage is unavailable");
        }
      }

      reply(undefined, `unknown method ${method}`);
    };

    window.addEventListener("message", onMessage);
    return () => window.removeEventListener("message", onMessage);
  }, [manifest.id, manifest.version, permissions, post, slot]);

  // Push changes after the handshake
  useEffect(() => { if (ready) post({ type: "event", event: "settings", data: settings }); }, [ready, settings, post]);
  useEffect(() => { if (ready) post({ type: "event", event: "active", data: active }); }, [ready, active, post]);
  useEffect(() => {
    if (ready) post({ type: "event", event: "channel", data: channel });
    // channel is rebuilt each render; its slug is what matters
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ready, channel?.slug, post]);

  useEffect(() => {
    const mq = window.matchMedia?.("(prefers-reduced-motion: reduce)");
    if (!mq || !ready) return;
    const onChange = () => post({ type: "event", event: "reducedMotion", data: mq.matches });
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, [ready, post]);

  // srcdoc loads exactly once. A second load means the plugin navigated its
  // frame somewhere else, which no plugin has a reason to do, so it's removed.
  const onLoad = () => {
    loads.current += 1;
    if (loads.current > 1) setFailure("This plugin tried to leave its sandbox and was stopped.");
  };

  if (failure) {
    return slot === "sidebar.background" ? null : <div className="plugin-failure">{failure}</div>;
  }

  return (
    <iframe
      ref={frame}
      className={className}
      title={manifest.name}
      srcDoc={srcDoc}
      sandbox="allow-scripts"
      allow=""
      referrerPolicy="no-referrer"
      onLoad={onLoad}
      style={height != null ? { height } : undefined}
      // Backgrounds are decoration only
      aria-hidden={slot === "sidebar.background" ? true : undefined}
      tabIndex={slot === "sidebar.background" ? -1 : undefined}
    />
  );
};

export default SandboxedPlugin;
