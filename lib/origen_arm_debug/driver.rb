module OrigenARMDebug
  # To use this driver the owner model must include the SWD or JTAG protocol drivers:
  #   include JTAG
  #     or
  #   include SWD
  #
  class Driver
    # Returns the parent object that instantiated the driver, could be
    # either a DUT object or a protocol abstraction
    attr_reader :owner

    def jtag
       owner.jtag
    end

    # Initialize class variables
    #
    # @param [Object] owner Parent object
    # @param [Hash] options Options to customize the operation
    #
    # @example
    #   DUT.new.arm_debug
    #
    def initialize(owner, options = {})
      @owner = owner
    end

    # Create and/or return the SWJ_DP object with specified protocol
    def swj_dp
      if owner.respond_to?(:swd)
        @swj_dp ||= SWJ_DP.new(self, :swd)
      elsif owner.respond_to?(:jtag)
        @swj_dp ||= SWJ_DP.new(self, :jtag)
      end
    end

    # Returns an instance of the OrigenARMDebug::MemAP
    def mem_ap
      @mem_ap ||= MemAP.new(self)
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
      instance_variable_set("@#{name}", MemAP.new(self, name: name, base_address: base_address))
      self.class.send(:attr_accessor, name)
    end

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
        ap = options[:ap]
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
        ap = options[:ap]
      end
      ap.write_register(reg_or_val, options)
    end

    def inspect_driver
      Origen.log.info "ARM Debug Driver = #{arm_debug_driver}"
    end

    private

    # Short-cut to protocol driver
    def arm_debug_driver
      return @arm_debug_driver if @arm_debug_driver
      if owner.respond_to?(:jtag)
        @arm_debug_driver = owner.jtag
      elsif owner.respond_to?(:swd)
        @arm_debug_driver = owner.swd
      else
        puts 'Cannot find a compatible physical driver!'
        puts 'The ARM debug protocol supports the following phyiscal drivers:'
        puts '  JTAG - http://origen-sdk.org/origen_jtag'
        puts '  Single Wire Debug - http://origen-sdk.org/origen_swd'
        puts '  Background Debug - http://origen-sdk.org/origen_bdm'
        puts "Add one to your #{owner.class} to resolve this error."
        fail 'ARM Debug error!'
      end
    end
  end
end
