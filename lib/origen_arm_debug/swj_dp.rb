module OrigenARMDebug
  class SWJ_DP
    include Origen::Registers

    # Returns the parent object that instantiated the driver, could be
    # either a DUT object or a protocol abstraction
    attr_reader :owner
    attr_reader :imp
    attr_accessor :write_ap_dly
    attr_accessor :acc_access_dly

    # Initialize class variables
    #
    # @param [Object] owner Parent object
    # @param [Hash] options Options to customize the operation
    #
    # @example
    #   # Create new SWD::Driver object
    #   DUT.new.arm_debug.swj_dp
    #
    def initialize(owner, implementation, options = {})
      @owner = owner

      if implementation == :jtag || implementation == :swd
        @imp = implementation
      else
        msg = "SWJ-DP: '#{implementation}' implementation not supported.  JTAG and SWD only"
        Origen.log.error msg

        # Just default to jtag for now
        @imp = :jtag
      end

      @write_ap_dly = 8
      @acc_access_dly = 7

      @current_apaddr = 0
      @orundetect = 0

      add_reg :dpacc,     0x00, 35,  rnw:  { pos: 0 },
                                     a:    { pos: 1, bits: 2 },
                                     data: { pos: 3, bits: 32 }

      add_reg :apacc,     0x00, 35,  rnw:  { pos: 0 },
                                     a:    { pos: 1, bits: 2 },
                                     data: { pos: 0, bits: 35 }

      add_reg :reserved,  0x00, 32, data: { pos: 0, bits: 32 }
      add_reg :ctrl_stat, 0x04, 32, data: { pos: 0, bits: 32 }
      add_reg :select,    0x08, 32, data: { pos: 0, bits: 32 }
      add_reg :rebuff,    0x0C, 32, data: { pos: 0, bits: 32 }

      # jtag-dp only
      add_reg :idcode,    0x00, 32, data: { pos: 0, bits: 32 }
      add_reg :abort,     0x00, 35,  rnw:  { pos: 0 },
                                     a:    { pos: 1, bits: 2 },
                                     data: { pos: 0, bits: 32 }
    end

    #-------------------------------------
    #  DPACC Access API
    #-------------------------------------

    # Method to read from a Debug Port register
    #
    # @param [String] name Name of register to be read from
    #   Supports: 'IDCODE','ABORT','CTRL/STAT','SELECT','RDBUFF','WCR','RESEND'
    # @param [Hash] options Options to customize the operation
    # @option options [Integer] edata Value to compare read data against
    def read_dp(name, options = {})
      options = { r_attempts: 1, mask: 0xffffffff }.merge(options)
      if @imp == :swd
        read_dp_swd(name, options)
      else
        read_dp_jtag(name, options)
      end
    end

    # Method to read from a Debug Port register and compare for an expected value
    #
    # @param [String] name Name of register to be read from
    #   Supports: 'IDCODE','ABORT','CTRL/STAT','SELECT','RDBUFF','WCR','RESEND'
    # @param [Integer] edata Value to compare read data against
    # @param [Hash] options Options to customize the operation
    def read_expect_dp(name, edata, options = {})
      options[:edata] = edata
      read_dp(name, options)
    end

    # Method to write to a Debug Port register
    #
    # @param [String] name Name of register to be written to
    #   Supports: 'IDCODE','ABORT','CTRL/STAT','SELECT','RDBUFF','WCR','RESEND'
    # @param [Integer] wdata Value to written
    # @param [Hash] options Options to customize the operation
    def write_dp(name, wdata, options = {})
      options = { w_attempts: 1 }.merge(options)
      if @imp == :swd
        write_dp_swd(name, wdata, options)
      else
        write_dp_jtag(name, wdata, options)
      end
    end

    # Method to write to and then read from a Debug Port register
    #
    # @param [String] name Name of register to be written to and read from
    #   Supports: 'IDCODE','ABORT','CTRL/STAT','SELECT','RDBUFF','WCR','RESEND'
    # @param [Integer] wdata Value to written
    # @param [Hash] options Options to customize the operation
    def write_read_dp(name, wdata, options = {})
      write_dp(name, wdata, options)
      read_dp(name, options)
      if @imp == :swd
        cc "SW-DP: WR-32: name='#{name}', "\
          "data=0x#{wdata.to_s(16).rjust(8, '0')}"
      else
        cc "JTAG-DP: WR-32: name='#{name}', "\
          "data=0x#{wdata.to_s(16).rjust(8, '0')}"
      end
    end

    #-------------------------------------
    #  APACC Access API
    #-------------------------------------

    # Method to read from a Access Port register
    #
    # @param [Integer] addr Address of register to be read from
    # @param [Hash] options Options to customize the operation
    # @option options [Integer] edata Value to compare read data against
    def read_ap(addr, options = {})
      rwb = 1
      options = { r_attempts: 1 }.merge(options)

      # Create another copy of options with select keys removed.
      # This first read is junk so we do not want to store it or compare it.
      junk_options = options.clone.delete_if do |key, val|
        (key.eql?(:r_mask) && val.eql?('store')) || key.eql?(:compare_data)
      end

      apacc_access(addr, rwb, random, 0, junk_options)
      read_dp('RDBUFF', options)                     # This is the real data

      if @imp == :swd
        cc "SW-AP: R-32: addr=0x#{addr.to_s(16).rjust(8, '0')}"
      else
        cc "JTAG-AP: R-32: addr=0x#{addr.to_s(16).rjust(8, '0')}"
      end
    end

    # Method to read from a Access Port register and compare against specific value
    #
    # @param [Integer] addr Address of register to be read from
    # @param [Integer] edata Value to compare read data against
    # @param [Hash] options Options to customize the operation
    def read_expect_ap(addr, edata, options = {})
      options[:edata] = edata
      read_ap(name, options)
    end
    alias_method :wait_read_expect_ap, :read_expect_ap

    # Method to write to a Access Port register
    #
    # @param [Integer] addr Address of register to be read from
    # @param [Integer] wdata Value to written
    # @param [Hash] options Options to customize the operation
    def write_ap(addr, wdata, options = {})
      rwb = 0
      options = { w_attempts: 1 }.merge(options)
      apacc_access(addr, rwb, wdata, 0, options)
      $tester.cycle(repeat: @write_ap_dly) if @imp == :jtag
      if @imp == :swd
        cc 'SW-AP: W-32: '\
          "addr=0x#{addr.to_s(16).rjust(8, '0')}, "\
          "data=0x#{wdata.to_s(16).rjust(8, '0')}"
      else
        cc 'JTAG-AP: W-32: '\
          "addr=0x#{addr.to_s(16).rjust(8, '0')}, "\
          "data=0x#{wdata.to_s(16).rjust(8, '0')}"
      end
    end

    # Method to write to and then read from a Debug Port register
    #
    # @param [Integer] addr Address of register to be read from
    # @param [Integer] wdata Value to written
    # @param [Hash] options Options to customize the operation
    def write_read_ap(addr, wdata, options = {})
      write_ap(addr, wdata, options)
      read_ap(addr, options)
      if @imp == :swd
        cc 'SW-AP: WR-32: '\
          "addr=0x#{addr.to_s(16).rjust(8, '0')}, "\
          "data=0x#{wdata.to_s(16).rjust(8, '0')}"
      else
        cc 'JTAG-AP: WR-32: '\
          "addr=0x#{addr.to_s(16).rjust(8, '0')}, "\
          "data=0x#{wdata.to_s(16).rjust(8, '0')}"
      end
    end

    private

    #-----------------------------------------------
    #  DPACC Access Implementation-Specific methods
    #-----------------------------------------------

    # Method to read from a Debug Port register with SWD protocol
    #
    # @param [String] name Name of register to be read from
    #   Supports: 'IDCODE','ABORT','CTRL/STAT','SELECT','RDBUFF','WCR','RESEND'
    # @param [Hash] options Options to customize the operation
    def read_dp_swd(name, options = {})
      rwb = 1
      case name
        when 'IDCODE'    then dpacc_access(name, rwb, random, options)
        when 'ABORT'     then Origen.log.error "#{name} #{@imp.to_s.upcase}-DP register is write-only!"
        when 'CTRL/STAT' then dpacc_access(name, rwb, random, options)
        when 'SELECT'    then Origen.log.error "#{name} #{@imp.to_s.upcase}-DP register is write-only!"
        when 'RDBUFF'    then dpacc_access(name, rwb, random, options)
        when 'WCR'       then dpacc_access(name, rwb, random, options)
        when 'RESEND'    then dpacc_access(name, rwb, random, options)
        else Origen.log.error "Unknown #{@imp.to_s.upcase}-DP register name #{name}"
      end
      cc "SW-DP: R-32: name='#{name}'"
    end

    # Method to read from a Debug Port register with JTAG protocol
    #
    # @param [String] name Name of register to be read from
    #   Supports: 'IDCODE','ABORT','CTRL/STAT','SELECT','RDBUFF','WCR','RESEND'
    # @param [Hash] options Options to customize the operation
    def read_dp_jtag(name, options = {})
      rwb = 1
      set_ir(name) if name == 'IDCODE'
      case name
        when 'IDCODE'    then jtag.write_dr(random, size: 32)
        when 'ABORT'     then Origen.log.error "#{name} #{@imp.to_s.upcase}-DP register is write-only!"
        when 'CTRL/STAT' then dpacc_access(name, rwb, random, options)
        when 'SELECT'    then dpacc_access(name, rwb, random, options)
        when 'RDBUFF'    then dpacc_access(name, rwb, random, options)
        else Origen.log.error "Unknown #{@imp.to_s.upcase}-DP register name #{name}"
      end
      read_dp_jtag('RDBUFF', options) if name != 'IDCODE' && name != 'RDBUFF'
      cc "JTAG-DP: R-32: name='#{name}'"
    end

    # Method to write to a Debug Port register with SWD protocol
    #
    # @param [String] name Name of register to be read from
    #   Supports: 'IDCODE','ABORT','CTRL/STAT','SELECT','RDBUFF','WCR','RESEND'
    # @param [Integer] wdata Data to be written
    # @param [Hash] options Options to customize the operation
    def write_dp_swd(name, wdata, options = {})
      rwb = 0
      case name
        when 'IDCODE'    then Origen.log.error "#{name} #{@imp.to_s.upcase}-DP register is read-only!"
        when 'ABORT'     then dpacc_access(name, rwb, wdata, options)
        when 'CTRL/STAT' then dpacc_access(name, rwb, wdata, options)
        when 'SELECT'    then dpacc_access(name, rwb, wdata, options)
        when 'RDBUFF'    then Origen.log.error "#{name} #{@imp.to_s.upcase}-DP register is read-only!"
        when 'WCR'       then dpacc_access(name, rwb, wdata, options)
        when 'RESEND'    then Origen.log.error "#{name} #{@imp.to_s.upcase}-DP register is read-only!"
        else Origen.log.error "Unknown #{@imp.to_s.upcase}-DP register name #{name}"
      end
      cc "SW-DP: W-32: name='#{name}', "\
        "data=0x#{wdata.to_s(16).rjust(8, '0')}"
    end

    # Method to write to a Debug Port register with JTAG protocol
    #
    # @param [String] name Name of register to be read from
    #   Supports: 'IDCODE','ABORT','CTRL/STAT','SELECT','RDBUFF','WCR','RESEND'
    # @param [Integer] wdata Data to be written
    # @param [Hash] options Options to customize the operation
    def write_dp_jtag(name, wdata, options = {})
      rwb = 0
      case name
        when 'IDCODE'    then Origen.log.error "#{name} #{@imp.to_s.upcase}-DP register is read-only!"
        when 'ABORT'     then dpacc_access(name, rwb, wdata, options)
        when 'CTRL/STAT' then dpacc_access(name, rwb, wdata, options)
        when 'SELECT'    then dpacc_access(name, rwb, wdata, options)
        when 'RDBUFF'    then Origen.log.error "#{name} #{@imp.to_s.upcase}-DP register is read-only!"
        else Origen.log.error "Unknown #{@imp.to_s.upcase}-DP register name #{name}"
      end
      cc "JTAG-DP: W-32: name='#{name}', "\
        "data=0x#{wdata.to_s(16).rjust(8, '0')}"
    end

    def dpacc_access(name, rwb, wdata, options = {})
      addr = get_dp_addr(name)

      if name == 'CTRL/STAT' && @imp == :swd
        set_apselect(@current_apaddr & 0xFFFFFFFE, options)
      end
      set_ir(name) if @imp == :jtag
      acc_access(addr, rwb, 0, wdata, options)
    end

    def apacc_access(addr, rwb, wdata, rdata, options = {})
      set_apselect((addr & 0xFFFFFFFE) | (@current_apaddr & 1), options)
      if @imp == :swd
        options.delete(:w_delay) if options.key?(:w_delay)
      else
        set_ir('APACC')
      end
      acc_access((addr & 0xC), rwb, 1, wdata, options)
    end

    def acc_access(addr, rwb, ap_dp, wdata, options = {})
      if @imp == :swd
        acc_access_swd(addr, rwb, ap_dp, wdata, options = {})
      else
        acc_access_jtag(addr, rwb, ap_dp, wdata, options = {})
      end
    end

    def acc_access_swd(addr, rwb, ap_dp, wdata, options = {})
      if (rwb == 1)
        swd.read(ap_dp, addr, options)
      else
        swd.write(ap_dp, addr, wdata, options)
      end
      options = { w_delay: 10 }.merge(options)
      swd.swd_dio_to_0(options[:w_delay])
    end

    def acc_access_jtag(addr, rwb, ap_dp, wdata, options = {})
      if !options[:r_attempts].nil?
        attempts = options[:r_attempts]
      elsif !options[:r_attempts].nil?
        attempts = options[:w_attempts]
      else
        attempts = 1
      end

      attempts.times do
        if name == 'RDBUFF'
          r = $dut.reg(:dap)
          if options[:r_mask] == 'store'
            r.bits(3..34).store
          elsif options.key?(:compare_data)
            r.bits(3..34).data = options[:compare_data]
          end

          options = options.merge(size: r.size)
          jtag.read_dr(r, options)
        else
          options = options.merge(size: 35)
          addr_3_2 = (addr & 0x0000000C) >> 2
          wr_data = (wdata << 3) | (addr_3_2 << 1) | rwb
          jtag.write_dr(wr_data, options)
        end
      end
      $tester.cycle(repeat: @acc_access_dly)
    end

    def get_dp_addr(name)
      case name
        when 'IDCODE'    then return 0x0
        when 'ABORT'     then return 0x0
        when 'CTRL/STAT' then return 0x4
        when 'SELECT'    then return 0x8
        when 'RDBUFF'    then return 0xC
        when 'WCR'       then return 0x4
        when 'RESEND'    then return 0x8
        else Origen.log.error "Unknown #{@imp.to_s.upcase}-DP register name #{name}"
      end
    end

    def set_ir(name)
      new_ir = get_ir_code(name)
      jtag.write_ir(new_ir, size: 4)
    end

    def get_ir_code(name)
      case name
        when 'IDCODE'    then return 0b1110   # JTAGC_ARM_IDCODE
        when 'ABORT'     then return 0b1000   # JTAGC_ARM_ABORT
        when 'CTRL/STAT' then return 0b1010   # JTAGC_ARM_DPACC
        when 'SELECT'    then return 0b1010   # JTAGC_ARM_DPACC
        when 'RDBUFF'    then return 0b1010   # JTAGC_ARM_DPACC
        when 'RESEND'    then Origen.log.error "#{name} is a SW-DP only register"
        when 'WCR'       then Origen.log.error "#{name} is a SW-DP only register"
        when 'APACC'     then return 0b1011   # JTAGC_ARM_APACC
        else Origen.log.error "Unknown JTAG-DP register name: #{name}"
      end
      0
    end

    def set_apselect(addr, options = {})
      if @imp == :swd
        addr &= 0xff0000f1
      else
        addr &= 0xff0000f0
      end

      if (addr != @current_apaddr)
        write_dp('SELECT', addr & 0xff0000ff, options)
      end
      @current_apaddr = addr
    end

    # Generates 32-bit random number.  Although, for pattern comparison
    #   it is better to used the same value so that is what is used here.
    #   To turn on random-ness, un-comment rand() line.
    def random
      # rand(4294967295)  # random 32-bit integer
      # 0x55555555        # completely unroll jtag data shift
      0x00000000          # compress read out jtag shifts
    end

    # Provides shortname access to top-level jtag driver
    def jtag
      owner.owner.jtag
    end

    # Provides shortname access to top-level swd driver
    def swd
      owner.owner.swd
    end
  end
end
