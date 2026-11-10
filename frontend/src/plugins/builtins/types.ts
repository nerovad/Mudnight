import type React from "react";
import type { PluginManifest, SettingsValues } from "@cinezoo/shared/plugins";

export interface BuiltinPluginProps {
  settings: SettingsValues;
  // Whether the slot is on screen (e.g. the sidebar is open), so the plugin
  // can fade in or pause
  active: boolean;
}

// A plugin that ships with the client. It runs as trusted React rather than
// in the sandbox, but goes through the same manifest, policies and
// settings as an uploaded one.
export interface BuiltinPlugin {
  manifest: PluginManifest;
  component: React.ComponentType<BuiltinPluginProps>;
}
