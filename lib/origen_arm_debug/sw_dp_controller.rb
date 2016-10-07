require 'origen_arm_debug/dp_controller'
module OrigenARMDebug
  class SW_DPController
    include Origen::Controller
    include Helpers
    include DPController

    def write_register(reg, options = {})
      unless reg.writable?
        fail "The :#{reg.name} register is not writeable!"
      end

      if reg.owner == model
        log "Write SW-DP register #{reg.name.to_s.upcase}: #{reg.data.to_hex}" do
          dut.swd.write_dp(reg)
        end
      else
        unless reg.owner.is_a?(JTAGAP) || reg.owner.is_a?(MemAP)
          fail 'The SW-DP can only write to DP or AP registers!'
        end

        select_ap_reg(reg)
        dut.swd.write_ap(reg)
      end
    end

    def read_register(reg, options = {})
      unless reg.readable?
        fail "The :#{reg.name} register is not readable!"
      end

      if reg.owner == model
        log "Read SW-DP register #{reg.name.to_s.upcase}: #{Origen::Utility.read_hex(reg)}" do
          dut.swd.read_dp(reg)
        end
      else
        unless reg.owner.is_a?(JTAGAP) || reg.owner.is_a?(MemAP)
          fail 'The SW-DP can only write to DP or AP registers!'
        end

        select_ap_reg(reg)
        dut.swd.read_ap(address: reg.address)
        dut.swd.read_dp(reg, address: rdbuff.address)
      end
    end
  end
end
