import React from "react";
import type { PluginSlotId, ResolvedPlugin } from "@cinezoo/shared/plugins";
import { BUILTIN_PLUGINS } from "./builtins";
import SandboxedPlugin from "./sandbox/SandboxedPlugin";
import { usePluginStore, useResolvedPlugins } from "./usePluginStore";
import "./PluginSlot.scss";

interface RenderProps {
  plugin: Pick<ResolvedPlugin, "id" | "manifest" | "settings">;
  active: boolean;
  // Code for uploaded plugins; built-ins don't need it
  code?: string;
  channelSlug: string | null;
}

// One plugin, built-in or sandboxed. Also used for previews in the panel.
export const PluginRenderer: React.FC<RenderProps> = ({ plugin, active, code, channelSlug }) => {
  const builtin = BUILTIN_PLUGINS[plugin.id];
  if (builtin) {
    const Component = builtin.component;
    return <Component settings={plugin.settings} active={active} />;
  }
  if (code == null) return null;
  return (
    <SandboxedPlugin
      className={`plugin-frame plugin-frame--${plugin.manifest.slot.replace(".", "-")} ${active ? "is-active" : ""}`}
      manifest={plugin.manifest}
      code={code}
      settings={plugin.settings}
      slot={plugin.manifest.slot}
      channelSlug={channelSlug}
      active={active}
    />
  );
};

// Renders whatever the current viewer has active in a slot
const PluginSlot: React.FC<{ slot: PluginSlotId; active: boolean }> = ({ slot, active }) => {
  const plugins = useResolvedPlugins().filter((p) => p.manifest.slot === slot);
  const code = usePluginStore((s) => s.code);
  const channelSlug = usePluginStore((s) => s.channelSlug);
  if (!plugins.length) return null;

  return (
    <div className={`plugin-slot plugin-slot--${slot.replace(".", "-")}`} data-slot={slot}>
      {plugins.map((p) => (
        <div key={p.id} className="plugin-slot__item" data-plugin={p.id}>
          <PluginRenderer plugin={p} active={active} code={code[p.id]} channelSlug={channelSlug} />
        </div>
      ))}
    </div>
  );
};

export default PluginSlot;
