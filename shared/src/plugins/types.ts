// Plugin system types, shared by the web client (and later mobile).
//
// A plugin is a manifest plus an implementation. Built-in plugins ship with
// the client as React components; everyone else's run as sandboxed code (see
// docs/plugins.md). The manifest is what the rest of the site reasons about:
// where the plugin renders (slot), what it is (category), and how much a
// viewer may change it (policy).

export type PluginCategory = "theme" | "widget" | "chat" | "player" | "overlay";

// Places in the UI a plugin can render. Only the sidebar slots are rendered
// so far; new slots get added here and in SLOTS below.
export type PluginSlotId = "sidebar.background" | "sidebar.section";

// How far a viewer can change a plugin:
//   viewer-global  The viewer's choice wins, and can follow them to every
//                  channel. Required for themes: they're cosmetic, so a
//                  viewer can never break a channel by changing one.
//   additive       The creator's installs are fixed; viewers may add their
//                  own copies on top (globally or per channel).
//   locked         Only the channel creator decides. For anything the
//                  channel depends on to work.
export type PluginPolicy = "viewer-global" | "additive" | "locked";

// What a sandboxed plugin may ask the host for. Nothing is granted unless
// it's listed in the manifest.
export type PluginPermission = "channel:read" | "storage";

export type SettingValue = string | number | boolean;
export type SettingsValues = Record<string, SettingValue>;

interface FieldBase {
  key: string;
  label: string;
  help?: string;
}

export type SettingField =
  | (FieldBase & { type: "color"; default: string })
  | (FieldBase & { type: "number"; default: number; min?: number; max?: number; step?: number })
  | (FieldBase & { type: "boolean"; default: boolean })
  | (FieldBase & { type: "select"; default: string; options: { value: string; label: string }[] })
  | (FieldBase & { type: "text"; default: string; maxLength?: number });

export interface PluginManifest {
  // Built-ins: "mudnight.<name>". Uploaded: "@<username>/<name>" (the server
  // prefixes the author's username to whatever name they upload with).
  id: string;
  name: string;
  version: string;
  description?: string;
  author?: string;
  category: PluginCategory;
  slot: PluginSlotId;
  policy: PluginPolicy;
  settings?: SettingField[];
  permissions?: PluginPermission[];
}

// One plugin as configured by a channel creator (stored in channels.plugins)
export interface PluginInstall {
  id: string;
  enabled: boolean;
  settings?: SettingsValues;
}

// A viewer's change to one plugin. Missing fields inherit from the layer below.
export interface PluginOverride {
  enabled?: boolean;
  settings?: SettingsValues;
}

export interface ViewerPluginPrefs {
  // Applies on every channel
  global: Record<string, PluginOverride>;
  // Per channel slug; wins over global
  channels: Record<string, Record<string, PluginOverride>>;
}

export type PluginSource = "default" | "channel" | "viewer";

export interface ResolvedPlugin {
  id: string;
  manifest: PluginManifest;
  settings: SettingsValues;
  // Which layer turned it on
  source: PluginSource;
  // Whether the viewer is allowed to turn it off or change its settings
  viewerCanChange: boolean;
}

export interface SlotDefinition {
  id: PluginSlotId;
  label: string;
  // Only one plugin renders at a time (e.g. a background)
  exclusive: boolean;
  categories: PluginCategory[];
}

export const SLOTS: Record<PluginSlotId, SlotDefinition> = {
  "sidebar.background": {
    id: "sidebar.background",
    label: "Sidebar background",
    exclusive: true,
    categories: ["theme"],
  },
  "sidebar.section": {
    id: "sidebar.section",
    label: "Sidebar section",
    exclusive: false,
    categories: ["widget", "chat", "player", "overlay"],
  },
};

export const CATEGORY_LABELS: Record<PluginCategory, string> = {
  theme: "Themes",
  widget: "Widgets",
  chat: "Chat",
  player: "Player",
  overlay: "Overlays",
};

export const POLICY_LABELS: Record<PluginPolicy, string> = {
  "viewer-global": "Viewers can change",
  additive: "Viewers can add their own",
  locked: "Set by the channel",
};

export const EMPTY_PREFS: ViewerPluginPrefs = { global: {}, channels: {} };
