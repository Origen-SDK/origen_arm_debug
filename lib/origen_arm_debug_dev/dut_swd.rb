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

      arm_debug.mem_ap.csw.bits(:size).write(0b010)
    end
  end
end
