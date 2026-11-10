// Types for the `mudnight` global available inside every sandboxed plugin.
// Reference it from your plugin with:
//   /// <reference path="path/to/mudnight.d.ts" />
// The implementation lives in frontend/src/plugins/sandbox/runtime.ts.

declare namespace Mudnight {
  type SettingValue = string | number | boolean;
  type Settings = Record<string, SettingValue>;

  type Slot = "sidebar.background" | "sidebar.section";
  type Permission = "channel:read" | "storage";

  interface Channel {
    slug: string;
  }

  interface Context {
    pluginId: string;
    version: string;
    slot: Slot;
    permissions: Permission[];
    // Resolved values for every setting your manifest declares
    settings: Settings;
    // null unless you asked for "channel:read"
    channel: Channel | null;
    // Whether your slot is on screen (e.g. the sidebar is open). Pause
    // animations while it's false.
    active: boolean;
    // The viewer asked their OS for less motion. Respect it.
    reducedMotion: boolean;
  }

  interface Events {
    settings: Settings;
    channel: Channel | null;
    active: boolean;
    reducedMotion: boolean;
  }

  interface Storage {
    // Per plugin, per viewer, on their device; 64 KB total. Needs "storage".
    get<T = unknown>(key: string): Promise<T | null>;
    set(key: string, value: unknown): Promise<true>;
    remove(key: string): Promise<true>;
  }

  interface SDK {
    readonly version: number;
    // null until the host has sent it; use ready() to wait
    readonly context: Context | null;
    ready(fn?: (context: Context) => void): Promise<Context>;
    // Returns an unsubscribe function
    on<E extends keyof Events>(event: E, fn: (data: Events[E]) => void): () => void;
    // sidebar.section only: ask for a frame height in px (24-800)
    resize(height: number): void;
    readonly storage: Storage;
  }
}

declare const mudnight: Mudnight.SDK;
