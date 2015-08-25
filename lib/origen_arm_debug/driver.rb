module OrigenARMDebug
  class Driver
    # Returns the parent object that instantiated the driver, could be
    # either a DUT object or a protocol abstraction
    attr_reader :owner

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
    # name - short name for mem_ap that is being created
    # base_address - base address
    def add_mem_ap(name, base_address)
      instance_variable_set("@#{name}", MemAP.new(self, name: name, base_address: base_address))
      self.class.send(:attr_accessor, name)
    end

    def read_register(reg_or_val, options = {})
      mem_ap.read(reg_or_val.address, size: reg_or_val.size, compare_data: reg_or_val.data)
    end

    def write_register(reg_or_val, options = {})
      mem_ap.write(reg_or_val.address, reg_or_val.data, size: reg_or_val.size)
    end

    private

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
