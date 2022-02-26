module OrigenARMDebug
  # Common methods shared between the SW and JTAG DP controllers
  module DPControllerV6
    # Alias for the ctrlstat register
    def ctrl_stat
      ctrlstat
    end

    # @api private
    def select_ap_reg(reg)
      address = (reg.address & 0xFFFF_FFF0) >> 4
      address1 = (reg.address & 0xFFFF_FFFF_0000_0000) >> 32
      model.select1.write! address1 if model.select1.data != address1
      model.select.addr.write! address if model.select.addr.data != address
    end
  end
end
