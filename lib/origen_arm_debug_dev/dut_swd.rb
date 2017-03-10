module OrigenARMDebugDev
  # Simple SWD-specific dut model that inherits from protocol-agnostic DUT model
  class SWD_DUT < DUT
    include OrigenSWD

    # Adds swd-required pins to the simple dut model
    # Returns nothing.
    def initialize
      super
      add_pin :tclk
      add_pin :tdi
      add_pin :tdo
      add_pin :tms
      add_pin :trst
      add_pin :swd_clk
      add_pin :swd_dio

      sub_block :arm_debug, class_name: 'OrigenARMDebug::DAP',
                            mem_aps:    {
                              mem_ap: { base_address: 0x00000000, csw_reset: 0x23000042 },
                              mdm_ap: 0x01000000
                            }
    end
  end
end
