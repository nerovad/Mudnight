import React, { useEffect, useMemo, useState } from "react";
import {
  CATEGORY_LABELS,
  MAX_PLUGIN_CODE_BYTES,
  POLICY_LABELS,
  SLOTS,
  resolveSettings,
  validateManifest,
  type PluginCategory,
  type PluginInstall,
  type PluginManifest,
  type PluginOverride,
  type ResolvedPlugin,
  type SettingsValues,
  type ViewerPluginPrefs,
} from "@cinezoo/shared/plugins";
import { useAuth } from "../../store/AuthContext";
import { PluginRenderer } from "../PluginSlot";
import { usePluginStore, useResolvedPlugins, type CatalogEntry } from "../usePluginStore";
import SettingsForm from "./SettingsForm";
import templateCode from "../../../../plugins/template/plugin.js?raw";
import templateManifest from "../../../../plugins/template/manifest.json?raw";
import "./PluginsPanel.scss";

type Tab = "active" | "browse" | "channel" | "build";
// Where a viewer's changes go: every channel, or just this one
type Scope = "global" | "channel";

const SOURCE_LABELS: Record<ResolvedPlugin["source"], string> = {
  default: "Mudnight default",
  channel: "Set by this channel",
  viewer: "Your choice",
};

/* === Viewer prefs helpers === */

function getOverride(prefs: ViewerPluginPrefs, scope: Scope, slug: string | null, id: string): PluginOverride | undefined {
  return scope === "global" ? prefs.global[id] : slug ? prefs.channels[slug]?.[id] : undefined;
}

// Returns prefs with one plugin's override at `scope` replaced (null removes it)
function withOverride(
  prefs: ViewerPluginPrefs,
  scope: Scope,
  slug: string | null,
  id: string,
  override: PluginOverride | null
): ViewerPluginPrefs {
  const apply = (map: Record<string, PluginOverride>) => {
    const next = { ...map };
    if (override) next[id] = override;
    else delete next[id];
    return next;
  };
  if (scope === "global") return { ...prefs, global: apply(prefs.global) };
  if (!slug) return prefs;
  const channels = { ...prefs.channels, [slug]: apply(prefs.channels[slug] ?? {}) };
  if (!Object.keys(channels[slug]).length) delete channels[slug];
  return { ...prefs, channels };
}

// Turning on a plugin in a one-at-a-time slot (like the sidebar background)
// clears your other picks for that slot at the same scope
function enableAt(prefs: ViewerPluginPrefs, scope: Scope, slug: string | null, manifest: PluginManifest, manifests: Record<string, PluginManifest>) {
  let next = prefs;
  if (SLOTS[manifest.slot].exclusive) {
    const map = scope === "global" ? prefs.global : slug ? prefs.channels[slug] ?? {} : {};
    for (const [otherId, o] of Object.entries(map)) {
      if (otherId === manifest.id || manifests[otherId]?.slot !== manifest.slot || o.enabled === undefined) continue;
      const { enabled: _drop, ...rest } = o;
      next = withOverride(next, scope, slug, otherId, Object.keys(rest).length ? rest : null);
    }
  }
  const current = getOverride(next, scope, slug, manifest.id);
  return withOverride(next, scope, slug, manifest.id, { ...current, enabled: true });
}

/* === Small pieces === */

const Badge: React.FC<{ kind: string; children: React.ReactNode }> = ({ kind, children }) => (
  <span className={`plugin-badge plugin-badge--${kind}`}>{children}</span>
);

const Preview: React.FC<{ manifest: PluginManifest; settings: SettingsValues; code?: string; channelSlug: string | null }> = ({
  manifest,
  settings,
  code,
  channelSlug,
}) => (
  <div className={`plugin-preview plugin-preview--${manifest.slot.replace(".", "-")}`}>
    <div className="plugin-preview__stage">
      <PluginRenderer plugin={{ id: manifest.id, manifest, settings }} active code={code} channelSlug={channelSlug} />
    </div>
    {manifest.slot === "sidebar.background" && (
      <div className="plugin-preview__mock" aria-hidden="true">
        <strong>The Pit</strong>
        <span />
        <span />
      </div>
    )}
  </div>
);

/* === Panel === */

