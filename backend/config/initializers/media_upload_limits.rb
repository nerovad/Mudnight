# Rack 3.2's multipart parser refuses any body over
# RACK_MULTIPART_PARSER_BYTESIZE_LIMIT (default 10 GiB), but channel masters
# may be up to MEDIA_MAX_UPLOAD_BYTES (default 16 GiB, as in Express/multer).
# Raise Rack's ceiling to at least that, unless the operator set it explicitly.
# (Api::MediaController enforces MEDIA_MAX_UPLOAD_BYTES itself.)
#
# The limit is read into a constant when rack/multipart/parser is loaded, which
# normally happens lazily on the first multipart request — after this runs —
# but if something already loaded it, patch the constant too.
unless ENV.key?("RACK_MULTIPART_PARSER_BYTESIZE_LIMIT")
  # (plain Float parse: reloadable lib/ helpers like Js aren't for initializers)
  max_upload = Float(ENV["MEDIA_MAX_UPLOAD_BYTES"].to_s.strip, exception: false) if ENV["MEDIA_MAX_UPLOAD_BYTES"].to_s != ""
  max_upload ||= 16 * 1024 * 1024 * 1024
  limit = [max_upload.finite? ? max_upload.ceil : 0, 10 * 1024 * 1024 * 1024].max
  ENV["RACK_MULTIPART_PARSER_BYTESIZE_LIMIT"] = limit.to_s

  require "rack/multipart"
  parser = Rack::Multipart::Parser
  if parser.const_get(:PARSER_BYTESIZE_LIMIT) != limit
    parser.send(:remove_const, :PARSER_BYTESIZE_LIMIT)
    parser.const_set(:PARSER_BYTESIZE_LIMIT, limit)
    parser.send(:private_constant, :PARSER_BYTESIZE_LIMIT)
  end
end
