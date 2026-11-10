import React from "react";
import type { SettingField, SettingsValues } from "@cinezoo/shared/plugins";

interface Props {
  fields: SettingField[];
  values: SettingsValues;
  onChange: (values: SettingsValues) => void;
  disabled?: boolean;
}

// Renders a plugin's declared settings as form controls
const SettingsForm: React.FC<Props> = ({ fields, values, onChange, disabled }) => {
  if (!fields.length) return <p className="plugins-muted">No settings.</p>;
  const set = (key: string, value: string | number | boolean) => onChange({ ...values, [key]: value });

  return (
    <div className="plugin-settings">
      {fields.map((f) => {
        const value = values[f.key] ?? f.default;
        const id = `plugin-setting-${f.key}`;
        let control: React.ReactNode;
        switch (f.type) {
          case "color":
            control = <input id={id} type="color" value={String(value)} disabled={disabled} onChange={(e) => set(f.key, e.target.value)} />;
            break;
          case "number":
            control = (
              <span className="plugin-settings__range">
                <input
                  id={id}
                  type="range"
                  min={f.min ?? 0}
                  max={f.max ?? 100}
                  step={f.step ?? 1}
                  value={Number(value)}
                  disabled={disabled}
                  onChange={(e) => set(f.key, Number(e.target.value))}
                />
                <output htmlFor={id}>{Number(value)}</output>
              </span>
            );
            break;
          case "boolean":
            control = <input id={id} type="checkbox" checked={Boolean(value)} disabled={disabled} onChange={(e) => set(f.key, e.target.checked)} />;
            break;
          case "select":
            control = (
              <select id={id} value={String(value)} disabled={disabled} onChange={(e) => set(f.key, e.target.value)}>
                {f.options.map((o) => (
                  <option key={o.value} value={o.value}>{o.label}</option>
                ))}
              </select>
            );
            break;
          case "text":
            control = (
              <input
                id={id}
                type="text"
                value={String(value)}
                maxLength={f.maxLength ?? 200}
                disabled={disabled}
                onChange={(e) => set(f.key, e.target.value)}
              />
            );
            break;
        }
        return (
          <div key={f.key} className={`plugin-settings__row plugin-settings__row--${f.type}`}>
            <label htmlFor={id}>{f.label}</label>
            {control}
            {f.help && <small>{f.help}</small>}
          </div>
        );
      })}
    </div>
  );
};

export default SettingsForm;
