module OrigenARMDebug
  class DAPController
    include Origen::Controller
    include Helpers

    # Returns the currently enabled DP (or the only DP if only one
    # of them).
    # If no dp is enabled before calling this, it will choose the
    # SW_DP by default.
    def dp
      dps.first
    end
  end
end
