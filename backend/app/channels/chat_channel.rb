# Live channel chat and "trending" viewer counts, ported from the Socket.io
# handlers in the Express backend (src/sockets/chatSocket.ts).
#
# Each client subscription stands in for one Socket.io socket. Clients speak
# the same event names through shared/src/realtime (a socket.io-shaped
# wrapper), and every server -> client message is `{ event:, data: }`:
#
#   client perform "join_room"    { channelId }               -> "chatHistory" (to the caller)
#   client perform "send_message" { userId, message, channelId } -> "receiveMessage" (to the room)
#   server broadcast                                            -> "viewerCounts" (to everyone)
#
# Rooms (which channel each subscription is watching) live in process memory,
# exactly as Socket.io's adapter rooms did, so viewer counts assume a single
# Puma process (threads are fine).
class ChatChannel < ApplicationCable::Channel
  VIEWER_COUNTS = "viewer_counts"

  # subscription object_id => channel slug
  ROOMS = Concurrent::Map.new

  def self.room_stream(slug) = "chat:#{slug}"

  def subscribed
    stream_from VIEWER_COUNTS
    # send current counts to the newly connected client
    self.class.broadcast_viewer_counts
  end

  def unsubscribed
    ROOMS.delete(object_id)
    self.class.broadcast_viewer_counts
  end

  def join_room(data)
    slug = data["channelId"]
    previous = ROOMS[object_id]
    stop_stream_from self.class.room_stream(previous) if previous
    ROOMS.delete(object_id)
    return if slug.nil?

    slug = slug.to_s
    ROOMS[object_id] = slug
    stream_from self.class.room_stream(slug)

    channel_db_id = Db.one("SELECT id FROM channels WHERE slug = $1 LIMIT 1", [slug])&.dig("id")

    session_id = nil
    if channel_db_id
      session_id = Db.one(<<~SQL, [channel_db_id])&.dig("id")
        SELECT id FROM sessions
        WHERE channel_id = $1
          AND now() BETWEEN starts_at AND COALESCE(ends_at, now() + interval '100 years')
          AND status IN ('scheduled','live')
        ORDER BY starts_at DESC
        LIMIT 1
      SQL
    end

    history =
      if session_id
        Db.query(<<~SQL, [session_id]).rows
          SELECT m.id, m.content, m.created_at, u.username
            FROM messages m
            JOIN users u ON u.id = m.user_id
            WHERE m.session_id = $1
              AND m.created_at > NOW() - INTERVAL '1 hour'
            ORDER BY m.created_at ASC
        SQL
      elsif channel_db_id
        Db.query(<<~SQL, [channel_db_id]).rows
          SELECT m.id, m.content, m.created_at, u.username
            FROM messages m
            JOIN users u ON u.id = m.user_id
            WHERE m.channel_id = $1
              AND m.created_at > NOW() - INTERVAL '1 hour'
            ORDER BY m.created_at ASC
        SQL
      else
        []
      end

    @room = { slug: slug, channel_db_id: channel_db_id, session_id: session_id }
    emit "chatHistory", history

    # broadcast updated viewer counts after room change
    self.class.broadcast_viewer_counts
  rescue => e
    logger.error("joinRoom error: #{e.message}")
    emit "chatHistory", []
  end

  def send_message(data)
    user_id, message, slug = data.values_at("userId", "message", "channelId")
    return if Js.falsy?(user_id) || Js.falsy?(slug) || message.to_s.strip.empty?

    username = Db.one("SELECT username FROM users WHERE id = $1", [user_id])&.dig("username")
    return if username.nil?

    room = @room || {}
    channel_db_id = room[:channel_db_id]
    channel_db_id ||= Db.one("SELECT id FROM channels WHERE slug = $1", [slug])&.dig("id")

    row = Db.one(<<~SQL, [user_id, message.strip, channel_db_id, room[:session_id]])
      INSERT INTO messages (user_id, content, channel_id, session_id)
      VALUES ($1, $2, $3, $4)
      RETURNING id, content, created_at
    SQL

    ActionCable.server.broadcast(self.class.room_stream(slug), {
      event: "receiveMessage",
      data: { id: row["id"], content: row["content"], created_at: row["created_at"], user: username }
    })
  rescue => e
    logger.error("sendMessage error: #{e.message}")
  end

  # Top-5 channels by viewer count, sent to every subscriber. Also feeds the
  # on-demand playout supervisor the full set of channels that have viewers.
  def self.broadcast_viewer_counts
    counts = ROOMS.values.tally.map { |slug, viewers| { slug: slug, viewers: viewers } }

    OnDemandPlayout.instance.sync_viewer_counts(counts.map { _1[:slug] }.to_set)

    top5 = counts.sort_by { -_1[:viewers] }.first(5)
    return broadcast_event("viewerCounts", []) if top5.empty?

    rows = Db.query(
      "SELECT slug, display_name, name, channel_number FROM channels WHERE slug = ANY($1)",
      [top5.map { _1[:slug] }]
    ).rows.index_by { _1["slug"] }

    payload = top5.map do |c|
      ch = rows[c[:slug]]
      {
        slug: c[:slug],
        name: ch&.dig("display_name").presence || ch&.dig("name").presence || c[:slug],
        channelNumber: ch&.dig("channel_number"),
        viewers: c[:viewers]
      }
    end
    broadcast_event("viewerCounts", payload)
  rescue => e
    Rails.logger.error("broadcastViewerCounts error: #{e.message}")
  end

  def self.broadcast_event(event, data)
    ActionCable.server.broadcast(VIEWER_COUNTS, { event: event, data: data })
  end

  private

  def emit(event, data)
    transmit({ event: event, data: data })
  end
end
