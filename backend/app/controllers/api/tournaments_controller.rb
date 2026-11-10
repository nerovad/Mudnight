# Port of controllers/tournamentController.ts + controllers/tournamentVotingController.ts
# (routes/tournamentRoutes.ts). Every handler had its own try/catch returning a
# handler-specific 500 message, which is kept here.
module Api
  class TournamentsController < ApplicationController
    before_action :authenticate_token!, except: :show

    DEFAULT_WINDOW = { "isActive" => false, "currentRound" => nil }.freeze

    B = TournamentBracket

    # GET /api/channels/:channelId/tournament (public)
    def show
      channel_id = params[:channelId]

      channel_result = Db.query(
        "SELECT
        c.id as channel_id,
        c.name as channel_name,
        c.slug,
        s.id as session_id,
        s.tournament_bracket,
        s.starts_at,
        s.ends_at,
        s.event_type,
        s.voting_window
       FROM channels c
       LEFT JOIN sessions s ON s.channel_id = c.id AND s.is_active = true
       WHERE c.id::text = $1 OR c.slug = $1",
        [channel_id]
      )

      return render(json: { error: "Channel not found" }, status: 404) if channel_result.rows.empty?

      channel = channel_result.rows[0]

      if Js.falsy?(channel["tournament_bracket"])
        return render(json: { error: "No tournament found for this channel" }, status: 404)
      end

      if channel["event_type"] != "tournament"
        return render(json: { error: "This channel is not a tournament" }, status: 400)
      end

      bracket = channel["tournament_bracket"]

      matchups = Db.query(
        "SELECT
        tm.*,
        COUNT(DISTINCT tv.id) as total_votes
       FROM tournament_matchups tm
       LEFT JOIN tournament_votes tv ON tv.matchup_id = tm.id
       WHERE tm.session_id = $1
       GROUP BY tm.id
       ORDER BY tm.round_number, tm.position",
        [channel["session_id"]]
      ).rows

      film_ids = []
      matchups.each do |m|
        film_ids << m["film1_id"] if Js.truthy?(m["film1_id"])
        film_ids << m["film2_id"] if Js.truthy?(m["film2_id"])
      end
      film_ids.uniq!

      # parseInt(id) -> NaN is sent by node-pg as the text "NaN" (a pg error).
      films = Db.query(
        "SELECT id, title, creator_user_id, runtime_seconds
       FROM films
       WHERE id = ANY($1::int[])",
        [film_ids.map { |id| Js.parse_int(id) || "NaN" }]
      ).rows

      films_map = {}
      films.each { |f| films_map[f["id"].to_s] = f }

      now = Time.now
      starts_at = channel["starts_at"] || Time.at(0)
      ends_at = channel["ends_at"] || Time.at(0) # new Date(null) == epoch

      status =
        if now < starts_at then "upcoming"
        elsif now > ends_at then "completed"
        else "active"
        end

      rounds = B.prop(bracket, "rounds")
      raise TypeError, "bracket.rounds is not an array" unless rounds.is_a?(Array)

      current_round = 1
      if status == "active"
        matchups.each do |m|
          if Js.falsy?(m["winner_id"])
            current_round = m["round_number"]
            break
          end
        end
      elsif status == "completed"
        current_round = rounds.length
      end

      updated_rounds = rounds.map do |round|
        raise TypeError, "round is not an object" unless round.is_a?(Hash) && round["matchups"].is_a?(Array)

        out_round = {}
        out_round["roundNumber"] = round["roundNumber"] if round.key?("roundNumber")
        out_round["roundName"] = B.round_name(round["roundNumber"], rounds.length)
        out_round["matchups"] = round["matchups"].map do |matchup|
          raise TypeError, "matchup is null" if matchup.nil?

          db_matchup = matchups.find { |m| matchup.is_a?(Hash) && matchup.key?("id") && m["matchup_id"] == matchup["id"] }

          film1 = build_film(db_matchup && db_matchup["film1_id"], B.prop(matchup, "film1"), films_map)
          film2 = build_film(db_matchup && db_matchup["film2_id"], B.prop(matchup, "film2"), films_map)

          out = {}
          out["id"] = matchup["id"] if matchup.is_a?(Hash) && matchup.key?("id")
          out["position"] = matchup["position"] if matchup.is_a?(Hash) && matchup.key?("position")
          out["roundNumber"] = round["roundNumber"] if round.key?("roundNumber")
          out["film1"] = film1
          out["film2"] = film2
          out["votes1"] = Js.truthy?(db_matchup && db_matchup["film1_votes"]) ? db_matchup["film1_votes"] : 0
          out["votes2"] = Js.truthy?(db_matchup && db_matchup["film2_votes"]) ? db_matchup["film2_votes"] : 0
          out["winner"] = db_matchup["winner_id"] if db_matchup && Js.truthy?(db_matchup["winner_id"])
          out["dbMatchupId"] = db_matchup["id"] if db_matchup
          out
        end
        out_round
      end

      voting_window = Js.truthy?(channel["voting_window"]) ? channel["voting_window"] : DEFAULT_WINDOW

      render json: {
        id: channel["session_id"],
        channelName: channel["channel_name"],
        status: status,
        currentRound: current_round,
        rounds: updated_rounds,
        startsAt: channel["starts_at"],
        endsAt: channel["ends_at"],
        votingWindow: voting_window
      }
    rescue StandardError => e
      log_error("Error fetching tournament", e)
      render json: { error: "Failed to fetch tournament data" }, status: 500
    end

    # POST /api/tournaments/matchups/:matchupId/vote
    def vote
      matchup_id = params[:matchupId]
      film_id = body["film_id"]
      user_id = current_user_id

      return render(json: { error: "Film ID is required" }, status: 400) if Js.falsy?(film_id)

      matchup = Db.one(
        "SELECT tm.*, s.require_login, s.voting_window
       FROM tournament_matchups tm
       JOIN sessions s ON s.id = tm.session_id
       WHERE tm.id = $1",
        [matchup_id]
      )

      return render(json: { error: "Matchup not found" }, status: 404) unless matchup

      error = voting_window_error(matchup)
      return render(json: { error: error }, status: 400) if error

      film_id_str = B.js_string(film_id)

      if film_id_str != matchup["film1_id"] && film_id_str != matchup["film2_id"]
        Rails.logger.error("Film validation failed: #{{ received: film_id, filmIdStr: film_id_str, film1_id: matchup['film1_id'], film2_id: matchup['film2_id'] }}")
        return render(json: { error: "Invalid film for this matchup" }, status: 400)
      end

      if Js.truthy?(matchup["winner_id"])
        return render(json: { error: "This matchup has already been decided" }, status: 400)
      end

      if matchup["require_login"] && Js.falsy?(user_id)
        return render(json: { error: "Login required to vote" }, status: 401)
      end

      existing_vote = nil
      Db.transaction do
        if Js.truthy?(user_id)
          existing_vote = Db.one(
            "SELECT id, film_id FROM tournament_votes
           WHERE matchup_id = $1 AND user_id = $2",
            [matchup_id, user_id]
          )
        end

        if existing_vote
          old_film_id = existing_vote["film_id"]

          if old_film_id != film_id_str
            old_col = old_film_id == matchup["film1_id"] ? "film1_votes" : "film2_votes"
            Db.query(
              "UPDATE tournament_matchups
             SET #{old_col} = GREATEST(0, #{old_col} - 1),
                 updated_at = CURRENT_TIMESTAMP
             WHERE id = $1",
              [matchup_id]
            )

            Db.query(
              "UPDATE tournament_votes
            SET film_id = $1
            WHERE id = $2",
              [film_id_str, existing_vote["id"]]
            )

            new_col = film_id_str == matchup["film1_id"] ? "film1_votes" : "film2_votes"
            Db.query(
              "UPDATE tournament_matchups
             SET #{new_col} = #{new_col} + 1,
                 updated_at = CURRENT_TIMESTAMP
             WHERE id = $1",
              [matchup_id]
            )
          end
        else
          if Js.truthy?(user_id)
            Db.query(
              "INSERT INTO tournament_votes (matchup_id, user_id, film_id)
             VALUES ($1, $2, $3)",
              [matchup_id, user_id, film_id_str]
            )
          end

          col = film_id_str == matchup["film1_id"] ? "film1_votes" : "film2_votes"
          Db.query(
            "UPDATE tournament_matchups
           SET #{col} = #{col} + 1,
               updated_at = CURRENT_TIMESTAMP
           WHERE id = $1",
            [matchup_id]
          )
        end
      end

      updated = Db.one("SELECT * FROM tournament_matchups WHERE id = $1", [matchup_id])

      render json: {
        success: true,
        message: existing_vote ? "Vote changed successfully" : "Vote recorded successfully",
        matchup: {
          id: updated["id"],
          film1Votes: updated["film1_votes"],
          film2Votes: updated["film2_votes"]
        }
      }
    rescue StandardError => e
      log_error("Error recording vote", e)
      render json: { error: "Failed to record vote" }, status: 500
    end

    # DELETE /api/tournaments/matchups/:matchupId/vote
    def remove_vote
      matchup_id = params[:matchupId]
      user_id = current_user_id

      return render(json: { error: "Authentication required" }, status: 401) if Js.falsy?(user_id)

      matchup = Db.one(
        "SELECT tm.*, s.voting_window
       FROM tournament_matchups tm
       JOIN sessions s ON s.id = tm.session_id
       WHERE tm.id = $1",
        [matchup_id]
      )

      return render(json: { error: "Matchup not found" }, status: 404) unless matchup

      error = voting_window_error(matchup)
      return render(json: { error: error }, status: 400) if error

      if Js.truthy?(matchup["winner_id"])
        return render(json: { error: "This matchup has already been decided" }, status: 400)
      end

      film_id = nil
      Db.transaction do
        vote_row = Db.one(
          "SELECT film_id FROM tournament_votes
         WHERE matchup_id = $1 AND user_id = $2",
          [matchup_id, user_id]
        )
        next unless vote_row

        film_id = vote_row["film_id"]

        Db.query(
          "DELETE FROM tournament_votes
         WHERE matchup_id = $1 AND user_id = $2",
          [matchup_id, user_id]
        )

        col = film_id == matchup["film1_id"] ? "film1_votes" : "film2_votes"
        Db.query(
          "UPDATE tournament_matchups
         SET #{col} = GREATEST(0, #{col} - 1),
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $1",
          [matchup_id]
        )
      end

      return render(json: { error: "You haven't voted on this matchup" }, status: 400) if film_id.nil?

      updated = Db.one("SELECT * FROM tournament_matchups WHERE id = $1", [matchup_id])

      render json: {
        success: true,
        message: "Vote removed successfully",
        matchup: {
          id: updated["id"],
          film1Votes: updated["film1_votes"],
          film2Votes: updated["film2_votes"]
        }
      }
    rescue StandardError => e
      log_error("Error removing vote", e)
      render json: { error: "Failed to remove vote" }, status: 500
    end

    # POST /api/tournaments/matchups/:matchupId/advance
    # No ownership check in Express (any authenticated user may advance).
    def advance
      matchup_id = params[:matchupId]
      force_winner_id = body["forceWinnerId"]

      matchup = Db.one(
        "SELECT tm.*, s.tournament_bracket
       FROM tournament_matchups tm
       JOIN sessions s ON s.id = tm.session_id
       WHERE tm.id = $1",
        [matchup_id]
      )

      return render(json: { error: "Matchup not found" }, status: 404) unless matchup

      if Js.truthy?(force_winner_id)
        if force_winner_id != matchup["film1_id"] && force_winner_id != matchup["film2_id"]
          return render(json: { error: "Invalid winner ID" }, status: 400)
        end
        winner_id = force_winner_id
      else
        if matchup["film1_votes"] == matchup["film2_votes"]
          return render(json: { error: "Cannot advance: votes are tied" }, status: 400)
        end
        winner_id = B.gt(matchup["film1_votes"], matchup["film2_votes"]) ? matchup["film1_id"] : matchup["film2_id"]
      end

      response = Db.transaction do
        Db.query(
          "UPDATE tournament_matchups
         SET winner_id = $1,
             completed_at = CURRENT_TIMESTAMP,
             updated_at = CURRENT_TIMESTAMP
         WHERE id = $2",
          [winner_id, matchup_id]
        )

        # Express does JSON.parse(matchup.tournament_bracket) on an already
        # decoded jsonb value, which throws for a normal bracket object.
        bracket = js_json_parse(matchup["tournament_bracket"])
        rounds = B.prop(bracket, "rounds")
        raise TypeError, "Cannot read properties of rounds" unless bracket.is_a?(Hash) && rounds.respond_to?(:length)

        total_rounds = rounds.length

        if matchup["round_number"] == total_rounds
          next { success: true, message: "Tournament completed!", champion: winner_id }
        end

        next_round, next_position, film_slot, next_matchup_id = B.next_slot(matchup["round_number"], matchup["position"])

        next_matchup = Db.one(
          "SELECT id FROM tournament_matchups
         WHERE session_id = $1 AND round_number = $2 AND position = $3",
          [matchup["session_id"], next_round, next_position]
        )

        if next_matchup.nil?
          Db.query(
            "INSERT INTO tournament_matchups
           (session_id, matchup_id, round_number, position, #{film_slot})
           VALUES ($1, $2, $3, $4, $5)",
            [matchup["session_id"], next_matchup_id, next_round, next_position, winner_id]
          )
        else
          Db.query(
            "UPDATE tournament_matchups
           SET #{film_slot} = $1, updated_at = CURRENT_TIMESTAMP
           WHERE id = $2",
            [winner_id, next_matchup["id"]]
          )
        end

        {
          success: true,
          message: "Winner advanced to next round",
          winnerId: winner_id,
          nextRound: next_round,
          nextPosition: next_position
        }
      end

      render json: response
    rescue StandardError => e
      log_error("Error advancing winner", e)
      render json: { error: "Failed to advance winner" }, status: 500
    end

    # POST /api/tournaments/rounds/:sessionId/:roundNumber/advance-all
    # No ownership check in Express (any authenticated user may advance).
    def advance_all
      session_id = params[:sessionId]
      round_number = params[:roundNumber]

      matchups = Db.query(
        "SELECT * FROM tournament_matchups
       WHERE session_id = $1 AND round_number = $2
       ORDER BY position",
        [session_id, Js.parse_int(round_number) || "NaN"]
      ).rows

      return render(json: { error: "No matchups found for this round" }, status: 404) if matchups.empty?

      results = []

      matchups.each do |matchup|
        if Js.truthy?(matchup["winner_id"])
          results << { matchupId: matchup["id"], status: "already_advanced" }
          next
        end

        if matchup["film1_votes"] == matchup["film2_votes"]
          results << { matchupId: matchup["id"], status: "tie" }
          next
        end

        winner_id = B.gt(matchup["film1_votes"], matchup["film2_votes"]) ? matchup["film1_id"] : matchup["film2_id"]

        Db.query(
          "UPDATE tournament_matchups
         SET winner_id = $1, completed_at = CURRENT_TIMESTAMP
         WHERE id = $2",
          [winner_id, matchup["id"]]
        )

        next_round, next_position, film_slot, next_matchup_id = B.next_slot(matchup["round_number"], matchup["position"])

        existing = Db.one(
          "SELECT id FROM tournament_matchups
         WHERE session_id = $1 AND round_number = $2 AND position = $3",
          [session_id, next_round, next_position]
        )

        if existing.nil?
          Db.query(
            "INSERT INTO tournament_matchups
           (session_id, matchup_id, round_number, position, #{film_slot})
           VALUES ($1, $2, $3, $4, $5)",
            [session_id, next_matchup_id, next_round, next_position, winner_id]
          )
        else
          Db.query(
            "UPDATE tournament_matchups
           SET #{film_slot} = $1
           WHERE id = $2",
            [winner_id, existing["id"]]
          )
        end

        results << { matchupId: matchup["id"], status: "advanced", winnerId: winner_id }
      rescue StandardError => e
        results << { matchupId: matchup["id"], status: "error", error: js_error_message(e) }
      end

      render json: { success: true, message: "Round advancement complete", results: results }
    rescue StandardError => e
      log_error("Error advancing round", e)
      render json: { error: "Failed to advance round" }, status: 500
    end

    # GET /api/tournaments/:sessionId/status
    def status
      session_id = params[:sessionId]
      user_id = current_user_id

      return render(json: { error: "Authentication required" }, status: 401) if Js.falsy?(user_id)

      session_id_num = Js.number(session_id)
      return render(json: { error: "Invalid session id" }, status: 400) if session_id_num.nil?

      begin
        session = find_owned_session(session_id)
        return render(json: { error: "Tournament session not found" }, status: 404) unless session
        return render(json: { error: "You do not own this tournament" }, status: 403) if session["owner_id"] != user_id

        matchups = Db.query(
          "SELECT
        tm.*,
        f1.title as film1_title,
        f2.title as film2_title
      FROM tournament_matchups tm
      LEFT JOIN films f1 ON tm.film1_id::bigint = f1.id
      LEFT JOIN films f2 ON tm.film2_id::bigint = f2.id
      WHERE tm.session_id = $1
      ORDER BY tm.round_number, tm.position",
          [session_id_num]
        ).rows

        rounds = {}
        max_round = 0
        current_round = 1

        matchups.each do |m|
          key = m["round_number"].to_s
          rounds[key] ||= []
          rounds[key] << {
            id: m["id"],
            matchupId: m["matchup_id"],
            round: m["round_number"],
            position: m["position"],
            film1Title: m["film1_title"],
            film2Title: m["film2_title"],
            votes1: Js.truthy?(m["film1_votes"]) ? m["film1_votes"] : 0,
            votes2: Js.truthy?(m["film2_votes"]) ? m["film2_votes"] : 0,
            winnerId: m["winner_id"],
            completed: !m["completed_at"].nil?
          }

          max_round = [max_round, m["round_number"]].max

          if Js.falsy?(m["winner_id"]) && m["round_number"] >= current_round
            current_round = m["round_number"]
          end
        end

        is_complete = matchups.all? { |m| !m["winner_id"].nil? }
        voting_window = Js.truthy?(session["voting_window"]) ? session["voting_window"] : DEFAULT_WINDOW

        render json: {
          currentRound: current_round,
          totalRounds: max_round,
          isComplete: is_complete,
          votingWindow: voting_window,
          rounds: rounds
        }
      rescue StandardError => e
        log_error("Error getting tournament status", e)
        render json: { error: "Failed to get tournament status" }, status: 500
      end
    end

    # POST /api/tournaments/:sessionId/voting/start
    def start_voting
      session_id = params[:sessionId]
      round = body["round"]
      user_id = current_user_id

      return render(json: { error: "Authentication required" }, status: 401) if Js.falsy?(user_id)

      if Js.falsy?(round) || !round.is_a?(Numeric)
        return render(json: { error: "Round number is required" }, status: 400)
      end

      # JSON.parse yields 2 for "2.0"; keep JS number formatting.
      round = round.to_i if round.is_a?(Float) && round.finite? && round == round.floor

      begin
        session = find_owned_session(session_id)
        return render(json: { error: "Tournament session not found" }, status: 404) unless session
        return render(json: { error: "You do not own this tournament" }, status: 403) if session["owner_id"] != user_id

        voting_window = Js.truthy?(session["voting_window"]) ? session["voting_window"] : DEFAULT_WINDOW
        if Js.truthy?(B.prop(voting_window, "isActive"))
          return render(json: { error: "Voting is already active for Round #{B.js_prop_string(voting_window, 'currentRound')}" }, status: 400)
        end

        round_data = Db.one(
          "SELECT COUNT(*) as total, COUNT(winner_id) as completed
       FROM tournament_matchups
       WHERE session_id::text = $1 AND round_number = $2",
          [session_id, round]
        )

        if Js.parse_int(round_data["total"]) == 0
          return render(json: { error: "Round #{B.js_string(round)} does not exist" }, status: 400)
        end

        if Js.parse_int(round_data["completed"]) == Js.parse_int(round_data["total"])
          return render(json: { error: "Round #{B.js_string(round)} is already complete" }, status: 400)
        end

        new_window = { isActive: true, currentRound: round }
        Db.query(
          "UPDATE sessions
       SET voting_window = $1, updated_at = NOW()
       WHERE id = $2",
          [JSON.generate(new_window), session_id]
        )

        render json: { message: "Voting started for Round #{B.js_string(round)}", votingWindow: new_window }
      rescue StandardError => e
        log_error("Error starting voting", e)
        render json: { error: "Failed to start voting" }, status: 500
      end
    end

    # POST /api/tournaments/:sessionId/voting/end
    def end_voting
      session_id = params[:sessionId]
      user_id = current_user_id

      return render(json: { error: "Authentication required" }, status: 401) if Js.falsy?(user_id)

      begin
        session = find_owned_session(session_id)
        return render(json: { error: "Tournament session not found" }, status: 404) unless session
        return render(json: { error: "You do not own this tournament" }, status: 403) if session["owner_id"] != user_id

        voting_window = Js.truthy?(session["voting_window"]) ? session["voting_window"] : DEFAULT_WINDOW
        unless Js.truthy?(B.prop(voting_window, "isActive"))
          return render(json: { error: "No active voting window" }, status: 400)
        end

        current_round = voting_window["currentRound"]

        rounds_len = B.prop(session["tournament_bracket"], "rounds")
        rounds_len = rounds_len.respond_to?(:length) ? rounds_len.length : nil
        total_rounds = Js.truthy?(rounds_len) ? rounds_len : 0

        matchups = Db.query(
          "SELECT * FROM tournament_matchups
       WHERE session_id::text = $1 AND round_number = $2 AND winner_id IS NULL",
          [session_id, current_round]
        ).rows

        winners_advanced = 0

        matchups.each do |matchup|
          v1 = matchup["film1_votes"]
          v2 = matchup["film2_votes"]
          winner_id =
            if B.gt(v1, v2) then matchup["film1_id"]
            elsif B.gt(v2, v1) then matchup["film2_id"]
            elsif v1 == v2 then rand < 0.5 ? matchup["film1_id"] : matchup["film2_id"]
            end

          next unless Js.truthy?(winner_id)

          Db.query(
            "UPDATE tournament_matchups
           SET winner_id = $1, completed_at = NOW()
           WHERE id = $2",
            [winner_id, matchup["id"]]
          )

          winners_advanced += 1

          next if current_round == total_rounds

          next_round, next_position, film_slot, next_matchup_id = B.next_slot(current_round, matchup["position"])

          next_matchup = Db.one(
            "SELECT * FROM tournament_matchups
           WHERE session_id::text = $1 AND round_number = $2 AND position = $3",
            [session_id, next_round, next_position]
          )

          if next_matchup
            Db.query(
              "UPDATE tournament_matchups
             SET #{film_slot} = $1, updated_at = NOW()
             WHERE id = $2",
              [winner_id, next_matchup["id"]]
            )
          else
            Db.query(
              "INSERT INTO tournament_matchups
             (session_id, matchup_id, round_number, position, #{film_slot}, film1_votes, film2_votes)
             VALUES ($1, $2, $3, $4, $5, 0, 0)",
              [session_id, next_matchup_id, next_round, next_position, winner_id]
            )
          end
        end

        Db.query(
          "UPDATE sessions
       SET voting_window = $1, updated_at = NOW()
       WHERE id = $2",
          [JSON.generate(DEFAULT_WINDOW), session_id]
        )

        # NOTE: sessions has no current_round column, so (as in Express) this
        # fails with a 500 after winners were already advanced.
        if (current_round.nil? ? 0 : current_round) < total_rounds
          Db.query(
            "UPDATE sessions
         SET current_round = $1
         WHERE id = $2",
            [(current_round.nil? ? 0 : current_round) + 1, session_id]
          )
        end

        render json: {
          message: "Voting ended and winners advanced",
          winnersAdvanced: winners_advanced,
          round: current_round,
          isFinalRound: current_round == total_rounds
        }
      rescue StandardError => e
        log_error("Error ending voting", e)
        render json: { error: "Failed to end voting" }, status: 500
      end
    end

    private

    def find_owned_session(session_id)
      Db.one(
        "SELECT s.*, c.owner_id
       FROM sessions s
       JOIN channels c ON s.channel_id::text = c.id::text
       WHERE s.id::text = $1 AND LOWER(s.event_type) = 'tournament'",
        [session_id]
      )
    end

    # Shared isActive / currentRound checks of voteOnMatchup and removeVote.
    def voting_window_error(matchup)
      window = Js.truthy?(matchup["voting_window"]) ? matchup["voting_window"] : DEFAULT_WINDOW
      return "Voting is not currently active" unless Js.truthy?(B.prop(window, "isActive"))

      if B.prop(window, "currentRound") != matchup["round_number"]
        return "Voting is active for Round #{B.js_prop_string(window, 'currentRound')}, not Round #{matchup['round_number']}"
      end

      nil
    end

    def build_film(db_film_id, bracket_film, films_map)
      return nil unless Js.truthy?(db_film_id)

      data = films_map[db_film_id]
      return nil unless data

      seed = B.prop(bracket_film, "seed")
      film = { "filmId" => db_film_id, "seed" => Js.truthy?(seed) ? seed : 0, "title" => data["title"] }
      film["creator"] = bracket_film["creator"] if bracket_film.is_a?(Hash) && bracket_film.key?("creator")
      film["thumbnail"] = bracket_film["thumbnail"] if bracket_film.is_a?(Hash) && bracket_film.key?("thumbnail")
      film
    end

    # JSON.parse(value) applied to an already-decoded jsonb value (String(value) first).
    def js_json_parse(value)
      raise JSON::ParserError, "\"[object Object]\" is not valid JSON" if value.is_a?(Hash)

      JSON.parse(value.is_a?(String) ? value : B.js_string(value))
    end

    # node-pg error.message is the primary message only.
    def js_error_message(error)
      if error.is_a?(Db::Error) && error.pg_error.respond_to?(:result) && error.pg_error.result
        error.pg_error.result.error_field(PG::Result::PG_DIAG_MESSAGE_PRIMARY) || error.message
      else
        error.message
      end
    end

    def log_error(label, error)
      Rails.logger.error("#{label}: #{error.class}: #{error.message}")
    end
  end
end
