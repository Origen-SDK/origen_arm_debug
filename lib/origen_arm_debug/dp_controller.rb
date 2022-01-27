module OrigenARMDebug
  # Common methods shared between the SW and JTAG DP controllers
  module DPController
    # Alias for the ctrlstat register
    def ctrl_stat
      ctrlstat
    end

    # @api private
    def select_ap_reg(reg)
      apsel = (reg.address & 0xFF000_0000) >> 24
      apbanksel = (reg.address & 0xF0) >> 4
      if model.select.apsel.data != apsel || model.select.apbanksel.data != apbanksel
        model.select.write! do |r|
          r.apsel.write apsel
          r.apbanksel.write apbanksel
        end
      end
    end
  end
end
