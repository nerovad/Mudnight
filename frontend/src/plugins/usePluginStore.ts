import { useEffect, useMemo } from "react";
import { create } from "zustand";
import {
  EMPTY_PREFS,
  resolvePlugins,
  type PluginInstall,
  type PluginManifest,
  type ResolvedPlugin,
  type ViewerPluginPrefs,
} from "@cinezoo/shared/plugins";
import { BUILTIN_PLUGINS, DEFAULT_INSTALLS } from "./builtins";

export interface CatalogEntry {
  id: string;
  manifest: PluginManifest;
  builtin: boolean;
  // Shows up when browsing (built-ins, public plugins, your own). Unlisted
  // plugins still load when a channel or your prefs reference them.
  listed: boolean;
  dbId?: number;
  visibility?: "unlisted" | "public";
  author?: string;
  mine?: boolean;
}

interface ServerPlugin {
  id: string;
  db_id: number;
  manifest: PluginManifest;
  visibility: "unlisted" | "public";
  author: string;
  mine: boolean;
  code?: string;
}

const LOCAL_PREFS_KEY = "mudnight.plugin-prefs";

function readLocalPrefs(): ViewerPluginPrefs {
  try {
    const p = JSON.parse(localStorage.getItem(LOCAL_PREFS_KEY) || "null");
    return p && typeof p === "object" ? { global: p.global ?? {}, channels: p.channels ?? {} } : EMPTY_PREFS;
  } catch {
    return EMPTY_PREFS;
  }
}

function writeLocalPrefs(prefs: ViewerPluginPrefs) {
  try {
    localStorage.setItem(LOCAL_PREFS_KEY, JSON.stringify(prefs));
  } catch { /* private mode etc. — prefs just won't persist */ }
}

