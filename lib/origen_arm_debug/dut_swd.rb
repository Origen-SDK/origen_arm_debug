module OrigenARMDebug
  # Simple SWD-specific dut model that inherits from protocol-agnostic DUT model
  class SWD_DUT < DUT
    include OrigenSWD
    include Origen::Pins

    # Adds swd-required pins to the simple dut model
    # Returns nothing.
    def initialize
      super
      add_pin :swd_clk
      add_pin :swd_dio
    end
  end
end
