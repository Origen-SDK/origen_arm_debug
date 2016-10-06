module OrigenARMDebug
  # Object that defines API for performing Debug AP transactions using SWD or JTAG
  class SWJ_DP
    include Origen::Model

    # Customizable delay for DUT-specific required cycles for write_ap transaction
    #   to complete
    attr_accessor :write_ap_dly

    # Customizable delay for DUT-specific required cycles for acc_access transaction
    #   to complete
    attr_accessor :acc_access_dly

    # Customizable random number generator mode.
    #   compress: any uncompared data will be set to 0 when shifted out for better vector compression
    #   unrolled: any uncompared data will be set to 5 when shifted out for complete unrolling of JTAG data
    #   random: true random number generation, not ideal for pattern comparison
    attr_accessor :random_mode

    # Initialize class variables
    #
    # @param [Hash] options Options to customize the operation
    #
    # @example
    #   # Create new SWD::Driver object
    #   DUT.new.arm_debug.swj_dp
    #
    def initialize(options = {})
      @random_mode = :compress
      @write_ap_dly = 8
      @acc_access_dly = 7
      @current_apaddr = 0
      @orundetect = 0

      add_reg :ir,        0x00,  4, data: { pos: 0, bits: 4 }    # ARM-JTAG Instruction Register

      add_reg :swd_dp,    0x00, 32, data: { pos: 0, bits: 32 }   # SWD Register

      # jtag-dp only
      add_reg :dpacc,     0x00, 35, rnw:  { pos: 0 },            # DP-Access Register (DPACC)
                                    a:    { pos: 1, bits: 2 },
                                    data: { pos: 3, bits: 32 }

      add_reg :apacc,     0x00, 35, rnw:  { pos: 0 },            # AP-Access Register (APACC)
                                    a:    { pos: 1, bits: 2 },
                                    data: { pos: 3, bits: 32 }

      add_reg :idcode,    0x00, 32, data: { pos: 0, bits: 32 }   # Device ID Code Register (IDCODE)
      add_reg :abort,     0x00, 35, rnw:  { pos: 0 },            # Abort Register (ABORT)
                                    a:    { pos: 1, bits: 2 },
                                    data: { pos: 3, bits: 32 }

      # DP Registers
      add_reg :dpidr,     0x00, 32, data: { pos: 0, bits: 32 }
      add_reg :ctrl_stat, 0x04, 32, data: { pos: 0, bits: 32 }
      add_reg :select,    0x08, 32, data: { pos: 0, bits: 32 }, reset: :undefined
      add_reg :rdbuff,    0x0C, 32, data: { pos: 0, bits: 32 }
    end

    def write_register(reg, options = {})
      unless reg.owner == self
        fail 'The SWJ_DP write_register method can only be used for writing its own registers!'
      end
      if protocol != :swd
        fail 'The register-based ARM Debug API is currently only implemented for SWD'
      end
      swd.write_dp(reg)
    end

    def read_register(reg, options = {})
      unless reg.owner == self
        fail 'The SWJ_DP read_register method can only be used for reading its own registers!'
      end
      if protocol != :swd
        fail 'The register-based ARM Debug API is currently only implemented for SWD'
      end
      swd.read_dp(reg)
    end

    def select_bank(address)
      if @bank_initialized
        @bank_initialized = true
        reg(:select).write!(address)
      else
        reg(:select).write!(address) unless reg(:select).data == address
      end
    end

    private

    # Provides shortname access to top-level jtag driver
    def jtag
      parent.parent.jtag
    end

    # Provides shortname access to top-level swd driver
    def swd
      parent.parent.swd
    end

    # Returns protocol implemented at the top-level (i.e. SWD or JTAG)
    def protocol
      if parent.parent.respond_to?(:swd)
        implementation = :swd
      elsif parent.parent.respond_to?(:jtag)
        implementation = :jtag
      end
      implementation
    end

    def log
      Origen.log
    end
  end
end
