# Raw SQL access with node-postgres semantics.
#
# The API was ported from Express, where every handler ran hand-written SQL
# through `pool.query(sql, [params])` and returned `result.rows` as JSON. The
# React and mobile clients depend on the exact shape of those rows, so this
# module keeps the same contract instead of re-expressing the queries through
# ActiveRecord models:
#
#   result = Db.query("SELECT * FROM channels WHERE slug = $1", [slug])
#   result.rows       # => [{"id" => 1, "slug" => "...", ...}]  (string keys)
#   result.row_count  # => rows returned / affected, like pg's rowCount
#   Db.one(sql, params)  # => first row or nil
#
# Values decode the way node-postgres decodes them, so JSON responses match:
# int2/int4 -> Integer, int8 (COUNT(*), bigserial) -> String, numeric -> String,
# float -> Float, bool -> true/false, json/jsonb -> parsed, timestamptz -> Time
# (UTC), arrays -> Arrays, anything else -> String. `date` is local midnight,
# like node-postgres. `timestamp without time zone` is read as UTC, because
# ActiveRecord runs every session in UTC, so that is the zone now() writes
# such columns in (node-postgres used the server's default zone; on a UTC
# server the two agree).
#
# Queries share ActiveRecord's per-thread connection, so they participate in
# `Db.transaction { ... }` (an ActiveRecord transaction underneath).
module Db
  Result = Struct.new(:rows, :row_count) do
    def first = rows.first
    def empty? = rows.empty?
    def any? = rows.any?
  end

  # Postgres error with node-postgres style accessors (`code`, `constraint`),
  # so handlers can keep branching on e.g. unique violations ("23505").
  class Error < StandardError
    attr_reader :code, :constraint, :detail, :pg_error

    def initialize(pg_error)
      @pg_error = pg_error
      result = pg_error.respond_to?(:result) ? pg_error.result : nil
      if result
        @code = result.error_field(PG::Result::PG_DIAG_SQLSTATE)
        @constraint = result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
        @detail = result.error_field(PG::Result::PG_DIAG_MESSAGE_DETAIL)
      end
      super(pg_error.message)
    end
  end

  module_function

  def query(sql, params = [])
    encoded = params.map { |value| encode(value) }
    ActiveRecord::Base.connection_pool.with_connection do |conn|
      res = ActiveSupport::Notifications.instrument("sql.active_record", sql: sql, name: "Db", binds: [], connection: conn) do
        conn.raw_connection.exec_params(sql, encoded)
      end
      begin
        Result.new(decode(res), res.cmd_tuples)
      ensure
        res.clear
      end
    end
  rescue PG::Error => e
    raise Error.new(e)
  end

  def one(sql, params = [])
    query(sql, params).rows.first
  end

  def transaction(&block)
    ActiveRecord::Base.transaction(requires_new: true, &block)
  rescue ActiveRecord::StatementInvalid => e
    raise e.cause.is_a?(PG::Error) ? Error.new(e.cause) : e
  end

  # --- parameter encoding (mirrors node-postgres' prepareValue) ---

  ARRAY_ENCODER = PG::TextEncoder::Array.new

  def encode(value)
    case value
    when nil then nil
    when true then "true"
    when false then "false"
    when Array then ARRAY_ENCODER.encode(value.map { |v| v.is_a?(Hash) ? JSON.generate(v) : encode_scalar(v) })
    when Hash, ActionController::Parameters then JSON.generate(value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value)
    else encode_scalar(value)
    end
  end

  def encode_scalar(value)
    case value
    when nil then nil
    when true then "true"
    when false then "false"
    when Time, DateTime, ActiveSupport::TimeWithZone then value.utc.iso8601(6)
    when Date then value.iso8601
    else value.to_s
    end
  end

  # --- result decoding (mirrors node-postgres' default type parsers) ---

  TIMESTAMP = PG::TextDecoder::TimestampWithTimeZone.new
  TIMESTAMP_UTC = PG::TextDecoder::TimestampUtc.new
  JSON_DECODER = ->(s) { JSON.parse(s) }

  SCALAR = {
    16 => ->(s) { s == "t" },                       # bool
    21 => ->(s) { Integer(s, 10) },                 # int2
    23 => ->(s) { Integer(s, 10) },                 # int4
    26 => ->(s) { Integer(s, 10) },                 # oid
    700 => ->(s) { Float(s) },                      # float4
    701 => ->(s) { Float(s) },                      # float8
    114 => JSON_DECODER,                            # json
    3802 => JSON_DECODER,                           # jsonb
    1082 => ->(s) { local_date(s) },                # date
    1114 => ->(s) { TIMESTAMP_UTC.decode(s).utc },  # timestamp (no tz)
    1184 => ->(s) { TIMESTAMP.decode(s).utc }       # timestamptz
  }.freeze

  # array oid => element oid (nil element => keep strings, e.g. int8[], text[])
  ARRAYS = {
    1000 => 16, 1005 => 21, 1007 => 23, 1028 => 26, 1021 => 700, 1022 => 701,
    199 => 114, 3807 => 3802, 1115 => 1114, 1185 => 1184, 1182 => 1082,
    1016 => nil, 1231 => nil, 1009 => nil, 1015 => nil, 1014 => nil, 2951 => nil
  }.freeze

  ARRAY_DECODER = PG::TextDecoder::Array.new

  # node-postgres: DATE -> local midnight.
  def local_date(s)
    return s unless (m = s.match(/\A(\d{4,})-(\d\d)-(\d\d)\z/))
    Time.local(m[1].to_i, m[2].to_i, m[3].to_i).utc
  end

  RAW = PG::TypeMapAllStrings.new

  def decode(res)
    # ActiveRecord installs its own result decoders on the connection; read raw
    # text here so the node-postgres rules above apply uniformly.
    res.type_map = RAW
    fields = res.fields
    casts = res.nfields.times.map { |i| caster(res.ftype(i)) }
    res.values.map do |values|
      row = {}
      values.each_with_index do |raw, i|
        row[fields[i]] = raw.nil? ? nil : casts[i].call(raw)
      end
      row
    end
  end

  def caster(oid)
    return SCALAR[oid] if SCALAR.key?(oid)
    if ARRAYS.key?(oid)
      element = ARRAYS[oid] && SCALAR[ARRAYS[oid]]
      return ->(s) { deep_map(ARRAY_DECODER.decode(s), element) }
    end
    ->(s) { s }
  end

  def deep_map(value, element)
    return value unless element
    value.map { |v| v.is_a?(Array) ? deep_map(v, element) : (v.nil? ? nil : element.call(v)) }
  end
end
