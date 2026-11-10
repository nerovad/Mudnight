require "net/http"
require "json"

# Minimal ffplayout v2 control-plane client (ported from
# backend/src/services/ffplayoutClient.ts; fetch -> Net::HTTP).
#
# Cinezoo PUSHES to ffplayout:
#   login -> configure the channel's stream output (RTMP -> our tower)
#         -> POST the generated day playlist -> control: start
#
# Auth is username/password -> a short-lived access token; we re-login on a
# 401 rather than juggling refresh tokens. Like fetch, non-2xx responses do
# not raise by themselves; network errors do.
class FfplayoutClient
  Response = Struct.new(:status, :body) do
    def ok? = status >= 200 && status <= 299
    def json = JSON.parse(body.to_s)
  end

  METHODS = {
    "GET" => Net::HTTP::Get,
    "POST" => Net::HTTP::Post,
    "PUT" => Net::HTTP::Put,
    "DELETE" => Net::HTTP::Delete
  }.freeze

  def initialize(base_url, username, password)
    @base_url = base_url.to_s.sub(%r{/\z}, "")
    @username = username
    @password = password
    @access = nil
  end

  def list_outputs(ch)
    res = auth_fetch("/api/playout/outputs/#{ch}")
    raise "listOutputs(#{ch}) failed: #{res.status}" unless res.ok?
    res.json
  end

  def get_config(ch)
    res = auth_fetch("/api/playout/config/#{ch}")
    raise "getConfig(#{ch}) failed: #{res.status}" unless res.ok?
    res.json
  end

  def put_config(ch, config)
    res = auth_fetch("/api/playout/config/#{ch}", method: "PUT",
      headers: { "Content-Type" => "application/json" }, body: JSON.generate(config))
    raise "putConfig(#{ch}) failed: #{res.status}" unless res.ok?
    nil
  end

  # Point the channel at our RTMP tower and enable the as-run task. ffplayout
  # selects the active output by its `output.id` (the 'stream' output row).
  # opts: stream_url:, width:, height:, fps:, task_path:
  def configure_stream_output(ch, opts)
    outputs = list_outputs(ch)
    stream = outputs.find { |o| o.is_a?(Hash) && o["name"] == "stream" }
    raise "channel #{ch} has no 'stream' output" unless stream

    config = get_config(ch)
    config["output"] = (config["output"].is_a?(Hash) ? config["output"] : {}).merge(
      "id" => stream["id"],
      "mode" => "stream",
      "stream_type" => "rtmp",
      "stream_format" => "flv",
      "stream_url" => opts[:stream_url],
      "width" => opts[:width],
      "height" => opts[:height],
      "fps" => opts[:fps]
    )
    config["task"] = { "enable" => true, "path" => opts[:task_path] }
    config["playlist"] = (config["playlist"].is_a?(Hash) ? config["playlist"] : {}).merge("day_start" => "00:00:00")
    put_config(ch, config)
  end

  # Replace the channel's day playlist. DELETE-then-POST is idempotent: a bare
  # POST 409s when a playlist for that date already exists.
  def push_playlist(ch, playlist)
    date = playlist["date"]
    begin
      auth_fetch("/api/playlist/#{ch}/#{date}", method: "DELETE")
    rescue StandardError
      # best effort, like `.catch(() => {})`
    end
    res = auth_fetch("/api/playlist/#{ch}", method: "POST",
      headers: { "Content-Type" => "application/json" }, body: JSON.generate(playlist))
    raise "pushPlaylist(#{ch}, #{date}) failed: #{res.status}" unless res.ok?
    nil
  end

  # command: "start" | "stop" | "restart" | "status"
  def control(ch, command)
    res = auth_fetch("/api/control/#{ch}/process", method: "POST",
      headers: { "Content-Type" => "application/json" }, body: JSON.generate({ command: command }))
    raise "control(#{ch}, #{command}) failed: #{res.status}" unless res.ok?
    nil
  end

  def media_current(ch)
    res = auth_fetch("/api/control/#{ch}/media/current")
    raise "mediaCurrent(#{ch}) failed: #{res.status}" unless res.ok?
    res.json
  end

  # Plain HTTP request helper (also used by FfplayoutControlDriver).
  def self.http(method, url, headers: {}, body: nil)
    uri = URI.parse(url)
    raise ArgumentError, "Invalid URL: #{url}" unless uri.is_a?(URI::HTTP) && uri.host
    req = METHODS.fetch(method).new(uri)
    headers.each { |k, v| req[k] = v }
    req.body = body if body
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
      open_timeout: 10, read_timeout: 300, write_timeout: 300) { |http| http.request(req) }
    Response.new(res.code.to_i, res.body)
  end

  private

  def login
    res = self.class.http("POST", "#{@base_url}/auth/login",
      headers: { "Content-Type" => "application/json" },
      body: JSON.generate({ username: @username, password: @password }))
    raise "ffplayout login failed: #{res.status}" unless res.ok?
    body = res.json
    access = body.is_a?(Hash) ? body["access"] : nil
    raise "ffplayout login returned no access token" unless Js.truthy?(access)
    @access = access
  end

  # Authenticated request that logs in on first use and re-logs once on a 401.
  def auth_fetch(path, method: "GET", headers: {}, body: nil, retry_auth: true)
    login unless @access
    res = self.class.http(method, "#{@base_url}#{path}",
      headers: headers.merge("Authorization" => "Bearer #{@access}"), body: body)
    if res.status == 401 && retry_auth
      @access = nil
      return auth_fetch(path, method: method, headers: headers, body: body, retry_auth: false)
    end
    res
  end
end
