# Port of controllers/directMessageController.ts + routes/directMessageRoutes.ts.
# Every handler caught its own errors: 500 {"error":"Server error"}.
module Api
  class DirectMessagesController < ApplicationController
    # All direct message routes require authentication
    before_action :authenticate_token!

    # GET /api/messages/conversations
    def conversations
      with_server_error("Get conversations error") do
        result = Db.query(<<~SQL, [current_user_id])
          WITH conversations AS (
                  SELECT
                    CASE
                      WHEN sender_id = $1 THEN receiver_id
                      ELSE sender_id
                    END AS other_user_id,
                    content,
                    created_at,
                    read,
                    sender_id
                  FROM direct_messages
                  WHERE sender_id = $1 OR receiver_id = $1
                ),
                latest_messages AS (
                  SELECT DISTINCT ON (other_user_id)
                    other_user_id,
                    content AS last_message,
                    created_at AS last_message_time
                  FROM conversations
                  ORDER BY other_user_id, created_at DESC
                ),
                unread_counts AS (
                  SELECT
                    sender_id AS other_user_id,
                    COUNT(*) AS unread_count
                  FROM direct_messages
                  WHERE receiver_id = $1 AND read = false
                  GROUP BY sender_id
                )
                SELECT
                  u.id AS user_id,
                  COALESCE(up.handle, '@' || u.username) AS user_handle,
                  up.avatar_url AS user_avatar,
                  lm.last_message,
                  lm.last_message_time,
                  COALESCE(uc.unread_count, 0) AS unread_count
                FROM latest_messages lm
                JOIN users u ON u.id = lm.other_user_id
                LEFT JOIN user_profiles up ON up.user_id = u.id
                LEFT JOIN unread_counts uc ON uc.other_user_id = lm.other_user_id
                ORDER BY lm.last_message_time DESC
        SQL

        conversations = result.rows.map do |row|
          {
            userId: row["user_id"].to_s,
            userHandle: row["user_handle"],
            userAvatar: row["user_avatar"],
            lastMessage: row["last_message"],
            lastMessageTime: row["last_message_time"],
            unreadCount: Js.parse_int(row["unread_count"]) || 0
          }
        end

        render json: conversations
      end
    end

    # GET /api/messages/:userId
    def show
      with_server_error("Get messages error") do
        user_id = current_user_id
        other_user_id = Js.parse_int(params[:userId])
        next render(json: { error: "Invalid user ID" }, status: :bad_request) if other_user_id.nil?

        result = Db.query(<<~SQL, [user_id, other_user_id])
          SELECT
                  dm.id,
                  dm.sender_id,
                  COALESCE(sp.handle, '@' || su.username) AS sender_handle,
                  sp.avatar_url AS sender_avatar,
                  dm.receiver_id,
                  dm.content,
                  dm.created_at,
                  dm.expires_at,
                  dm.read
                FROM direct_messages dm
                JOIN users su ON su.id = dm.sender_id
                LEFT JOIN user_profiles sp ON sp.user_id = dm.sender_id
                WHERE (dm.sender_id = $1 AND dm.receiver_id = $2)
                   OR (dm.sender_id = $2 AND dm.receiver_id = $1)
                ORDER BY dm.created_at ASC
        SQL

        messages = result.rows.map do |row|
          {
            id: row["id"].to_s,
            senderId: row["sender_id"] == user_id ? "me" : row["sender_id"].to_s,
            senderHandle: row["sender_handle"],
            senderAvatar: row["sender_avatar"],
            receiverId: row["receiver_id"] == user_id ? "me" : row["receiver_id"].to_s,
            content: row["content"],
            createdAt: row["created_at"],
            expiresAt: row["expires_at"],
            read: row["read"]
          }
        end

        render json: messages
      end
    end

    # POST /api/messages/:userId/read
    def mark_read
      with_server_error("Mark as read error") do
        sender_id = Js.parse_int(params[:userId])
        next render(json: { error: "Invalid user ID" }, status: :bad_request) if sender_id.nil?

        Db.query(<<~SQL, [sender_id, current_user_id])
          UPDATE direct_messages
                 SET read = true
                 WHERE sender_id = $1 AND receiver_id = $2 AND read = false
        SQL

        render json: { message: "Messages marked as read" }
      end
    end

    # GET /api/messages/users/search?q=
    def search_users
      with_server_error("Search users error") do
        query = request.query_parameters["q"]

        # `!query || query.length < 2` on whatever qs produced (string, array
        # or object; an object has no length and so passes).
        too_short =
          case query
          when String then query.length < 2
          when Array then query.length < 2
          when Hash then false
          else true
          end
        next render(json: []) if too_short

        pattern_text =
          case query
          when Array then query.map { |q| q.is_a?(String) ? q : "[object Object]" }.join(",")
          when Hash then "[object Object]"
          else query
          end

        result = Db.query(<<~SQL, [current_user_id, "%#{pattern_text}%"])
          SELECT u.id, u.username, COALESCE(up.handle, '@' || u.username) AS handle, up.avatar_url
                 FROM users u
                 LEFT JOIN user_profiles up ON up.user_id = u.id
                 WHERE u.id != $1
                   AND (u.username ILIKE $2 OR up.handle ILIKE $2)
                 LIMIT 10
        SQL

        users = result.rows.map do |row|
          { userId: row["id"].to_s, userHandle: row["handle"], userAvatar: row["avatar_url"] }
        end

        render json: users
      end
    end

    # POST /api/messages/send
    def send_message
      with_server_error("Send message error") do
        sender_id = current_user_id
        receiver_id = body["receiverId"]
        content = body["content"]

        if Js.falsy?(receiver_id) || Js.falsy?(content)
          next render(json: { error: "receiverId and content are required" }, status: :bad_request)
        end

        receiver_id_num = Js.parse_int(receiver_id.is_a?(Array) ? receiver_id.join(",") : receiver_id)
        next render(json: { error: "Invalid receiver ID" }, status: :bad_request) if receiver_id_num.nil?

        if receiver_id_num == sender_id
          next render(json: { error: "Cannot send message to yourself" }, status: :bad_request)
        end

        # Verify receiver exists
        user_check = Db.query("SELECT id FROM users WHERE id = $1", [receiver_id_num])
        next render(json: { error: "Recipient not found" }, status: :not_found) if user_check.rows.empty?

        # Insert the message
        msg = Db.query(<<~SQL, [sender_id, receiver_id_num, content]).rows[0]
          INSERT INTO direct_messages (sender_id, receiver_id, content)
                 VALUES ($1, $2, $3)
                 RETURNING id, sender_id, receiver_id, content, read, created_at, expires_at
        SQL

        # Get sender info
        sender = Db.one(<<~SQL, [sender_id])
          SELECT u.username, up.handle, up.avatar_url
                 FROM users u
                 LEFT JOIN user_profiles up ON up.user_id = u.id
                 WHERE u.id = $1
        SQL

        render json: {
          id: msg["id"].to_s,
          senderId: "me",
          senderHandle: Js.truthy?(sender["handle"]) ? sender["handle"] : "@#{sender['username']}",
          senderAvatar: sender["avatar_url"],
          receiverId: msg["receiver_id"].to_s,
          content: msg["content"],
          createdAt: msg["created_at"],
          expiresAt: msg["expires_at"],
          read: msg["read"]
        }, status: :created
      end
    end

    private

    def with_server_error(label)
      yield
    rescue StandardError => e
      Rails.logger.error("#{label}: #{e.message}")
      render json: { error: "Server error" }, status: :internal_server_error
    end
  end
end
