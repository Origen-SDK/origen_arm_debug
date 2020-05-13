module OrigenARMDebug
  class DAPController
    include Origen::Controller
    include Helpers

    attr_accessor :dp

    # Returns the currently enabled DP (or the only DP if only one
    # of them).
    # If no dp is enabled before calling this, it will choose the
    # SW_DP by default.
    def dp
      @dp ||= dps.first
    end

    def set_dp(dp)
      if dps.size > 1
        if dp == :swd || dp == :sw
          @dp = dps.first
        elsif dp == :jtag
          @dp = dps.last
        else
          Origen.log.error 'origen_arm_debug: Only SWD and JTAG DP available'
        end
      else
        Origen.log.warn 'origen_arm_debug: Ignoring set_dp call since only one DP is available'
      end
    end

    def reset_dp
      @dp = nil
    end

    def is_jtag?
      dp.is_jtag?
    end

    def is_swd?
      dp.is_swd?
    end
    alias_method :is_sw?, :is_swd?
  end
end