async function api<T>(path: string, token: string | null, init: RequestInit = {}): Promise<T> {
  const res = await fetch(path, {
    ...init,
    headers: {
      ...(init.body ? { "Content-Type": "application/json" } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...init.headers,
    },
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || `Request failed (${res.status})`);
  return data as T;
}

const fromServer = (p: ServerPlugin, listed: boolean): CatalogEntry => ({
  id: p.id,
  manifest: p.manifest,
  builtin: false,
  listed,
  dbId: p.db_id,
  visibility: p.visibility,
  author: p.author,
  mine: p.mine,
});

const builtinCatalog = (): Record<string, CatalogEntry> =>
  Object.fromEntries(
    Object.values(BUILTIN_PLUGINS).map((b) => [b.manifest.id, { id: b.manifest.id, manifest: b.manifest, builtin: true, listed: true }])
  );

interface PluginState {
  token: string | null;
  catalog: Record<string, CatalogEntry>;
  code: Record<string, string>;
  channelSlug: string | null;
  channelOwnerId: number | null;
  channelInstalls: PluginInstall[];
  prefs: ViewerPluginPrefs;

  setToken: (token: string | null) => void;
  loadCatalog: () => Promise<void>;
  loadChannel: (slug: string | null) => Promise<void>;
  loadPrefs: () => Promise<void>;
  updatePrefs: (update: (prefs: ViewerPluginPrefs) => ViewerPluginPrefs) => void;
  saveChannelInstalls: (installs: PluginInstall[]) => Promise<void>;
  ensureCode: (ids: string[]) => Promise<void>;
  upload: (manifest: unknown, code: string, visibility: "unlisted" | "public") => Promise<CatalogEntry>;
  setVisibility: (entry: CatalogEntry, visibility: "unlisted" | "public") => Promise<void>;
  remove: (entry: CatalogEntry) => Promise<void>;
}

let prefsSaveTimer: ReturnType<typeof setTimeout> | undefined;

export const usePluginStore = create<PluginState>((set, get) => ({
  token: null,
  catalog: builtinCatalog(),
  code: {},
  channelSlug: null,
  channelOwnerId: null,
  channelInstalls: [],
  prefs: readLocalPrefs(),

  setToken: (token) => set({ token }),

  loadCatalog: async () => {
    try {
      const list = await api<ServerPlugin[]>("/api/plugins", get().token);
      set((s) => {
        // Keep unlisted entries we already pulled in for a channel
        const kept = Object.fromEntries(Object.entries(s.catalog).filter(([, e]) => !e.builtin && !e.listed));
        return { catalog: { ...kept, ...builtinCatalog(), ...Object.fromEntries(list.map((p) => [p.id, fromServer(p, true)])) } };
      });
    } catch (e) {
      console.warn("Couldn't load plugins", e);
    }
  },

  loadChannel: async (slug) => {
    set({ channelSlug: slug, channelOwnerId: null, channelInstalls: [] });
    if (!slug) return;
    try {
      const data = await api<{ owner_id: number | null; plugins: PluginInstall[] }>(
        `/api/channels/${encodeURIComponent(slug)}/plugins`,
        null
      );
      if (get().channelSlug === slug) set({ channelOwnerId: data.owner_id, channelInstalls: data.plugins ?? [] });
    } catch {
      // Unknown channel or offline: defaults only
    }
  },

  loadPrefs: async () => {
    const { token } = get();
    if (!token) return set({ prefs: readLocalPrefs() });
    try {
      set({ prefs: await api<ViewerPluginPrefs>("/api/plugin-prefs", token) });
    } catch {
      set({ prefs: readLocalPrefs() });
    }
  },

  updatePrefs: (update) => {
    const prefs = update(get().prefs);
    set({ prefs });
    writeLocalPrefs(prefs);
    const { token } = get();
    if (!token) return;
    clearTimeout(prefsSaveTimer);
    prefsSaveTimer = setTimeout(() => {
      api("/api/plugin-prefs", token, { method: "PUT", body: JSON.stringify(prefs) }).catch((e) =>
        console.warn("Couldn't save plugin prefs", e)
      );
    }, 400);
  },

  saveChannelInstalls: async (installs) => {
    const { channelSlug, token } = get();
    if (!channelSlug) return;
    const data = await api<{ plugins: PluginInstall[] }>(`/api/channels/${encodeURIComponent(channelSlug)}/plugins`, token, {
      method: "PUT",
      body: JSON.stringify({ plugins: installs }),
    });
    set({ channelInstalls: data.plugins });
  },

  ensureCode: async (ids) => {
    const { code, catalog } = get();
    const missing = [...new Set(ids)].filter((id) => !BUILTIN_PLUGINS[id] && !(id in code));
    if (!missing.length) return;
    try {
      const bundles = await api<ServerPlugin[]>(`/api/plugins/bundle?ids=${encodeURIComponent(missing.join(","))}`, null);
      set((s) => ({
        code: { ...s.code, ...Object.fromEntries(bundles.map((b) => [b.id, b.code ?? ""])) },
        catalog: {
          ...s.catalog,
          ...Object.fromEntries(
            bundles.map((b) => [b.id, { ...fromServer(b, catalog[b.id]?.listed ?? false), mine: catalog[b.id]?.mine ?? false }])
          ),
        },
      }));
    } catch (e) {
      console.warn("Couldn't load plugin code", e);
    }
  },

  upload: async (manifest, code, visibility) => {
    const saved = await api<ServerPlugin>("/api/plugins", get().token, {
      method: "POST",
      body: JSON.stringify({ manifest, code, visibility }),
    });
    const entry = fromServer(saved, true);
    set((s) => ({ catalog: { ...s.catalog, [entry.id]: entry }, code: { ...s.code, [entry.id]: code } }));
    return entry;
  },

  setVisibility: async (entry, visibility) => {
    const saved = await api<ServerPlugin>(`/api/plugins/${entry.dbId}`, get().token, {
      method: "PATCH",
      body: JSON.stringify({ visibility }),
    });
    set((s) => ({ catalog: { ...s.catalog, [entry.id]: { ...s.catalog[entry.id], visibility: saved.visibility } } }));
  },

  remove: async (entry) => {
    await api(`/api/plugins/${entry.dbId}`, get().token, { method: "DELETE" });
    set((s) => {
      const catalog = { ...s.catalog };
      delete catalog[entry.id];
      return { catalog };
    });
  },
}));

// Mount once (in the sidebar): keeps the store in step with who's signed in
// and which channel is on screen, and fetches code for every uploaded plugin
// the channel or the viewer's prefs refer to.
export function usePluginRuntime(token: string | null, channelSlug: string | null) {
  const { setToken, loadCatalog, loadPrefs, loadChannel, ensureCode, channelInstalls, prefs } = usePluginStore();

  useEffect(() => {
    setToken(token);
    loadCatalog();
    loadPrefs();
  }, [token, setToken, loadCatalog, loadPrefs]);

  useEffect(() => {
    loadChannel(channelSlug);
  }, [channelSlug, loadChannel]);

  const referenced = useMemo(() => {
    const ids = new Set(channelInstalls.map((i) => i.id));
    Object.keys(prefs.global).forEach((id) => ids.add(id));
    if (channelSlug) Object.keys(prefs.channels[channelSlug] ?? {}).forEach((id) => ids.add(id));
    return [...ids].sort().join(",");
  }, [channelInstalls, prefs, channelSlug]);

  useEffect(() => {
    if (referenced) ensureCode(referenced.split(","));
  }, [referenced, ensureCode]);
}

// Everything active on the current channel for this viewer, after layering
export function useResolvedPlugins(): ResolvedPlugin[] {
  const { catalog, channelInstalls, prefs, channelSlug } = usePluginStore();
  return useMemo(() => {
    const manifests = Object.fromEntries(Object.values(catalog).map((e) => [e.id, e.manifest]));
    return resolvePlugins({ manifests, defaults: DEFAULT_INSTALLS, channel: channelInstalls, viewer: prefs, channelSlug });
  }, [catalog, channelInstalls, prefs, channelSlug]);
}
