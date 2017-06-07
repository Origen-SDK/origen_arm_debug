module OrigenARMDebug
  # This is the top-level model that instantiates the DP and APs
  class DAP
    include Origen::Model

    attr_reader :dps, :mem_aps, :jtag_aps, :ext_aps

    def initialize(options = {})
      @dps = []
      @mem_aps = []         # Array of MEM-APs
      @jtag_aps = []        # Array of JTAG-APs
      @ext_aps = []         # Array of 'extension' APs

      instantiate_subblocks(options)
    end

    def instantiate_subblocks(options = {})
      if options[:swd] || parent.respond_to?(:swd)
        dps << sub_block(:sw_dp, class_name: 'SW_DP')
      end

      if options[:jtag] || parent.respond_to?(:jtag)
        dps << sub_block(:jtag_dp, class_name: 'JTAG_DP')
      end

      Array(options[:mem_aps]).each do |name, base_address|
        if base_address.is_a?(Hash)
          ap_opts = { class_name: 'MemAP' }.merge(base_address)
        else
          ap_opts = { class_name: 'MemAP', base_address: base_address }
        end

        add_ap(name, ap_opts)
      end

      Array(options[:jtag_aps]).each do |name, base_address|
        if base_address.is_a?(Hash)
          ap_opts = { class_name: 'JTAGAP' }.merge(base_address)
        else
          ap_opts = { class_name: 'JTAGAP', base_address: base_address }
        end

        add_ap(name, ap_opts)
      end

      Array(options[:aps]).each do |name, opts|
        if opts.is_a?(Hash)
          klass = opts.delete(:class_name)
          addr = opts.delete(:base_address)
          if klass.nil? || addr.nil?
            fail "[ARM DEBUG] Error: Must specify class_name and base_address if using 'aps' hash to define APs"
          end
          ap_opts = { class_name: klass, base_address: addr }.merge(opts)
        else
          fail "[ARM DEBUG] Error: Must specify class_name and base_address if using 'aps' hash to define APs"
        end

        add_ap(name, ap_opts)
      end
    end

    # Method to add additional Access Ports (MEM-AP)
    #
    # @param [Integer] name Short name for mem_ap that is being created
    # @param [Hash] options Implemenation specific details
    #
    # @examples
    #   arm_debug.add_ap('alt_ahbapi', { class_name: 'OrigenARMDebug::MemAP', base_address: 0x02000000 })
    #
    def add_ap(name, options)
      domain name.to_sym
      ap = sub_block(name.to_sym, options)

      if options[:class_name] == 'MemAP'
        mem_aps << ap
      elsif options[:class_name] == 'JTAGAP'
        jtag_aps << ap
      else
        ext_aps << ap
      end
    end

    # Returns an array containing all APs
    def aps
      mem_aps + jtag_aps + ext_aps
    end
  end
  Driver = DAP # For legacy API compatibility
end
