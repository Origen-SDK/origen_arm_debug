module OrigenARMDebug
  class SW_DPController
    include Origen::Controller
    include Helpers

    def write_register(reg, options = {})
      unless reg.owner == model
        fail 'The SW_DP write_register method can only be used for writing its own registers!'
      end
      unless reg.writable?
        fail "The :#{reg.name} register is not writeable!"
      end

      log "Write DP register #{reg.name.to_s.upcase}: #{reg.data.to_hex}" do
        dut.swd.write_dp(reg)
      end
    end

    def read_register(reg, options = {})
      unless reg.owner == model
        fail 'The SW_DP read_register method can only be used for reading its own registers!'
      end
      unless reg.readable?
        fail "The :#{reg.name} register is not readable!"
      end

      log "Read DP register #{reg.name.to_s.upcase}: #{Origen::Utility.read_hex(reg)}" do
        dut.swd.read_dp(reg)
      end
    end

    def select_bank(address)
      if @bank_initialized
        @bank_initialized = true
        reg(:select).write!(address)
      else
        reg(:select).write!(address) unless reg(:select).data == address
      end
    end
  end
end
