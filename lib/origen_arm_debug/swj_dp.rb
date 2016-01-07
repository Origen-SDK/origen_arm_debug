module OrigenARMDebug
  # Object that defines API for performing Debug AP transations using SWD or JTAG
  class SWJ_DP
    include Origen::Registers

    # Returns the parent object that instantiated the driver, could be
    # either a DUT object or a protocol abstraction
    attr_reader :owner

    # Protocol implemented at the top-level (i.e. SWD or JTAG)
    attr_reader :imp

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
        fail msg
      end

      @random_mode = :compress

      @write_ap_dly = 8
      @acc_access_dly = 7

      @current_apaddr = 0
      @orundetect = 0

      add_reg :ir,        0x00,  4, data: { pos: 0, bits: 4 }      # ARM-JTAG Instruction Register

      add_reg :dpacc,     0x00, 35, rnw:  { pos: 0 },            # DP-Access Register (DPACC)
                                    a:    { pos: 1, bits: 2 },
                                    data: { pos: 3, bits: 32 }

      add_reg :apacc,     0x00, 35, rnw:  { pos: 0 },            # AP-Access Register (APACC)
                                    a:    { pos: 1, bits: 2 },
                                    data: { pos: 0, bits: 32 }

      # jtag-dp only
      add_reg :idcode,    0x00, 32, data: { pos: 0, bits: 32 }   # Device ID Code Register (IDCODE)
      add_reg :abort,     0x00, 35, rnw:  { pos: 0 },            # Abort Register (ABORT)
                                    a:    { pos: 1, bits: 2 },
                                    data: { pos: 0, bits: 32 }

      # DP Registers
      add_reg :dpidr,     0x00, 32, data: { pos: 0, bits: 32 }
      add_reg :ctrl_stat, 0x04, 32, data: { pos: 0, bits: 32 }
      add_reg :select,    0x08, 32, data: { pos: 0, bits: 32 }
      add_reg :rdbuff,    0x0C, 32, data: { pos: 0, bits: 32 }
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
      msg = "#{@imp.to_s.upcase}-DP: R-32: name='#{name}'"
      msg += ", expected=#{options[:edata].to_s(16).rjust(8, '0')}" unless options[:edata].nil?
      cc msg
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
      cc "#{@imp.to_s.upcase}-DP: W-32: name='#{name}', data=0x#{wdata.to_s(16).rjust(8, '0')}"
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

      cc "#{@imp.to_s.upcase}-DP: WR-32: name='#{name}', data=0x#{wdata.to_s(16).rjust(8, '0')}"
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
        (key.eql?(:r_mask) && val.eql?('store')) || key.eql?(:compare_data) || key.eql?(:reg)
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
      read_ap(addr, options)
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
      read_dp('RDBUFF', options) if name != 'IDCODE' && name != 'RDBUFF'
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
    end

    # Method
    #
    # @param [Integer] name Name of register to be transacted
    # @param [Integer] rwb Indicates read or write
    # @param [Integer] wdata Value of data to be written
    # @param [Hash] options Options to customize the operation
    def dpacc_access(name, rwb, wdata, options = {})
      addr = get_dp_addr(name)

      if name == 'CTRL/STAT' && @imp == :swd
        set_apselect(@current_apaddr & 0xFFFFFFFE, options)
      end
      set_ir(name) if @imp == :jtag
      options = { name: name }.merge(options)
      acc_access(addr, rwb, 0, wdata, options)
    end

    # Method
    #
    # @param [Integer] addr Address of register to be transacted
    # @param [Integer] rwb Indicates read or write
    # @param [Integer] wdata Value of data to be written
    # @param [Integer] rdata Value of data to be read back
    # @param [Hash] options Options to customize the operation
    def apacc_access(addr, rwb, wdata, rdata, options = {})
      set_apselect((addr & 0xFFFFFFFE) | (@current_apaddr & 1), options)
      if @imp == :swd
        options.delete(:w_delay) if options.key?(:w_delay)
      else
        set_ir('APACC')
      end
      options = { name: 'APACC' }.merge(options)
      acc_access((addr & 0xC), rwb, 1, wdata, options)
    end

    # Method
    #
    # @param [Integer] addr Address of register to be transacted
    # @param [Integer] rwb Indicates read or write
    # @param [Integer] ap_dp Indicates Access Port or Debug Port
    # @param [Integer] wdata Value of data to be written
    # @param [Hash] options Options to customize the operation
    def acc_access(addr, rwb, ap_dp, wdata, options = {})
      if @imp == :swd
        acc_access_swd(addr, rwb, ap_dp, wdata, options)
      else
        acc_access_jtag(addr, rwb, ap_dp, wdata, options)
      end
    end

    # Method SWD-specific
    #
    # @param [Integer] addr Address of register to be transacted
    # @param [Integer] rwb Indicates read or write
    # @param [Integer] ap_dp Indicates Access Port or Debug Port
    # @param [Integer] wdata Value of data to be written
    # @param [Hash] options Options to customize the operation
    def acc_access_swd(addr, rwb, ap_dp, wdata, options = {})
      _name = options.delete(:name)
      if (rwb == 1)
        if options[:reg].nil?
          swd.read(ap_dp, addr, options)
        else
          # make sure reg.addr = addr
          Origen.log.error 'SWJ_DP ERROR: In acc_access_swd, addr does not match options[:reg].addr'
          swd.read(ap_dp, options[:reg], options)
        end
      else
        swd.write(ap_dp, addr, wdata, options)
      end
      options = { w_delay: 10 }.merge(options)
      swd.swd_dio_to_0(options[:w_delay])
    end

    # Method JTAG-specific
    #
    # @param [Integer] addr Address of register to be transacted
    # @param [Integer] rwb Indicates read or write
    # @param [Integer] ap_dp Indicates Access Port or Debug Port
    # @param [Integer] wdata Value of data to be written
    # @param [Hash] options Options to customize the operation
    def acc_access_jtag(addr, rwb, ap_dp, wdata, options = {})
      _name = options.delete(:name)
      if !options[:r_attempts].nil?
        attempts = options[:r_attempts]
      elsif !options[:w_attempts].nil?
        attempts = options[:w_attempts]
      else
        attempts = 1
      end

      attempts.times do
        if _name == 'RDBUFF'
          if options[:reg].nil?
            if options[:r_mask] == 'store'
              reg(:dpacc).bits(:data).store
            elsif options.key?(:compare_data)
              reg(:dpacc).bits(:data).data = options[:compare_data]
            elsif options.key?(:edata)
              options[:compare_data] = options[:edata]
              reg(:dpacc).bits(:data).data = options[:edata]
            end
          else
            reg(:dpacc).bits(:data).data = options[:reg].data
            (3..34).each do |i|
              reg(:dpacc).bits(i).read if options[:reg].bits(i - 3).is_to_be_read?
            end
            (3..34).each do |i|
              reg(:dpacc).bits(i).store if options[:reg].bits(i - 3).is_to_be_stored?
            end
          end

          options = options.merge(size: reg(:dpacc).size)
          jtag.read_dr(reg(:dpacc), options)
        else
          reg(:dpacc).bits(:data).write(wdata)
          reg(:dpacc).bits(:a).write((addr & 0x0000000C) >> 2)
          reg(:dpacc).bits(:rnw).write(rwb)
          options = options.merge(size: reg(:dpacc).size)
          jtag.write_dr(reg(:dpacc), options)
        end
      end
      $tester.cycle(repeat: @acc_access_dly)
    end

    # Returns the address of the register based on the name (string) of the register
    #
    # @param [String] name Name of the register
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

    # Shifts IR code into the JTAG/ARM Instruction Regsiter based on requested Register Name
    #
    # @param [String] name Name of the register to be interacted with
    def set_ir(name)
      case name
        when 'IDCODE'
          reg(:ir).write(0b1110)                          # JTAGC_ARM_IDCODE
        when 'ABORT'
          reg(:ir).write(0b1000)                          # JTAGC_ARM_ABORT
        when 'CTRL/STAT', 'SELECT', 'RDBUFF'
          reg(:ir).write(0b1010)                          # JTAGC_ARM_DPACC
        when 'APACC'
          reg(:ir).write(0b1011)                          # JTAGC_ARM_APACC
        when 'RESEND', 'WCR'
          Origen.log.error "#{name} is a SW-DP only register"
        else
          Origen.log.error "Unknown JTAG-DP register name: #{name}"
      end
      jtag.write_ir(reg(:ir), size: reg(:ir).size)
    end

    # Method to select an Access Port (AP) by writing to the SELECT register in the Debug Port
    #
    # @param [Integer] addr Address to be written to the SELECT register.  It's value
    #    will determine which Access Port is selected.
    # @param [Hash] options Options to customize the operation
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

    # Generates 32-bit number for 'dont care' jtag shift outs.  Value generated
    #   depends on class variable 'random_mode'.
    def random
      case @random_mode
        when :compress then return 0x00000000
        when :unrolled then return 0x55555555
        when :random then return rand(4_294_967_295)
        else return 0x00000000
      end
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
