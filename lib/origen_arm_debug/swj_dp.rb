module OrigenARMDebug
  # Object that defines API for performing Debug AP transations using SWD or JTAG
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
                                    data: { pos: 0, bits: 32 }

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
    #   Supports: :idcode,:abort,:ctrl_stat,:select,:rdbuff,:wcr,:resend
    # @param [Integer] data Value to be read
    # @param [Hash] options Options to customize the operation
    def read_dp(name, data, options = {})
      if protocol == :swd
        case name
          when :idcode, :ctrl_stat, :rdbuff, :wcr, :resend
            dpacc_access(name, 1, data, options)
          when :abort, :ctrl_stat
            log.error "#{name} #{protocol.to_s.upcase}-DP register is write-only!"
          else
            log.error "Unknown #{protocol.to_s.upcase}-DP register name #{name}"
        end
      else
        case name
          when :idcode
            set_ir(name)
            jtag.write_dr(random, size: 32)
          when :abort
            log.error "#{name} #{protocol.to_s.upcase}-DP register is write-only!"
          when :ctrl_stat, :select
            dpacc_access(name, 1, random, options)
          when :rdbuff
            dpacc_access(name, 1, data, options)
          else
            log.error "Unknown #{protocol.to_s.upcase}-DP register name #{name}"
        end
        read_dp(:rdbuff, data, options) if name != :idcode && name != :rdbuff
      end
      msg = "#{protocol.to_s.upcase}-DP: R-32: name='#{name.to_s.upcase}'"
      msg += ", expected=#{data.to_s(16).rjust(8, '0')}"     # if name == :rdbuff
      cc msg
    end

    # Method to write to a Debug Port register
    #
    # @param [String] name Name of register to be written to
    #   Supports: :idcode,:abort,:ctrl_stat,:select,:rdbuff,:wcr,:resend
    # @param [Integer] data Value to written
    # @param [Hash] options Options to customize the operation
    def write_dp(name, data, options = {})
      if protocol == :swd
        case name
          when :idcode, :rdbuff, :resend
            log.error "#{name} #{protocol.to_s.upcase}-DP register is read-only!"
          when :abort, :ctrl_stat, :select, :wcr
            dpacc_access(name, 0, data, options)
          else
            log.error "Unknown #{protocol.to_s.upcase}-DP register name #{name}"
        end
      else
        case name
          when :idcode, :rdbuff
            log.error "#{name} #{protocol.to_s.upcase}-DP register is read-only!"
          when :abort, :ctrl_stat, :select
            dpacc_access(name, 0, data, options)
          else
            log.error "Unknown #{protocol.to_s.upcase}-DP register name #{name}"
        end
      end
      cc "#{protocol.to_s.upcase}-DP: W-32: name='#{name.to_s.upcase}', data=0x#{data.to_s(16).rjust(8, '0')}"
    end

    # Method to write to and then read from a Debug Port register
    #
    # @param [String] name Name of register to be written to and read from
    #   Supports: :idcode,:abort,:ctrl_stat,:select,:rdbuff,:wcr,:resend
    # @param [Integer] data Value to written
    # @param [Hash] options Options to customize the operation
    def write_read_dp(name, data, options = {})
      write_dp(name, data, options)
      if options[:actual].nil?
        read_dp(name, data, options)
      else
        rdata = options.delete(:actual)
        read_dp(name, rdata, options)
      end

      cc "#{protocol.to_s.upcase}-DP: WR-32: name='#{name.to_s.upcase}', data=0x#{data.to_s(16).rjust(8, '0')}"
    end

    #-------------------------------------
    #  APACC Access API
    #-------------------------------------

    # Method to read from a Access Port register
    #
    # @param [Integer] addr Address of register to be read from
    # @param [Hash] options Options to customize the operation
    # @option options [Integer] edata Value to compare read data against
    def read_ap(addr, data, options = {})
      rwb = 1
      # Create another copy of options with select keys removed.
      # This first read is junk so we do not want to store it or compare it.
      junk_options = options.clone.delete_if do |key, val|
        (key.eql?(:r_mask) && val.eql?('store')) || key.eql?(:compare_data) || key.eql?(:reg)
      end
      junk_options[:mask] = 0x00000000
      apacc_access(addr, rwb, random, junk_options)
      read_dp(:rdbuff, data, options)                     # This is the real data
      cc "#{protocol.to_s.upcase}-AP: R-32: addr=0x#{addr.to_s(16).rjust(8, '0')}"
    end

    # Method to read from a Access Port register and compare against specific value
    #
    # @param [Integer] addr Address of register to be read from
    # @param [Integer] edata Value to compare read data against
    # @param [Hash] options Options to customize the operation
    def read_expect_ap(addr, options = {})
      # Warn caller that this method is being deprecated
      msg = 'Use swj_dp.read_ap(addr, data, options) instead of read_expect_ap(addr, edata: 0xXXXXXXX)'
      Origen.deprecate msg

      edata = options[:edata] || 0x00000000
      read_ap(addr, edata, options)
    end
    alias_method :wait_read_expect_ap, :read_expect_ap

    # Method to write to a Access Port register
    #
    # @param [Integer] addr Address of register to be read from
    # @param [Integer] data Value to written
    # @param [Hash] options Options to customize the operation
    def write_ap(addr, data, options = {})
      rwb = 0
      options[:mask] = 0x00000000
      # options = { w_attempts: 1 }.merge(options)
      apacc_access(addr, rwb, data, options)
      $tester.cycle(repeat: @write_ap_dly) if protocol == :jtag
      cc "#{protocol.to_s.upcase}-AP: W-32: "\
         "addr=0x#{addr.to_s(16).rjust(8, '0')}, "\
         "data=0x#{data.to_s(16).rjust(8, '0')}"
    end

    # Method to write to and then read from a Debug Port register
    #
    # @param [Integer] addr Address of register to be read from
    # @param [Integer] data Value to written
    # @param [Hash] options Options to customize the operation
    def write_read_ap(addr, data, options = {})
      # Warn caller that this method is being deprecated
      msg = 'Use write_ap(addr, data, options); read_ap(addr, data, options) instead of write_read_ap'
      Origen.deprecate msg

      write_ap(addr, data, options)
      if options[:edata].nil?
        read_ap(addr, data, options)
      else
        read_ap(addr, options[:edata], options)
      end

      cc "#{protocol.to_s.upcase}: WR-32: "\
         "addr=0x#{addr.to_s(16).rjust(8, '0')}, "\
         "data=0x#{data.to_s(16).rjust(8, '0')}"
    end

    private

    #-----------------------------------------------
    #  DPACC Access Implementation-Specific methods
    #-----------------------------------------------

    # Method
    #
    # @param [Integer] name Name of register to be transacted
    # @param [Integer] rwb Indicates read or write
    # @param [Integer] data Value of data to be written
    # @param [Hash] options Options to customize the operation
    def dpacc_access(name, rwb, data, options = {})
      addr = get_dp_addr(name)
      if name == :ctrl_stat && protocol == :swd
        set_apselect(@current_apaddr & 0xFFFFFFFE, options)
      end
      set_ir(name) if protocol == :jtag
      options = { name: name }.merge(options)
      acc_access(addr, rwb, 0, data, options)
    end

    # Method
    #
    # @param [Integer] addr Address of register to be transacted
    # @param [Integer] rwb Indicates read or write
    # @param [Integer] data Value of data to be written
    # @param [Hash] options Options to customize the operation
    def apacc_access(addr, rwb, data, options = {})
      set_apselect((addr & 0xFFFFFFFE) | (@current_apaddr & 1), options)
      if protocol == :swd
        options.delete(:w_delay) if options.key?(:w_delay)
      else
        set_ir(:apacc)
      end
      options = { name: :apacc }.merge(options)
      acc_access((addr & 0xC), rwb, 1, data, options)
    end

    # Method
    #
    # @param [Integer] addr Address of register to be transacted
    # @param [Integer] rwb Indicates read or write
    # @param [Integer] ap_dp Indicates Access Port or Debug Port
    # @param [Integer] data Value of data to be written
    # @param [Hash] options Options to customize the operation
    def acc_access(addr, rwb, ap_dp, data, options = {})
      if protocol == :swd
        acc_access_swd(addr, rwb, ap_dp, data, options)
      else
        acc_access_jtag(addr, rwb, ap_dp, data, options)
      end
    end

    # Method SWD-specific
    #
    # @param [Integer] addr Address of register to be transacted
    # @param [Integer] rwb Indicates read or write
    # @param [Integer] ap_dp Indicates Access Port or Debug Port
    # @param [Integer] data Value of data to be written
    # @param [Hash] options Options to customize the operation
    def acc_access_swd(addr, rwb, ap_dp, data, options = {})
      _name = options.delete(:name)
      if (rwb == 1)
        reg(:swd_dp).address = addr
        reg(:swd_dp).bits(:data).clear_flags
        reg(:swd_dp).bits(:data).write(data)
        _mask = options[:mask] || 0xFFFFFFFF
        _store = options[:store] || 0x00000000
        0.upto(31) do |i|
          reg(:swd_dp).bits(:data)[i].read if _mask[i] == 1
          reg(:swd_dp).bits(:data)[i].store if _store[i] == 1
        end
        options = options.merge(size: reg(:swd_dp).size)
        swd.read(ap_dp, reg(:swd_dp), options)
      else
        reg(:swd_dp).bits(:data).write(data)
        reg(:dpacc).address = addr
        options = options.merge(size: reg(:swd_dp).size)
        swd.write(ap_dp, reg(:swd_dp), reg(:swd_dp).data, options)
      end
      options = { w_delay: 10 }.merge(options)
      swd.swd_dio_to_0(options[:w_delay])
    end

    # Method JTAG-specific
    #
    # @param [Integer] addr Address of register to be transacted
    # @param [Integer] rwb Indicates read or write
    # @param [Integer] ap_dp Indicates Access Port or Debug Port
    # @param [Integer] data Value of data to be written
    # @param [Hash] options Options to customize the operation
    def acc_access_jtag(addr, rwb, ap_dp, data, options = {})
      _name = options.delete(:name)
      attempts = options[:attempts] || 1
      attempts.times do
        if _name == :rdbuff
          reg(:dpacc).bits(:data).clear_flags
          reg(:dpacc).bits(:data).write(data)
          _mask = options[:mask] || 0xFFFFFFFF
          _store = options[:store] || 0x00000000
          0.upto(31) do |i|
            reg(:dpacc).bits(:data)[i].read if _mask[i] == 1
            reg(:dpacc).bits(:data)[i].store if _store[i] == 1
          end
          options = options.merge(size: reg(:dpacc).size)
          jtag.read_dr(reg(:dpacc), options)
        else
          reg(:dpacc).bits(:data).write(data)
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
        when :idcode    then return 0x0
        when :abort     then return 0x0
        when :ctrl_stat then return 0x4
        when :select    then return 0x8
        when :rdbuff    then return 0xC
        when :wcr       then return 0x4
        when :resend    then return 0x8
      end
    end

    # Shifts IR code into the JTAG/ARM Instruction Regsiter based on requested Register Name
    #
    # @param [String] name Name of the register to be interacted with
    def set_ir(name)
      case name
        when :idcode
          reg(:ir).write(0b1110)                          # JTAGC_ARM_IDCODE
        when :abort
          reg(:ir).write(0b1000)                          # JTAGC_ARM_ABORT
        when :ctrl_stat, :select, :rdbuff
          reg(:ir).write(0b1010)                          # JTAGC_ARM_DPACC
        when :apacc
          reg(:ir).write(0b1011)                          # JTAGC_ARM_APACC
      end
      jtag.write_ir(reg(:ir), size: reg(:ir).size)
    end

    # Method to select an Access Port (AP) by writing to the SELECT register in the Debug Port
    #
    # @param [Integer] addr Address to be written to the SELECT register.  It's value
    #    will determine which Access Port is selected.
    # @param [Hash] options Options to customize the operation
    def set_apselect(addr, options = {})
      if protocol == :swd
        addr &= 0xff0000f1
      else
        addr &= 0xff0000f0
      end

      if (addr != @current_apaddr)
        write_dp(:select, addr & 0xff0000ff, options)
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
