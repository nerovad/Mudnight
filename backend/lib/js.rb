# JavaScript coercion rules the Express handlers relied on, so ported
# validation behaves identically (e.g. `if (!title)` rejects "" and 0, which
# Ruby truthiness would not).
module Js
  module_function

  # JS truthiness: false for nil, false, 0, 0.0, "", NaN.
  def truthy?(value)
    case value
    when nil, false then false
    when Numeric then !(value.zero? || (value.is_a?(Float) && value.nan?))
    when String then !value.empty?
    else true
    end
  end

  def falsy?(value) = !truthy?(value)

  # parseInt(value, 10): leading integer or nil (NaN).
  def parse_int(value)
    return value.truncate if value.is_a?(Numeric) && value.finite?
    match = value.to_s.strip.match(/\A[+-]?\d+/)
    match && match[0].to_i
  end

  # parseFloat(value): leading float or nil (NaN).
  def parse_float(value)
    return value.to_f if value.is_a?(Numeric)
    match = value.to_s.strip.match(/\A[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?/)
    match && match[0].to_f
  end

  # Number(value): nil for NaN; Number(null) / Number("") == 0.
  def number(value)
    case value
    when nil then 0
    when true then 1
    when false then 0
    when Integer then value
    when Float then value.nan? ? nil : value
    when Numeric then value.to_f
    else
      str = value.to_s.strip
      return 0 if str.empty?
      if str.match?(/\A[+-]?\d+\z/) then str.to_i
      elsif str.match?(/\A[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?\z/) then str.to_f
      elsif str.match?(/\A0x\h+\z/i) then str.to_i(16)
      end
    end
  end

  # Number.isInteger(Number(value)) && > 0, the common id check.
  def positive_int(value)
    n = number(value)
    n = n.to_i if n.is_a?(Float) && n == n.floor
    n.is_a?(Integer) && n.positive? ? n : nil
  end
end
