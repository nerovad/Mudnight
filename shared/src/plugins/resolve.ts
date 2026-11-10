import type {
  PluginInstall,
  PluginManifest,
  PluginOverride,
  PluginSlotId,
  PluginSource,
  ResolvedPlugin,
  SettingField,
  SettingsValues,
  SettingValue,
  ViewerPluginPrefs,
} from "./types";
import { SLOTS } from "./types";

const HEX_COLOR = /^#[0-9a-f]{6}$/i;

function coerce(field: SettingField, value: unknown): SettingValue {
  switch (field.type) {
    case "color":
      return typeof value === "string" && HEX_COLOR.test(value) ? value : field.default;
    case "number": {
      const n = typeof value === "number" ? value : Number(value);
      if (!Number.isFinite(n)) return field.default;
      const lo = field.min ?? -Infinity;
      const hi = field.max ?? Infinity;
      return Math.min(hi, Math.max(lo, n));
    }
    case "boolean":
      return typeof value === "boolean" ? value : field.default;
    case "select":
      return field.options.some((o) => o.value === value) ? (value as string) : field.default;
    case "text":
      return typeof value === "string" ? value.slice(0, field.maxLength ?? 200) : field.default;
  }
}

// Manifest defaults overlaid with each layer's values, every value checked
// against its field so nothing a layer stored can reach a plugin malformed.
// Keys the manifest doesn't declare are dropped.
export function resolveSettings(manifest: PluginManifest, ...layers: (SettingsValues | undefined)[]): SettingsValues {
  const out: SettingsValues = {};
  for (const field of manifest.settings ?? []) {
    let value: unknown = field.default;
    for (const layer of layers) {
      if (layer && field.key in layer) value = layer[field.key];
    }
    out[field.key] = coerce(field, value);
  }
  return out;
}

interface Entry {
  id: string;
  enabled: boolean;
  settingsLayers: (SettingsValues | undefined)[];
  source: PluginSource;
  // Higher wins an exclusive slot: 0 default, 1 channel, 2 viewer global,
  // 3 viewer per-channel
  rank: number;
  // The channel creator turned it on, so additive plugins are fixed
  channelOwned: boolean;
  order: number;
}

export interface ResolveInput {
  manifests: Record<string, PluginManifest>;
  // Platform defaults, e.g. the lava lamp, so a channel with no config still
  // looks the way it always has
  defaults: PluginInstall[];
  channel: PluginInstall[];
  viewer: ViewerPluginPrefs;
  channelSlug: string | null;
}

// Layers, lowest first: platform defaults, the channel creator's config, the
// viewer's global prefs, the viewer's prefs for this channel. Each plugin's
// policy decides which viewer layers it listens to.
export function resolvePlugins({ manifests, defaults, channel, viewer, channelSlug }: ResolveInput): ResolvedPlugin[] {
  const entries = new Map<string, Entry>();
  let order = 0;

  const applyInstall = (install: PluginInstall, rank: number, source: PluginSource) => {
    if (!manifests[install.id]) return;
    const prev = entries.get(install.id);
    entries.set(install.id, {
      id: install.id,
      enabled: install.enabled,
      settingsLayers: [...(prev?.settingsLayers ?? []), install.settings],
      source: install.enabled ? source : prev?.source ?? source,
      rank: install.enabled ? rank : prev?.rank ?? rank,
      channelOwned: source === "channel" ? install.enabled : prev?.channelOwned ?? false,
      order: prev?.order ?? order++,
    });
  };

  const applyOverrides = (overrides: Record<string, PluginOverride> | undefined, rank: number) => {
    for (const [id, override] of Object.entries(overrides ?? {})) {
      const manifest = manifests[id];
      if (!manifest || manifest.policy === "locked") continue;
      const prev = entries.get(id);
      if (manifest.policy === "additive" && prev?.channelOwned) continue;

      const enabled = override.enabled ?? prev?.enabled ?? false;
      const turnedOn = override.enabled === true;
      entries.set(id, {
        id,
        enabled,
        settingsLayers: [...(prev?.settingsLayers ?? []), override.settings],
        source: turnedOn ? "viewer" : prev?.source ?? "viewer",
        rank: turnedOn ? rank : prev?.rank ?? rank,
        channelOwned: prev?.channelOwned ?? false,
        order: prev?.order ?? order++,
      });
    }
  };

  defaults.forEach((d) => applyInstall(d, 0, "default"));
  channel.forEach((c) => applyInstall(c, 1, "channel"));
  applyOverrides(viewer.global, 2);
  if (channelSlug) applyOverrides(viewer.channels[channelSlug], 3);

  const enabled = [...entries.values()].filter((e) => e.enabled).sort((a, b) => a.order - b.order);

  // Exclusive slots keep one plugin: a channel's locked plugin if it has one,
  // otherwise whichever layer most recently turned something on
  const winners = new Map<PluginSlotId, Entry>();
  for (const e of enabled) {
    const slot = manifests[e.id].slot;
    if (!SLOTS[slot]?.exclusive) continue;
    const current = winners.get(slot);
    const locked = (x: Entry) => manifests[x.id].policy === "locked";
    if (!current || (locked(e) && !locked(current)) || (locked(e) === locked(current) && e.rank >= current.rank)) {
      winners.set(slot, e);
    }
  }

  return enabled
    .filter((e) => {
      const slot = manifests[e.id].slot;
      return !SLOTS[slot]?.exclusive || winners.get(slot) === e;
    })
    .map((e) => {
      const manifest = manifests[e.id];
      return {
        id: e.id,
        manifest,
        settings: resolveSettings(manifest, ...e.settingsLayers),
        source: e.source,
        viewerCanChange:
          manifest.policy === "viewer-global" || (manifest.policy === "additive" && !e.channelOwned),
      };
    });
}
