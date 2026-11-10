import type { PluginManifest } from "./types";
import { SLOTS } from "./types";

// Client-side mirror of backend/app/services/plugin_manifest.rb, so authors
// see problems before uploading. The server check is the one that counts.

export const MAX_PLUGIN_CODE_BYTES = 1024 * 1024;
export const PLUGIN_NAME_PATTERN = /^[a-z0-9][a-z0-9-]{1,39}$/;

const CATEGORIES = ["theme", "widget", "chat", "player", "overlay"];
const POLICIES = ["viewer-global", "additive", "locked"];
const PERMISSIONS = ["channel:read", "storage"];
const FIELD_TYPES = ["color", "number", "boolean", "select", "text"];

export function validateManifest(raw: unknown): { manifest?: PluginManifest; errors: string[] } {
  const errors: string[] = [];
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return { errors: ["Manifest must be a JSON object"] };
  const m = raw as Record<string, any>;

  // Uploaded ids are bare names; the server adds "@username/"
  const name = typeof m.id === "string" ? m.id.replace(/^@[^/]+\//, "") : "";
  if (!PLUGIN_NAME_PATTERN.test(name)) errors.push("id must be 2-40 lowercase letters, numbers or dashes");
  if (typeof m.name !== "string" || !m.name.trim() || m.name.length > 60) errors.push("name is required (max 60 characters)");
  if (typeof m.version !== "string" || !/^\d+\.\d+\.\d+$/.test(m.version)) errors.push('version must look like "1.0.0"');
  if (m.description != null && (typeof m.description !== "string" || m.description.length > 300)) errors.push("description must be text (max 300 characters)");
  if (!CATEGORIES.includes(m.category)) errors.push(`category must be one of: ${CATEGORIES.join(", ")}`);
  if (!(m.slot in SLOTS)) errors.push(`slot must be one of: ${Object.keys(SLOTS).join(", ")}`);
  if (!POLICIES.includes(m.policy)) errors.push(`policy must be one of: ${POLICIES.join(", ")}`);

  if (m.slot in SLOTS && CATEGORIES.includes(m.category) && !SLOTS[m.slot as keyof typeof SLOTS].categories.includes(m.category)) {
    errors.push(`slot ${m.slot} doesn't take ${m.category} plugins`);
  }
  if (m.category === "theme" && m.policy !== "viewer-global") {
    errors.push('themes must use policy "viewer-global": viewers always get to choose how the site looks');
  }

  if (m.permissions != null) {
    if (!Array.isArray(m.permissions) || m.permissions.some((p: unknown) => !PERMISSIONS.includes(p as string))) {
      errors.push(`permissions must be a list from: ${PERMISSIONS.join(", ")}`);
    }
  }

  if (m.settings != null) {
    if (!Array.isArray(m.settings) || m.settings.length > 30) {
      errors.push("settings must be a list of at most 30 fields");
    } else {
      const seen = new Set<string>();
      m.settings.forEach((f: any, i: number) => {
        const at = `settings[${i}]`;
        if (!f || typeof f !== "object") return errors.push(`${at} must be an object`);
        if (typeof f.key !== "string" || !/^[a-zA-Z][a-zA-Z0-9_]{0,39}$/.test(f.key)) errors.push(`${at}.key must be a simple identifier`);
        else if (seen.has(f.key)) errors.push(`${at}.key "${f.key}" is used twice`);
        else seen.add(f.key);
        if (typeof f.label !== "string" || !f.label) errors.push(`${at}.label is required`);
        if (!FIELD_TYPES.includes(f.type)) return errors.push(`${at}.type must be one of: ${FIELD_TYPES.join(", ")}`);
        const d = f.default;
        if (f.type === "color" && !(typeof d === "string" && /^#[0-9a-f]{6}$/i.test(d))) errors.push(`${at}.default must be a color like "#a259ff"`);
        if (f.type === "number" && typeof d !== "number") errors.push(`${at}.default must be a number`);
        if (f.type === "boolean" && typeof d !== "boolean") errors.push(`${at}.default must be true or false`);
        if (f.type === "text" && typeof d !== "string") errors.push(`${at}.default must be text`);
        if (f.type === "select") {
          if (!Array.isArray(f.options) || !f.options.length) errors.push(`${at}.options must list at least one option`);
          else if (!f.options.some((o: any) => o?.value === d)) errors.push(`${at}.default must be one of its options`);
        }
      });
    }
  }

  return errors.length ? { errors } : { manifest: m as PluginManifest, errors };
}
