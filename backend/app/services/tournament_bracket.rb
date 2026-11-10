# Pure helpers shared by the tournament endpoints (ported from
# tournamentController.ts / tournamentVotingController.ts), plus the small
# bits of JavaScript semantics those handlers relied on.
module TournamentBracket
  module_function

  # getRoundName(roundNumber, totalRounds)
  def round_name(round_number, total_rounds)
    rounds_from_end = round_number.is_a?(Numeric) ? total_rounds - round_number : nil
    return "Finals" if rounds_from_end == 0
    return "Semi-Finals" if rounds_from_end == 1
    return "Quarter-Finals" if rounds_from_end == 2
    return "Round of 16" if rounds_from_end == 3

    "Round #{js_string(round_number)}"
  end

  # Where the winner of (round_number, position) goes next:
  # [nextRound, nextPosition, filmSlot, nextMatchupId]
  def next_slot(round_number, position)
    next_round = round_number + 1
    next_position = (position / 2.0).floor
    film_slot = (position % 2).zero? ? "film1_id" : "film2_id"
    [next_round, next_position, film_slot, "r#{next_round}-m#{next_position + 1}"]
  end

  # `obj.key` / `obj?.key` on parsed JSON: undefined (nil) unless obj is an object.
  def prop(obj, key)
    obj.is_a?(Hash) ? obj[key] : nil
  end

  # String(value) / template-literal interpolation.
  def js_string(value)
    case value
    when nil then "null"
    when Float then value.finite? && value == value.floor ? value.to_i.to_s : value.to_s
    when Array then value.map { |v| v.nil? ? "" : js_string(v) }.join(",")
    when Hash then "[object Object]"
    else value.to_s
    end
  end

  # Interpolation of a possibly-missing property (`${obj.key}`).
  def js_prop_string(obj, key)
    obj.is_a?(Hash) && obj.key?(key) ? js_string(obj[key]) : "undefined"
  end

  # Relational comparison (`a > b`) on vote counts, where null coerces to 0.
  def gt(a, b)
    (a.nil? ? 0 : a) > (b.nil? ? 0 : b)
  end
end
