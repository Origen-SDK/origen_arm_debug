module OrigenARMDebugDev
  # Simple JTAG-specific dut model that inherits from protocol-agnostic DUT model
  class JTAG_DUT < DUT
    include OrigenJTAG

    # Adds jtag-required pins to the simple dut model
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

      # Specify (customize) ARM Debug implementation details
      arm_debug.mdm_ap.add_reg(:company, 0x08)
      arm_debug.mdm_ap.apreg_access_wait = 8
      arm_debug.mem_aps.each do |ap|
        ap.apreg_access_wait = 8
        ap.apmem_access_wait = 8
        ap.csw.write(0x23000040)
      end
    end
  end
end
