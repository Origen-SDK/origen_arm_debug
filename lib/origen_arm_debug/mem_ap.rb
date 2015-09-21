module OrigenARMDebug
  # Object that defines the API necessary to perform MEM-AP transactions.  Requires
  #  a top-level protocol be defined as well as a top-level instantiation of an
  #  SWJ-DP object.
  class MemAP
    # ARM Debug Interface v5.1
    MEM_ADDR_CSW  = 0x00000000
    MEM_ADDR_TAR  = 0x00000004
    MEM_ADDR_DRW  = 0x0000000C
    MEM_ADDR_BD0  = 0x00000010
    MEM_ADDR_BD1  = 0x00000014
    MEM_ADDR_BD2  = 0x00000018
    MEM_ADDR_BD3  = 0x0000001C
    MEM_ADDR_CFG  = 0x000000F4
    MEM_ADDR_BASE = 0x000000F8
    MEM_ADDR_IDR  = 0x000000FC

    # Returns the parent object that instantiated the driver
    attr_reader :owner

    # Initialize class variables
    #
    # @param [Object] owner Parent object
    # @param [Hash] options Options to customize the operation
    #
    # @example
    #   DUT.new.arm_debug.mem_ap
    #
    def initialize(owner, options = {})
      @owner = owner
      @name = options[:name].nil? ? 'default' : options[:name]
      @base_address = options[:base_address].nil? ? 0x00000000 : options[:base_address]

      # reset values for MEM-AP registers
      @current_csw = 0x00000000
      @current_tar = 0xffffffff
      @current_dsw = 0x00000000
    end

    # Shortcut name to SWJ-DP Debug Port
    def debug_port
      owner.swj_dp
    end
    alias_method :dp, :debug_port

    # Output some instance-specific information
    def inspect
      Origen.log.info '=' * 30
      Origen.log.info ' MEM-AP INFO'
      Origen.log.info "  name: #{@name}"
      Origen.log.info "  base address: 0x#{@base_address.to_hex}"
      Origen.log.info ''
      Origen.log.debug "  csw_reg_addr  = 0x#{csw_reg_addr.to_hex}"
      Origen.log.debug "  tar_reg_addr  = 0x#{tar_reg_addr.to_hex}"
      Origen.log.debug "  drw_reg_addr  = 0x#{drw_reg_addr.to_hex}"
      Origen.log.debug "  bd0_reg_addr  = 0x#{bd0_reg_addr.to_hex}"
      Origen.log.debug "  bd1_reg_addr  = 0x#{bd1_reg_addr.to_hex}"
      Origen.log.debug "  bd2_reg_addr  = 0x#{bd2_reg_addr.to_hex}"
      Origen.log.debug "  bd3_reg_addr  = 0x#{bd3_reg_addr.to_hex}"
      Origen.log.debug "  cfg_reg_addr  = 0x#{cfg_reg_addr.to_hex}"
      Origen.log.debug "  base_reg_addr = 0x#{base_reg_addr.to_hex}"
      Origen.log.debug "  idr_reg_addr  = 0x#{idr_reg_addr.to_hex}"
    end

    # -----------------------------------------------------------------------------
    # User API
    # -----------------------------------------------------------------------------

    # Method to read from a mem_ap register
    #
    # @param [Integer] addr Address of register to be read from
    # @param [Hash] options Options to customize the operation
    #
    # @example
    #   # don't care what data actually is
    #   mem_ap.read(0x2000000, size: 32)
    #
    #   # expect read data to be = 0x5a5a5a5a
    #   mem_ap.read(0x2000000, size: 32, edata: 0x5a5a5a5a)
    #
    #   # expect read data to be = 0xXXXXXX5a (mask out all bits except [7:0])
    #   mem_ap.read(0x2000000, size: 32, edata: 0x5a5a5a5a, r_mask: 0x000000ff)
    #
    # Returns nothing.
    def read(addr, options = {})
      options = { size: 32 }.merge(options)
      options = { r_mask: 'mask', r_attempts: 1 }.merge(options)
      msg = 'Arm Debug: Shift out data for reading'
      options = { arm_debug_comment: msg }.merge(options)
      size = options[:size]

      set_size(size)
      set_addr(addr)
      debug_port.read_ap(drw_reg_addr, options)
      rdata = get_rdata(size, addr, rdata)
      increment_addr

      cc "MEM-AP(#{@name}): R-#{size.to_s(10)}: "\
        "addr=0x#{addr.to_s(16).rjust(size / 4, '0')}"
    end

    # Method to write to a mem_ap register
    #
    # @param [Integer] addr Address of register to be read from
    # @param [Integer] wdata Data to be written
    # @param [Hash] options Options to customize the operation
    #
    # @example
    #   mem_ap.write(0x2000000, 0xc3c3a5a5, size: 32)
    #
    # Returns nothing.
    def write(addr, wdata, options = {});
      options = { size: 32 }.merge(options)
      options = { w_attempts: 1 }.merge(options)
      msg = "Arm Debug: Shift in data to write: #{wdata.to_hex}"
      options = { arm_debug_comment: msg }.merge(options)
      size = options[:size]

      set_size(size)
      set_addr(addr)
      wdata = get_wdata(size, addr, wdata)
      debug_port.write_ap(drw_reg_addr, wdata, options)
      increment_addr

      cc "MEM-AP(#{@name}): WR-#{size.to_s(10)}: "\
        "addr=0x#{addr.to_s(16).rjust(size / 4, '0')}, "\
        "data=0x#{wdata.to_s(16).rjust(size / 4, '0')}"
    end

    # Method to write and then read from a mem_ap register (legacy)
    #
    # @param [Integer] addr Address of register to be read from
    # @param [Integer] wdata Data to be written
    # @param [Hash] options Options to customize the operation
    #
    # @example
    #   # don't care what read-back data actually is
    #   mem_ap.write_read(0x2000000, 0xc3c3a5a5, size: 32)
    #
    #   # expect read-back data to be same as write data = 0xc3c3a5a5
    #   mem_ap.read(0x2000000, 0xc3c3a5a5, size: 32, edata: 0xc3c3a5a5)
    #
    #   # expect read-back data to be = 0xXXXXXXa5 (mask out all bits except [7:0])
    #   mem_ap.read(0x2000000, 0xc3c3a5a5, size: 32, edata: 0xc3c3a5a5, r_mask: 0x000000ff)
    #
    # Returns nothing.
    def write_read(addr, wdata, options = {})
      options = { size: 32 }.merge(options)
      options = { edata: 0x00000000, r_mask: 0xffffffff, actual: 0x00000000 }.merge(options)
      options = { w_attempts: 1, r_attempts: 2 }.merge(options)
      size = options[:size]

      write(addr, wdata, options)
      options[:edata] = wdata & options[:r_mask] if options[:edata] == 0x00000000
      read(addr, options)
      actual = wdata & options[:r_mask]

      cc "MEM-AP(#{@name}): WR-#{size.to_s(10)}: "\
        "addr=0x#{addr.to_s(16).rjust(size / 4, '0')}, "\
        "wdata=0x#{wdata.to_s(16).rjust(size / 4, '0')}, "\
        "read=0x#{actual.to_s(16).rjust(size / 4, '0')}, "\
        "expect=0x#{options[:edata].to_s(16).rjust(size / 4, '0')}, "\
        "mask=0x#{options[:r_mask].to_s(16).rjust(size / 4, '0')}"
    end

    # -----------------------------------------------------------------------------
    # Legacy Support (to be phased out)
    # -----------------------------------------------------------------------------

    # Method to read from a mem_ap register (legacy)
    #
    # @param [Integer] addr Address of register to be read from
    # @param [Integer] rdata This really does nothing since only care about value
    #   of options[:edata]
    # @param [Hash] options Options to customize the operation
    # Returns nothing.
    def r(addr, rdata, options = {})
      # Warn caller that this method is being deprecated
      msg = 'Use mem_ap.read(addr, options) instead of R(addr, rdata, options)'
      Origen.deprecate msg

      # Patch arguments and send to new method
      options = { rdata: rdata }.merge(options)
      read(addr, options)
    end
    alias_method :R, :r

    # Method to write to a mem_ap register (legacy)
    #
    # @param [Integer] addr Address of register to be written to
    # @param [Integer] wdata Data to be written
    # @param [Hash] options Options to customize the operation
    # Returns nothing.
    def w(addr, wdata, options = {})
      # Warn caller that this method is being deprecated
      msg = 'Use mem_ap.write(addr, wdata, options) instead of W(addr, wdata, options)'
      Origen.deprecate msg

      # Patch arguments and send to new method
      write(addr, wdata, options)
    end
    alias_method :W, :w

    # Method to write and then read from a mem_ap register (legacy)
    #
    # @param [Integer] addr Address of register to be read from
    # @param [Integer] wdata Data to be written
    # @param [Hash] options Options to customize the operation
    # Returns nothing.
    def wr(addr, wdata, options = {})
      # Warn caller that this method is being deprecated
      msg = 'Use mem_ap.write_read(addr, wdata, options) instead of WR(addr, wdata, options)'
      Origen.deprecate msg

      # Patch arguments and send to new method
      write_read(addr, wdata, options)
    end
    alias_method :WR, :wr

    # -----------------------------------------------------------------------------
    # Support Code
    # -----------------------------------------------------------------------------

    private

    # Sets the size of the data (by writing to the CSW size bits).  It will only
    #   write to the size if the size from the previous transaction has changed
    #
    # @param [Integer] size Size of data, supports 8-bit, 16-bit, and 32-bit
    def set_size(size)
      case size
        when 8 then  new_size = 0x00000000
        when 16 then new_size = 0x00000001
        when 32 then new_size = 0x00000002
        else new_size = 0x00000002
      end

      if (@current_csw == 0x00000000)
        debug_port.read_ap(csw_reg_addr)
        @current_csw = 0x23000040
      end

      csw_size = @current_csw & 0x00000003
      if (csw_size != new_size)
        new_csw = (@current_csw & 0xfffffffc) | new_size
        debug_port.write_ap(csw_reg_addr, new_csw)
        @current_csw = new_csw
      end
    end

    # Sets the addr of the transaction.
    #
    # @param [Integer] addr Address of data to be read from or written to
    def set_addr(addr)
      arm_debug_comment = "Arm Debug: Shift in read/write address: #{addr.to_hex}"
      options = { arm_debug_comment: arm_debug_comment }

      if (@current_tar != addr)
        debug_port.write_ap(tar_reg_addr, addr, options)
      end
      @current_tar = addr;
    end

    # Increment the address for the next transaction.
    def increment_addr
      current_csw_5_4 = (@current_csw & 0x00000030) >> 4
      current_csw_2_0 = @current_csw & 0x00000007
      if (current_csw_5_4 == 0b01)
        case current_csw_2_0
          when 0b000 then @current_tar += 1   # Increment single
          when 0b001 then @current_tar += 2   # Increment single
          when 0b010 then @current_tar += 4   # Increment single
        end
      elsif (current_csw_5_4 == 0b10)
        @current_tar += 4                     # Increment packed
      end

      if current_csw_5_4 && ((@current_tar & 0xfffffc00) == 0xffffffff)
        # reset tar when attempting to increment past 1kB boundary
        @current_tar = 0xffffffff
      end
    end

    # Create a bit-wise mask based on size, address and mask parameters.
    #
    # @param [Integer] size Size of data, supports 8-bit, 16-bit, and 32-bit
    # @param [Integer] addr Address of data to be read from or written to
    # @param [Integer] mask Mask for full data, used to create nibble mask
    def get_mask(size, addr, mask)
      addr_1_0 &= 0x00000003
      case size
        when 8
          case addr_1_0
            when 0b00 then mask &= 0x000000ff
            when 0b01 then mask &= 0x0000ff00
            when 0b10 then mask &= 0x00ff0000
            when 0b11 then mask &= 0xff000000
          end
        when 16
          case addr_1_0
            when 0b00 then mask &= 0x0000ffff
            when 0b10 then mask &= 0xffff0000
          end
        when 32
          mask &= 0xffffffff
      end
      mask
    end

    # Create a bit-wise read-data based on size, address and rdata parameters.
    #
    # @param [Integer] size Size of data, supports 8-bit, 16-bit, and 32-bit
    # @param [Integer] addr Address of data to be read from or written to
    # @param [Integer] rdata Full data for read, used to create nibble read data
    def get_rdata(size, addr, rdata)
      addr_1_0 &= 0x00000003
      case size
        when 8
          case addr_1_0
            when 0b00 then rdata = 0x000000ff & rdata
            when 0b01 then rdata = 0x000000ff & (rdata >> 8)
            when 0b10 then rdata = 0x000000ff & (rdata >> 16)
            when 0b11 then rdata = 0x000000ff & (rdata >> 24)
          end
        when 16
          case addr_1_0
                  when 0b00 then rdata = 0x0000ffff & rdata
                  when 0b10 then rdata = 0x0000ffff & (rdata >> 16)
                end
        when 32
          rdata = rdata
      end
      rdata
    end

    # Create a bit-wise read-data based on size, address and wdata parameters.
    #
    # @param [Integer] size Size of data, supports 8-bit, 16-bit, and 32-bit
    # @param [Integer] addr Address of data to be read from or written to
    # @param [Integer] wdata Full data for write, used to create nibble write data
    def get_wdata(size, addr, wdata);
      addr_1_0 &= 0x00000003
      case size
        when 8
          case addr_1_0
                  when 0b00 then wdata = 0x000000ff & wdata
                  when 0b01 then wdata = 0x0000ff00 & (wdata << 8)
                  when 0b10 then wdata = 0x00ff0000 & (wdata << 16)
                  when 0b11 then wdata = 0xff000000 & (wdata << 24)
                end
        when 16
          case addr_1_0
                  when 0b00 then wdata = 0x0000ffff & wdata
                  when 0b10 then wdata = 0xffff0000 & (wdata << 16)
          end
        when 32
          wdata = wdata
      end
      wdata
    end

    # Returns address of CSW register for this mem-ap instance
    def csw_reg_addr
      MEM_ADDR_CSW + @base_address
    end

    # Returns address of TAR register for this mem-ap instance
    def tar_reg_addr
      MEM_ADDR_TAR + @base_address
    end

    # Returns address of DRW register for this mem-ap instance
    def drw_reg_addr
      MEM_ADDR_DRW + @base_address
    end

    # Returns address of BD0 register for this mem-ap instance
    def bd0_reg_addr
      MEM_ADDR_BD0 + @base_address
    end

    # Returns address of BD1 register for this mem-ap instance
    def bd1_reg_addr
      MEM_ADDR_BD1 + @base_address
    end

    # Returns address of BD2 register for this mem-ap instance
    def bd2_reg_addr
      MEM_ADDR_BD2 + @base_address
    end

    # Returns address of BD3 register for this mem-ap instance
    def bd3_reg_addr
      MEM_ADDR_BD3 + @base_address
    end

    # Returns address of CFG register for this mem-ap instance
    def cfg_reg_addr
      MEM_ADDR_CFG + @base_address
    end

    # Returns address of BASE register for this mem-ap instance
    def base_reg_addr
      MEM_ADDR_BASE + @base_address
    end

    # Returns address of IDR register for this mem-ap instance
    def idr_reg_addr
      MEM_ADDR_IDR + @base_address
    end
  end
end