const PluginsPanel: React.FC = () => {
  const { user, isAuthenticated } = useAuth();
  const store = usePluginStore();
  const { catalog, prefs, channelSlug, channelOwnerId, channelInstalls, code, updatePrefs, ensureCode } = store;
  const resolved = useResolvedPlugins();
  const isOwner = !!user && channelOwnerId != null && user.id === channelOwnerId;

  const [tab, setTab] = useState<Tab>("active");
  const [scope, setScope] = useState<Scope>("global");
  const effectiveScope: Scope = channelSlug ? scope : "global";

  const manifests = useMemo(() => Object.fromEntries(Object.values(catalog).map((e) => [e.id, e.manifest])), [catalog]);
  const activeIds = new Set(resolved.map((r) => r.id));

  const tabs: { id: Tab; label: string }[] = [
    { id: "active", label: "On this channel" },
    { id: "browse", label: "Browse" },
    ...(isOwner ? [{ id: "channel" as Tab, label: "My channel" }] : []),
    { id: "build", label: "Build" },
  ];

  /* --- viewer actions --- */
  const turnOn = (m: PluginManifest) => updatePrefs((p) => enableAt(p, effectiveScope, channelSlug, m, manifests));
  const turnOff = (id: string) =>
    updatePrefs((p) => withOverride(p, effectiveScope, channelSlug, id, { ...getOverride(p, effectiveScope, channelSlug, id), enabled: false }));
  const reset = (id: string) => updatePrefs((p) => withOverride(p, effectiveScope, channelSlug, id, null));
  const setMySettings = (id: string, settings: SettingsValues) =>
    updatePrefs((p) => withOverride(p, effectiveScope, channelSlug, id, { ...getOverride(p, effectiveScope, channelSlug, id), settings }));

  const scopeToggle = channelSlug && (
    <div className="plugins-scope" role="radiogroup" aria-label="Apply my changes to">
      <span>Apply my changes to</span>
      <button role="radio" aria-checked={scope === "global"} className={scope === "global" ? "on" : ""} onClick={() => setScope("global")}>
        All channels
      </button>
      <button role="radio" aria-checked={scope === "channel"} className={scope === "channel" ? "on" : ""} onClick={() => setScope("channel")}>
        This channel only
      </button>
    </div>
  );

  return (
    <div className="plugins-panel">
      <nav className="plugins-tabs" role="tablist">
        {tabs.map((t) => (
          <button key={t.id} role="tab" aria-selected={tab === t.id} className={tab === t.id ? "on" : ""} onClick={() => setTab(t.id)}>
            {t.label}
          </button>
        ))}
      </nav>

      {tab === "active" && (
        <section>
          {scopeToggle}
          {!resolved.length && <p className="plugins-muted">Nothing is running here. Find something in Browse.</p>}
          {resolved.map((r) => {
            const override = getOverride(prefs, effectiveScope, channelSlug, r.id);
            return (
              <article key={r.id} className="plugin-card">
                <header>
                  <div>
                    <h5>{r.manifest.name}</h5>
                    <small>
                      {CATEGORY_LABELS[r.manifest.category]} → {SLOTS[r.manifest.slot].label}
                    </small>
                  </div>
                  <div className="plugin-card__badges">
                    <Badge kind={r.source}>{SOURCE_LABELS[r.source]}</Badge>
                    {!r.viewerCanChange && <Badge kind="locked">🔒 {POLICY_LABELS[r.manifest.policy]}</Badge>}
                  </div>
                </header>
                {r.viewerCanChange ? (
                  <>
                    <SettingsForm fields={r.manifest.settings ?? []} values={r.settings} onChange={(s) => setMySettings(r.id, s)} />
                    <div className="plugin-card__actions">
                      <button className="btn-secondary" onClick={() => turnOff(r.id)}>
                        Turn off {effectiveScope === "global" ? "everywhere" : "here"}
                      </button>
                      {override && (
                        <button className="btn-ghost" onClick={() => reset(r.id)}>
                          Reset my changes
                        </button>
                      )}
                    </div>
                  </>
                ) : (
                  <p className="plugins-muted">This channel needs this plugin to work, so only its creator can change it.</p>
                )}
              </article>
            );
          })}
        </section>
      )}

      {tab === "browse" && (
        <BrowseTab
          entries={Object.values(catalog).filter((e) => e.listed)}
          activeIds={activeIds}
          isOwner={isOwner}
          channelInstalls={channelInstalls}
          channelSlug={channelSlug}
          code={code}
          ensureCode={ensureCode}
          scopeToggle={scopeToggle}
          scope={effectiveScope}
          prefs={prefs}
          onUse={turnOn}
          onTurnOff={turnOff}
          onReset={reset}
          onChannelChange={(installs) => store.saveChannelInstalls(installs)}
        />
      )}

      {tab === "channel" && isOwner && (
        <ChannelTab catalog={catalog} installs={channelInstalls} onSave={(i) => store.saveChannelInstalls(i)} />
      )}

      {tab === "build" && <BuildTab isAuthenticated={isAuthenticated} channelSlug={channelSlug} />}
    </div>
  );
};

