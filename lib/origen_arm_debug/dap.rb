require 'origen_arm_debug/dap_controller'
module OrigenARMDebug
  # This is the top-level model that instantiates the DP and APs
  class DAP
    include Origen::Model

    attr_reader :dps, :mem_aps, :jtag_aps

    def initialize(options = {})
      @dps = []
      @mem_aps = []
      @jtag_aps = []
      @latency = options[:latency] || 0
      instantiate_subblocks(options)
    end

    def instantiate_subblocks(options = {})
      if options[:swd] || parent.respond_to?(:swd)
        dps << sub_block(:sw_dp, class_name: 'OrigenARMDebug::SW_DP')
      end

      if options[:jtag] || parent.respond_to?(:jtag)
        dps << sub_block(:jtag_dp, class_name: 'OrigenARMDebug::JTAG_DP')
      end

      Array(options[:mem_aps]).each do |name, base_address|
        add_mem_ap(name, base_address)
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
      mem_aps << sub_block(name.to_sym, class_name: 'OrigenARMDebug::MemAP', base_address: base_address)
    end

    # Returns an array containing all APs
    def aps
      mem_aps + jtag_aps
    end
  end
  Driver = DAP # For legacy API compatibility
end
