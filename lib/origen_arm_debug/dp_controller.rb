module OrigenARMDebug
  # Common methods shared between the SW and JTAG DP controllers
  module DPController
    # Alias for the ctrlstat register
    def ctrl_stat
      ctrlstat
    end

    # @api private
    def select_ap_reg(reg)
      address = reg.address & 0xFFFF_FFF0
      if model.select.data != address
        model.select.write!(address)
      end
    end
  end
end
