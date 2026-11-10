import type { PluginInstall } from "@cinezoo/shared/plugins";
import type { BuiltinPlugin } from "./types";
import LavaLamp, { lavaLampManifest } from "./LavaLamp/LavaLamp";

// Adding a built-in? Also list its id in PluginManifest::BUILTIN_IDS
// (backend/app/services/plugin_manifest.rb) so channels can install it.
export const BUILTIN_PLUGINS: Record<string, BuiltinPlugin> = {
  [lavaLampManifest.id]: { manifest: lavaLampManifest, component: LavaLamp },
};

// What every channel gets before its creator or the viewer changes anything
export const DEFAULT_INSTALLS: PluginInstall[] = [{ id: lavaLampManifest.id, enabled: true }];
