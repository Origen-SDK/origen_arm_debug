module OrigenARMDebug
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
    end
  end
end
