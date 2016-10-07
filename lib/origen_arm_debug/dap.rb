module OrigenARMDebug
  # This is the top-level model that instantiates the DP and APs
  class DAP
    include Origen::Model

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

      @latency = options[:latency] || 0
      instantiate_subblocks(options)
    end

    def instantiate_subblocks(options = {})
      if options[:jtag] || parent.respond_to?(:jtag)
        sub_block :jtag_dp, class_name: 'OrigenARMDebug::JTAG_DP'
      end

      if options[:swd] || parent.respond_to?(:swd)
        sub_block :sw_dp, class_name: 'OrigenARMDebug::SW_DP'
      end

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
      @aps ||= {}
      name = name.to_sym
      domain name
      block = sub_block name.to_sym, class_name: 'OrigenARMDebug::MemAP', base_address: base_address
      @aps[name] = block
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
        ap = default_ap
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
        ap = default_ap
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

    def default_ap
      @aps[:mem_ap] || @aps.first[1]
    end
  end
  Driver = DAP # For legacy API compatibility
end
