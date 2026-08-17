# frozen_string_literal: true

module RailVerdict
  module Git
    class Error < RailVerdict::Error; end

    class NotARepository < Error; end
    class Unavailable < Error; end
    class InvalidRevision < Error; end
    class BaseUnresolvable < Error; end
    class MergeBaseFailure < Error; end
    class DiffFailure < Error; end
    class Timeout < Error; end
    class Truncated < Error; end
  end
end