/* === Browse === */

const BrowseTab: React.FC<{
  entries: CatalogEntry[];
  activeIds: Set<string>;
  isOwner: boolean;
  channelInstalls: PluginInstall[];
  channelSlug: string | null;
  code: Record<string, string>;
  ensureCode: (ids: string[]) => Promise<void>;
  scopeToggle: React.ReactNode;
  scope: Scope;
  prefs: ViewerPluginPrefs;
  onUse: (m: PluginManifest) => void;
  onTurnOff: (id: string) => void;
  onReset: (id: string) => void;
  onChannelChange: (installs: PluginInstall[]) => Promise<void>;
}> = ({ entries, activeIds, isOwner, channelInstalls, channelSlug, code, ensureCode, scopeToggle, scope, prefs, onUse, onTurnOff, onReset, onChannelChange }) => {
  const [previewing, setPreviewing] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const groups = useMemo(() => {
    const byCategory = new Map<PluginCategory, CatalogEntry[]>();
    for (const e of entries) {
      const list = byCategory.get(e.manifest.category) ?? [];
      list.push(e);
      byCategory.set(e.manifest.category, list);
    }
    return [...byCategory.entries()];
  }, [entries]);

  const installed = (id: string) => channelInstalls.some((i) => i.id === id);
  const toggleChannel = async (id: string) => {
    setError(null);
    try {
      await onChannelChange(installed(id) ? channelInstalls.filter((i) => i.id !== id) : [...channelInstalls, { id, enabled: true }]);
    } catch (e) {
      setError((e as Error).message);
    }
  };

  const preview = (e: CatalogEntry) => {
    if (!e.builtin) ensureCode([e.id]);
    setPreviewing(previewing === e.id ? null : e.id);
  };

  return (
    <section>
      {scopeToggle}
      {error && <p className="plugins-error">{error}</p>}
      {groups.map(([category, list]) => (
        <div key={category} className="plugins-group">
          <h4>{CATEGORY_LABELS[category]}</h4>
          {list.map((e) => {
            const m = e.manifest;
            const viewerCanUse = m.policy !== "locked";
            const override = getOverride(prefs, scope, channelSlug, e.id);
            return (
              <article key={e.id} className="plugin-card">
                <header>
                  <div>
                    <h5>{m.name}</h5>
                    <small>
                      {SLOTS[m.slot].label} · {e.builtin ? "by Mudnight" : `by @${e.author}`} · v{m.version}
                    </small>
                  </div>
                  <div className="plugin-card__badges">
                    {activeIds.has(e.id) && <Badge kind="viewer">Active</Badge>}
                    <Badge kind={m.policy}>{POLICY_LABELS[m.policy]}</Badge>
                  </div>
                </header>
                {m.description && <p className="plugin-card__desc">{m.description}</p>}
                {previewing === e.id && (
                  <Preview manifest={m} settings={resolveSettings(m)} code={code[e.id]} channelSlug={channelSlug} />
                )}
                <div className="plugin-card__actions">
                  <button className="btn-ghost" onClick={() => preview(e)}>
                    {previewing === e.id ? "Hide preview" : "Preview"}
                  </button>
                  {viewerCanUse &&
                    (override?.enabled === true ? (
                      <button className="btn-secondary" onClick={() => onReset(e.id)}>Stop using</button>
                    ) : override?.enabled === false ? (
                      <button className="btn-secondary" onClick={() => onReset(e.id)}>Turn back on</button>
                    ) : activeIds.has(e.id) ? (
                      <button className="btn-secondary" onClick={() => onTurnOff(e.id)}>Turn off for me</button>
                    ) : (
                      <button className="btn-primary" onClick={() => onUse(m)}>
                        Use {scope === "global" ? "everywhere" : "here"}
                      </button>
                    ))}
                  {isOwner && (
                    <button className="btn-secondary" onClick={() => toggleChannel(e.id)}>
                      {installed(e.id) ? "Remove from my channel" : "Add to my channel"}
                    </button>
                  )}
                </div>
              </article>
            );
          })}
        </div>
      ))}
    </section>
  );
};

