# Port of buildChannelAnalytics (channelController.ts), shared by
# Api::ChannelsController#analytics and Api::AdminController#channel_analytics.
module ChannelAnalytics
  module_function

  def build(channel_id)
    sessions = Db.one(
      "SELECT COUNT(*) as total_sessions,
            COUNT(*) FILTER (WHERE status = 'live') as live_sessions,
            COUNT(*) FILTER (WHERE status = 'closed' OR status = 'archived') as completed_sessions,
            MIN(starts_at) as first_session,
            MAX(starts_at) as latest_session
     FROM sessions WHERE channel_id = $1",
      [channel_id]
    )

    entries = Db.one(
      "SELECT COUNT(*) as total_entries
     FROM session_entries se
     JOIN sessions s ON se.session_id = s.id
     WHERE s.channel_id = $1",
      [channel_id]
    )

    ballots = Db.one(
      "SELECT COUNT(*) as total_ballots
     FROM ballots b
     JOIN sessions s ON b.session_id = s.id
     WHERE s.channel_id = $1",
      [channel_id]
    )

    ratings = Db.one(
      "SELECT COUNT(*) as total_ratings,
            ROUND(AVG(score), 2) as avg_rating
     FROM ratings r
     JOIN sessions s ON r.session_id = s.id
     WHERE s.channel_id = $1",
      [channel_id]
    )

    match_votes = Db.one(
      "SELECT COUNT(*) as total_match_votes
     FROM match_votes mv
     JOIN matches m ON mv.match_id = m.id
     JOIN sessions s ON m.session_id = s.id
     WHERE s.channel_id = $1",
      [channel_id]
    )

    messages = Db.one(
      "SELECT COUNT(*) as total_messages
     FROM messages WHERE channel_id = $1",
      [channel_id]
    )

    schedule = Db.one(
      "SELECT COUNT(*) as total_schedule_items
     FROM channel_schedule WHERE channel_id = $1",
      [channel_id]
    )

    recent_sessions = Db.query(
      "SELECT id, title, starts_at, ends_at, status, created_at
     FROM sessions WHERE channel_id = $1
     ORDER BY starts_at DESC LIMIT 10",
      [channel_id]
    )

    unique_voters = Db.one(
      "SELECT COUNT(DISTINCT b.user_id) as unique_voters
     FROM ballots b
     JOIN sessions s ON b.session_id = s.id
     WHERE s.channel_id = $1 AND b.user_id IS NOT NULL",
      [channel_id]
    )

    {
      "sessions" => {
        "total" => Js.parse_int(sessions["total_sessions"]),
        "live" => Js.parse_int(sessions["live_sessions"]),
        "completed" => Js.parse_int(sessions["completed_sessions"]),
        "first_session" => sessions["first_session"],
        "latest_session" => sessions["latest_session"]
      },
      "engagement" => {
        "total_entries" => Js.parse_int(entries["total_entries"]),
        "total_ballots" => Js.parse_int(ballots["total_ballots"]),
        "total_ratings" => Js.parse_int(ratings["total_ratings"]),
        "avg_rating" => Js.truthy?(ratings["avg_rating"]) ? js_float(Js.parse_float(ratings["avg_rating"])) : nil,
        "total_match_votes" => Js.parse_int(match_votes["total_match_votes"]),
        "unique_voters" => Js.parse_int(unique_voters["unique_voters"])
      },
      "chat" => {
        "total_messages" => Js.parse_int(messages["total_messages"])
      },
      "schedule" => {
        "total_items" => Js.parse_int(schedule["total_schedule_items"])
      },
      "recent_sessions" => recent_sessions.rows
    }
  end

  # JSON.stringify(4.0) is "4"; Ruby would emit "4.0".
  def js_float(value)
    return value unless value.is_a?(Float) && value.finite? && value == value.floor

    value.to_i
  end
end
