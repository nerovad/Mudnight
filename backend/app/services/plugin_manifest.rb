# Validation for the plugin system. The client runs the same manifest checks
# (shared/src/plugins/validate.ts) to give authors early feedback; these are
# the ones that are enforced.
module PluginManifest
  MAX_CODE_BYTES = 1024 * 1024
  MAX_INSTALLS = 20
  MAX_PREFS_BYTES = 64 * 1024

  NAME_PATTERN = /\A[a-z0-9][a-z0-9-]{1,39}\z/
  KEY_PATTERN = /\A@[A-Za-z0-9_.-]+\/[a-z0-9][a-z0-9-]{1,39}\z/
  FIELD_KEY_PATTERN = /\A[a-zA-Z][a-zA-Z0-9_]{0,39}\z/
  HEX_COLOR = /\A#[0-9a-fA-F]{6}\z/

  # Slot => categories it accepts. Keep in step with SLOTS in
  # shared/src/plugins/types.ts.
  SLOTS = {
    "sidebar.background" => %w[theme],
    "sidebar.section" => %w[widget chat player overlay]
  }.freeze
  CATEGORIES = %w[theme widget chat player overlay].freeze
  POLICIES = %w[viewer-global additive locked].freeze
  PERMISSIONS = %w[channel:read storage].freeze
  FIELD_TYPES = %w[color number boolean select text].freeze

  # Plugins that ship inside the web client (frontend/src/plugins/builtins)
  BUILTIN_IDS = %w[mudnight.lava-lamp].freeze

  module_function

  # Returns [normalized_manifest, errors]. The manifest's id is replaced with
  # the "@username/name" key it will be stored under.
  def validate(raw, username)
    return [nil, ["manifest must be a JSON object"]] unless raw.is_a?(Hash)

    errors = []
    m = raw.deep_dup
    name = m["id"].is_a?(String) ? m["id"].sub(%r{\A@[^/]+/}, "") : ""
    errors << "id must be 2-40 lowercase letters, numbers or dashes" unless name.match?(NAME_PATTERN)
    errors << "name is required (max 60 characters)" unless m["name"].is_a?(String) && m["name"].strip.present? && m["name"].length <= 60
    errors << 'version must look like "1.0.0"' unless m["version"].is_a?(String) && m["version"].match?(/\A\d+\.\d+\.\d+\z/)
    if !m["description"].nil? && !(m["description"].is_a?(String) && m["description"].length <= 300)
      errors << "description must be text (max 300 characters)"
    end
    errors << "category must be one of: #{CATEGORIES.join(', ')}" unless CATEGORIES.include?(m["category"])
    errors << "slot must be one of: #{SLOTS.keys.join(', ')}" unless SLOTS.key?(m["slot"])
    errors << "policy must be one of: #{POLICIES.join(', ')}" unless POLICIES.include?(m["policy"])

    if SLOTS.key?(m["slot"]) && CATEGORIES.include?(m["category"]) && !SLOTS[m["slot"]].include?(m["category"])
      errors << "slot #{m['slot']} doesn't take #{m['category']} plugins"
    end
    if m["category"] == "theme" && m["policy"] != "viewer-global"
      errors << 'themes must use policy "viewer-global": viewers always get to choose how the site looks'
    end

    unless m["permissions"].nil? || (m["permissions"].is_a?(Array) && m["permissions"].all? { |p| PERMISSIONS.include?(p) })
      errors << "permissions must be a list from: #{PERMISSIONS.join(', ')}"
    end

    errors.concat(validate_settings(m["settings"])) unless m["settings"].nil?

    m["id"] = "@#{username}/#{name}"
    m["author"] = username
    errors.empty? ? [m, []] : [nil, errors]
  end

  def validate_settings(settings)
    return ["settings must be a list of at most 30 fields"] unless settings.is_a?(Array) && settings.length <= 30

    errors = []
    seen = {}
    settings.each_with_index do |f, i|
      at = "settings[#{i}]"
      next errors << "#{at} must be an object" unless f.is_a?(Hash)

      key = f["key"]
      if !key.is_a?(String) || !key.match?(FIELD_KEY_PATTERN)
        errors << "#{at}.key must be a simple identifier"
      elsif seen[key]
        errors << "#{at}.key \"#{key}\" is used twice"
      else
        seen[key] = true
      end
      errors << "#{at}.label is required" unless f["label"].is_a?(String) && f["label"].present?
      next errors << "#{at}.type must be one of: #{FIELD_TYPES.join(', ')}" unless FIELD_TYPES.include?(f["type"])

      d = f["default"]
      case f["type"]
      when "color" then errors << "#{at}.default must be a color like \"#a259ff\"" unless d.is_a?(String) && d.match?(HEX_COLOR)
      when "number" then errors << "#{at}.default must be a number" unless d.is_a?(Numeric)
      when "boolean" then errors << "#{at}.default must be true or false" unless [true, false].include?(d)
      when "text" then errors << "#{at}.default must be text" unless d.is_a?(String)
      when "select"
        opts = f["options"]
        if !opts.is_a?(Array) || opts.empty?
          errors << "#{at}.options must list at least one option"
        elsif opts.none? { |o| o.is_a?(Hash) && o["value"] == d }
          errors << "#{at}.default must be one of its options"
        end
      end
    end
    errors
  end

  # A settings hash as stored on a channel or in a viewer's prefs: flat,
  # scalar values only. Each plugin re-checks values against its own fields
  # when it resolves them (shared/src/plugins/resolve.ts).
  def settings_ok?(settings)
    settings.nil? || (settings.is_a?(Hash) && settings.length <= 30 &&
      settings.all? { |k, v| k.is_a?(String) && k.match?(FIELD_KEY_PATTERN) && scalar?(v) })
  end

  def scalar?(v)
    v.is_a?(Numeric) || v == true || v == false || (v.is_a?(String) && v.length <= 500)
  end

  def plugin_id?(id)
    id.is_a?(String) && (BUILTIN_IDS.include?(id) || id.match?(KEY_PATTERN))
  end

  # Channel config: [{ "id", "enabled", "settings" }]. Returns [installs, error].
  def validate_installs(raw)
    return [nil, "plugins must be a list"] unless raw.is_a?(Array)
    return [nil, "a channel can have at most #{MAX_INSTALLS} plugins"] if raw.length > MAX_INSTALLS

    installs = raw.map do |i|
      return [nil, "each plugin needs an id, enabled and settings"] unless i.is_a?(Hash) && plugin_id?(i["id"])
      return [nil, "invalid settings for #{i['id']}"] unless settings_ok?(i["settings"])

      { "id" => i["id"], "enabled" => i["enabled"] == true, "settings" => i["settings"] || {} }
    end
    return [nil, "a plugin can only be listed once"] if installs.map { |i| i["id"] }.uniq.length != installs.length

    uploaded = installs.map { |i| i["id"] } - BUILTIN_IDS
    if uploaded.any?
      found = Db.query("SELECT plugin_key FROM plugins WHERE plugin_key = ANY($1)", [uploaded]).rows.map { |r| r["plugin_key"] }
      missing = uploaded - found
      return [nil, "unknown plugin: #{missing.join(', ')}"] if missing.any?
    end

    [installs, nil]
  end

  # Viewer prefs: { "global" => { id => override }, "channels" => { slug => { id => override } } }
  def validate_prefs(raw)
    return [nil, "prefs must be an object"] unless raw.is_a?(Hash)
    return [nil, "prefs are too large"] if JSON.generate(raw).bytesize > MAX_PREFS_BYTES

    override_ok = lambda do |overrides|
      overrides.is_a?(Hash) && overrides.all? do |id, o|
        plugin_id?(id) && o.is_a?(Hash) && (o["enabled"].nil? || [true, false].include?(o["enabled"])) && settings_ok?(o["settings"])
      end
    end

    global = raw["global"] || {}
    channels = raw["channels"] || {}
    return [nil, "invalid global prefs"] unless override_ok.call(global)
    return [nil, "invalid channel prefs"] unless channels.is_a?(Hash) && channels.all? { |slug, o| slug.is_a?(String) && override_ok.call(o) }

    [{ "global" => global, "channels" => channels }, nil]
  end
end
