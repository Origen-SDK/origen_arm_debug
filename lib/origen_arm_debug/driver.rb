module OrigenARMDebug
  # To use this driver the owner model must include the SWD or JTAG protocol drivers:
  #   include JTAG
  #     or
  #   include SWD
  #
  class Driver
    include Origen::Model

    # Returns the parent object that instantiated the driver, could be
    # either a DUT object or a protocol abstraction
    attr_reader :owner

    # Initialize class variables
    #
    # @param [Hash] options Options to customize the operation
    #
    # @example
    #   DUT.new.arm_debug
    #
    def initialize(options = {})
      # 'buffer' register to bridge the actual memory-mapped register to the internal DAP transactions
      #   (also used to support case on non-register based calls)
      add_reg :buffer, 0x00, 32, data: { pos: 0, bits: 32 }

      instantiate_subblocks(options)
    end

    def instantiate_subblocks(options = {})
      sub_block :swj_dp, class_name: 'OrigenARMDebug::SWJ_DP'

      if options[:aps].nil?
        add_mem_ap('mem_ap', 0x00000000)
      else
        options[:aps].each do |key, value|
          add_mem_ap(key, value)
        end
      end
    end

    # Method to add additional Memory Access Ports (MEM-AP) with specified base address
    #
    # @param [Integer] name Short name for mem_ap that is being created
    # @param [Integer] base_address Base address
    #
    # @examples
    #   arm_debug.add_mem_ap('alt_ahbapi', 0x02000000)
    #
    def add_mem_ap(name, base_address)
      domain name.to_sym
      sub_block name.to_sym, class_name: 'OrigenARMDebug::MemAP', base_address: base_address
    end

    # Create and/or return the SWJ_DP object with specified protocol
    # def swj_dp
    #  if parent.respond_to?(:swd)
    #    @swj_dp ||= SWJ_DP.new(self, :swd)
    #  elsif parent.respond_to?(:jtag)
    #    @swj_dp ||= SWJ_DP.new(self, :jtag)
    #  end
    # end
    def abs_if
      swj_dp
    end
    alias_method :apapi, :abs_if
    alias_method :dpapi, :abs_if

    # Read from a MEM-AP register
    #
    # @param [Integer, Origen::Register::Reg, Origen::Register::BitCollection, Origen::Register::Bit] reg_or_val
    #   Value to be read. If a reg/bit collection is supplied this can be pre-marked for
    #   read, store or overlay and which will result in the requested action being applied to
    #   the cycles corresponding to those bits only (don't care cycles will be generated for the others).
    # @param [Hash] options Options to customize the operation
    def read_register(reg_or_val, options = {})
      if options[:ap].nil?
        ap = mem_ap           # default to 'mem_ap' if no AP is specified as an option
      else
        ap = eval(options[:ap].to_s)
      end
      ap.read_register(reg_or_val, options)
    end

    # Write data to a MEM-AP register
    #
    # @param [Integer, Origen::Register::Reg, Origen::Register::BitCollection, Origen::Register::Bit] reg_or_val
    #   Value to be written to. If a reg/bit collection is supplied this can be pre-marked for
    #   read, store or overlay and which will result in the requested action being applied to
    #   the cycles corresponding to those bits only (don't care cycles will be generated for the others).
    # @param [Hash] options Options to customize the operation
    def write_register(reg_or_val, options = {})
      if options[:ap].nil?
        ap = mem_ap           # default to 'mem_ap' if no AP is specified as an option
      else
        ap = eval(options[:ap].to_s)
      end
      ap.write_register(reg_or_val, options)
    end

    def jtag
      parent.jtag
    end

    def swd
      parent.swd
    end
  end
end