/* === My channel (owner) === */

const ChannelTab: React.FC<{
  catalog: Record<string, CatalogEntry>;
  installs: PluginInstall[];
  onSave: (installs: PluginInstall[]) => Promise<void>;
}> = ({ catalog, installs, onSave }) => {
  const [draft, setDraft] = useState<PluginInstall[]>(installs);
  const [status, setStatus] = useState<string | null>(null);
  useEffect(() => setDraft(installs), [installs]);

  const patch = (id: string, change: Partial<PluginInstall>) =>
    setDraft((d) => d.map((i) => (i.id === id ? { ...i, ...change } : i)));

  const save = async () => {
    setStatus("Saving…");
    try {
      await onSave(draft);
      setStatus("Saved");
    } catch (e) {
      setStatus((e as Error).message);
    }
  };

  return (
    <section>
      <p className="plugins-muted">
        What your channel runs for every viewer. Viewers can restyle or turn off themes. Plugins marked 🔒 stay exactly as you set them.
        Add plugins from Browse.
      </p>
      {!draft.length && <p className="plugins-muted">No plugins yet, so your channel uses the Mudnight defaults.</p>}
      {draft.map((i) => {
        const entry = catalog[i.id];
        if (!entry) return <article key={i.id} className="plugin-card"><p className="plugins-muted">{i.id} (loading…)</p></article>;
        const m = entry.manifest;
        return (
          <article key={i.id} className="plugin-card">
            <header>
              <div>
                <h5>{m.name}</h5>
                <small>{SLOTS[m.slot].label}</small>
              </div>
              <div className="plugin-card__badges">
                <Badge kind={m.policy}>{m.policy === "locked" ? "🔒 " : ""}{POLICY_LABELS[m.policy]}</Badge>
              </div>
            </header>
            <label className="plugin-toggle">
              <input type="checkbox" checked={i.enabled} onChange={(e) => patch(i.id, { enabled: e.target.checked })} /> Enabled
            </label>
            <SettingsForm fields={m.settings ?? []} values={resolveSettings(m, i.settings)} onChange={(s) => patch(i.id, { settings: s })} />
            <div className="plugin-card__actions">
              <button className="btn-ghost" onClick={() => setDraft((d) => d.filter((x) => x.id !== i.id))}>Remove</button>
            </div>
          </article>
        );
      })}
      <div className="plugin-card__actions">
        <button className="btn-primary" onClick={save}>Save channel plugins</button>
        {status && <span className="plugins-muted">{status}</span>}
      </div>
    </section>
  );
};

/* === Build === */

