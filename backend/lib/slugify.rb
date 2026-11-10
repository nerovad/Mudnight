# Port of backend/src/utils/slugify.ts.
module Slugify
  module_function

  # slugify(input): lowercase, trim, collapse non [a-z0-9] runs to "-",
  # strip leading/trailing "-". Like the JS version, a non-string input raises
  # (there it was a TypeError on .toLowerCase).
  def slugify(input)
    raise TypeError, "input.toLowerCase is not a function" unless input.is_a?(String)

    input.downcase
      .gsub(/\A[[:space:]﻿]+|[[:space:]﻿]+\z/, "")
      .gsub(/[^a-z0-9]+/, "-")
      .gsub(/(\A-|-\z)+/, "")
  end
end