const BuildTab: React.FC<{ isAuthenticated: boolean; channelSlug: string | null }> = ({ isAuthenticated, channelSlug }) => {
  const { catalog, upload, setVisibility, remove } = usePluginStore();
  const [manifestText, setManifestText] = useState(templateManifest);
  const [source, setSource] = useState(templateCode);
  const [visibility, setVisibilityChoice] = useState<"unlisted" | "public">("unlisted");
  const [testSettings, setTestSettings] = useState<SettingsValues>({});
  const [running, setRunning] = useState<{ manifest: PluginManifest; code: string } | null>(null);
  const [status, setStatus] = useState<{ ok: boolean; text: string } | null>(null);

  const parsed = useMemo(() => {
    try {
      return validateManifest(JSON.parse(manifestText));
    } catch (e) {
      return { errors: [`manifest.json isn't valid JSON: ${(e as Error).message}`] };
    }
  }, [manifestText]);
  const tooBig = new Blob([source]).size > MAX_PLUGIN_CODE_BYTES;
  const errors = [...parsed.errors, ...(tooBig ? ["Code must be under 1 MB"] : [])];

  // Preview runs under a throwaway id, so it never collides with an
  // installed copy's storage
  const run = () => {
    if (!parsed.manifest) return;
    setRunning({ manifest: { ...parsed.manifest, id: `preview.${parsed.manifest.id}` }, code: source });
    setTestSettings(resolveSettings(parsed.manifest));
  };

  const submit = async () => {
    if (!parsed.manifest || tooBig) return;
    setStatus(null);
    try {
      const saved = await upload(parsed.manifest, source, visibility);
      setStatus({ ok: true, text: `Uploaded as ${saved.id}. Find it in Browse to use it or add it to your channel.` });
    } catch (e) {
      setStatus({ ok: false, text: (e as Error).message });
    }
  };

  const readFile = (file: File | undefined, into: (text: string) => void) => {
    if (file) file.text().then(into);
  };

  const mine = Object.values(catalog).filter((e) => e.mine);

  return (
    <section className="plugins-build">
      <p className="plugins-muted">
        A plugin is a <code>manifest.json</code> plus one JavaScript file. Write it in JavaScript, TypeScript, or any language that compiles
        to JS or WebAssembly, then bundle it into a single file (inline any .wasm as base64). It runs in a sandbox with no network access and
        talks to Mudnight only through the <code>mudnight</code> SDK. The starter below is a working theme; the full guide is
        docs/plugins.md.
      </p>

      <details className="plugins-cheatsheet">
        <summary>SDK cheat sheet</summary>
        <pre>{`mudnight.ready(ctx => { ctx.settings, ctx.active, ctx.channel, ctx.reducedMotion })
mudnight.on("settings" | "active" | "channel" | "reducedMotion", fn)
mudnight.resize(px)                       // sidebar.section only
await mudnight.storage.get(key)           // needs "storage"
await mudnight.storage.set(key, value)

slots:       sidebar.background (themes), sidebar.section
policies:    viewer-global (themes must use this), additive, locked
permissions: channel:read, storage`}</pre>
      </details>

      <div className="plugins-build__editors">
        <label>
          <span>
            manifest.json
            <input type="file" accept=".json,application/json" onChange={(e) => readFile(e.target.files?.[0], setManifestText)} />
          </span>
          <textarea spellCheck={false} value={manifestText} onChange={(e) => setManifestText(e.target.value)} rows={12} />
        </label>
        <label>
          <span>
            plugin code (.js)
            <input type="file" accept=".js,.mjs,text/javascript" onChange={(e) => readFile(e.target.files?.[0], setSource)} />
          </span>
          <textarea spellCheck={false} value={source} onChange={(e) => setSource(e.target.value)} rows={12} />
        </label>
      </div>

      {errors.length > 0 && (
        <ul className="plugins-error">
          {errors.map((e) => <li key={e}>{e}</li>)}
        </ul>
      )}

      <div className="plugin-card__actions">
        <button className="btn-secondary" disabled={!parsed.manifest} onClick={run}>Run preview</button>
        {isAuthenticated ? (
          <>
            <select value={visibility} onChange={(e) => setVisibilityChoice(e.target.value as "unlisted" | "public")} aria-label="Visibility">
              <option value="unlisted">Unlisted (only you and channels you add it to)</option>
              <option value="public">Public (anyone can find it in Browse)</option>
            </select>
            <button className="btn-primary" disabled={errors.length > 0} onClick={submit}>Upload</button>
          </>
        ) : (
          <span className="plugins-muted">Sign in to upload plugins.</span>
        )}
      </div>
      {status && <p className={status.ok ? "plugins-ok" : "plugins-error"}>{status.text}</p>}

      {running && (
        <div className="plugins-build__preview">
          <Preview manifest={running.manifest} settings={testSettings} code={running.code} channelSlug={channelSlug} />
          <SettingsForm fields={running.manifest.settings ?? []} values={testSettings} onChange={setTestSettings} />
        </div>
      )}

      {mine.length > 0 && (
        <div className="plugins-group">
          <h4>Your plugins</h4>
          {mine.map((e) => (
            <article key={e.id} className="plugin-card">
              <header>
                <div>
                  <h5>{e.manifest.name}</h5>
                  <small>{e.id} · v{e.manifest.version}</small>
                </div>
              </header>
              <div className="plugin-card__actions">
                <select
                  value={e.visibility}
                  aria-label={`Visibility of ${e.manifest.name}`}
                  onChange={(ev) => setVisibility(e, ev.target.value as "unlisted" | "public").catch((err) => setStatus({ ok: false, text: err.message }))}
                >
                  <option value="unlisted">Unlisted</option>
                  <option value="public">Public</option>
                </select>
                <button
                  className="btn-ghost"
                  onClick={() => {
                    if (window.confirm(`Delete ${e.manifest.name}? Channels using it will stop showing it.`)) {
                      remove(e).catch((err) => setStatus({ ok: false, text: err.message }));
                    }
                  }}
                >
                  Delete
                </button>
              </div>
            </article>
          ))}
        </div>
      )}
    </section>
  );
};

export default PluginsPanel;
