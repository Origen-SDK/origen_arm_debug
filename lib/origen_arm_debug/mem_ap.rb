module OrigenARMDebug
  # Object that defines the API necessary to perform MEM-AP transactions.  Requires
  #  a top-level protocol be defined as well as a top-level instantiation of an
  #  SWJ-DP object.
  class MemAP
    include Origen::Model

    # Initialize class variables
    #
    # @param [Hash] options Options to customize the operation
    #
    # @example
    #   DUT.new.arm_debug.mem_ap
    #
    def initialize(options = {})
      instantiate_registers
    end

    def instantiate_registers(options = {})
      # ARM Debug Interface v5.1
      reg :csw, 0x00, size: 32, reset: 0x00000000 do |reg|
        reg.bit 31,     :dbg_sw_enable
        reg.bit 30..24, :prot
        reg.bit 23,     :spiden
        reg.bit 11..8,  :mode
        reg.bit 7,      :tr_in_prog
        reg.bit 6,      :device_en
        reg.bit 5..4,   :addr_inc, reset: 0b00
        reg.bit 2..0,   :size, reset: 0b000
      end

      add_reg :tar, 0x04, 32, data: { pos: 0, bits: 32 }, reset: 0xffffffff
      add_reg :drw, 0x0C, 32, data: { pos: 0, bits: 32 }, reset: 0x00000000
      add_reg :idr, 0xFC, 32, data: { pos: 0, bits: 32 }, reset: 0x00000000
    end

    # Shortcut name to SWJ-DP Debug Port
    def debug_port
      parent.swj_dp
    end
    alias_method :dp, :debug_port

    # -----------------------------------------------------------------------------
    # User API
    # -----------------------------------------------------------------------------
    def write_register(reg_or_val, options = {})
      if reg_or_val.try(:owner) == self
        if protocol != :swd
          fail 'The register-based ARM Debug API is currently only implemented for SWD'
        end
        bank = reg_or_val.address & 0xF0
        debug_port.select_bank(bank)
        swd.write_ap(reg_or_val)
      else
        if reg_or_val.respond_to?(:data)
          addr = reg_or_val.addr
          data = reg_or_val.data
        else
          addr = options[:address]
          data = reg_or_val
        end
        size = options[:size] || 32

        set_size(size)
        set_addr(addr, force: true)
        drw.write!(get_wdata(size, addr, data))
        increment_addr

        cc "[ARM DEBUG] WRITE #{size.to_s(10)}: "\
          "addr=0x#{addr.to_s(16).rjust(size / 4, '0')}, "\
          "data=0x#{reg(:drw).data.to_s(16).rjust(size / 4, '0')}"

        apply_latency
      end
    end

    def read_register(reg_or_val, options = {})
      if reg_or_val.try(:owner) == self
        if protocol != :swd
          fail 'The register-based ARM Debug API is currently only implemented for SWD'
        end
        bank = reg_or_val.address & 0xF0
        debug_port.select_bank(bank)
        swd.read_ap(address: reg_or_val.address)
        swd.read_dp(reg_or_val, address: debug_port.rdbuff.address)
      else
        if reg_or_val.respond_to?(:data)
          addr = reg_or_val.addr
          data = reg_or_val.data
          options[:mask] = reg_or_val.enable_mask(:read)
          options[:store] = reg_or_val.enable_mask(:store)
        else
          addr = options[:address]
          data = reg_or_val
        end
        size = options[:size] || 32

        set_size(size)
        set_addr(addr, force: true)
        apply_latency
        swd.read_ap(address: drw.address)
        apply_latency
        swd.read_ap(reg_or_val, address: drw.address)
        increment_addr

        cc "[ARM DEBUG] READ #{size.to_s(10)}: "\
          "addr=0x#{addr.to_s(16).rjust(size / 4, '0')}"
      end
    end

    # -----------------------------------------------------------------------------
    # Support Code
    # -----------------------------------------------------------------------------

    private

    def protocol
      debug_port.send(:protocol)
    end

    def swd
      debug_port.send(:swd)
    end

    # Sets the size of the data (by writing to the CSW size bits).  It will only
    #   write to the size if the size from the previous transaction has changed
    #
    # @param [Integer] size Size of data, supports 8-bit, 16-bit, and 32-bit
    def set_size(size)
      case size
        when 8 then  new_size = 0b00
        when 16 then new_size = 0b01
        when 32 then new_size = 0b10
      end

      if (reg(:csw).data == 0x00000000)
        debug_port.read_ap(reg(:csw).address, reg(:csw).data, mask: 0x00000000)
        reg(:csw).data = 0x23000040
      end

      if (reg(:csw).bits(:size).data != new_size)
        reg(:csw).bits(:size).data = new_size
        debug_port.write_ap(reg(:csw).address, reg(:csw).data)
      end
    end

    # Sets the addr of the transaction.
    #
    # @param [Integer] addr Address of data to be read from or written to
    def set_addr(addr, options = {})
      tar.write!(addr) if options[:force] || tar.data != addr
    end

    # Increment the address for the next transaction.
    def increment_addr
      if reg(:csw).bits(:addr_inc).data == 1
        case reg(:csw).bits(:size)
          when 0 then reg(:tar).data += 1   # Increment single
          when 1 then reg(:tar).data += 2   # Increment single
          when 2 then reg(:tar).data += 4   # Increment single
        end
      elsif reg(:csw).bits(:addr_inc).data == 2
        reg(:tar).data += 4                 # Increment packed
      end

      if reg(:csw).bits(:addr_inc) && ((reg(:tar).data & 0xfffffc00) == 0xffffffff)
        # reset tar when attempting to increment past 1kB boundary
        reg(:tar).data = 0xffffffff
      end
    end

    # Create a bit-wise read-data based on size, address and rdata parameters.
    #
    # @param [Integer] size Size of data, supports 8-bit, 16-bit, and 32-bit
    # @param [Integer] addr Address of data to be read from or written to
    # @param [Integer] rdata Full data for read, used to create nibble read data
    def get_rdata(size, addr, rdata)
      addr_1_0 = addr & 0x00000003
      case size
        when 8
          case addr_1_0
            when 0 then rdata = 0x000000ff & rdata
            when 1 then rdata = 0x000000ff & (rdata >> 8)
            when 2 then rdata = 0x000000ff & (rdata >> 16)
            when 3 then rdata = 0x000000ff & (rdata >> 24)
          end
        when 16
          case addr_1_0
            when 0 then rdata = 0x0000ffff & rdata
            when 2 then rdata = 0x0000ffff & (rdata >> 16)
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
      addr_1_0 = addr & 0x00000003
      case size
        when 8
          case addr_1_0
            when 0 then wdata = 0x000000ff & wdata
            when 1 then wdata = 0x0000ff00 & (wdata << 8)
            when 2 then wdata = 0x00ff0000 & (wdata << 16)
            when 3 then wdata = 0xff000000 & (wdata << 24)
          end
        when 16
          case addr_1_0
            when 0 then wdata = 0x0000ffff & wdata
            when 2 then wdata = 0xffff0000 & (wdata << 16)
          end
        when 32
          wdata = wdata
      end
      wdata
    end

    # Apply delay as specified by the top-level attribute 'latency' (defaults to 0).
    #
    # @param [Hash] options Options to customize the operation
    def apply_latency(options = {})
      Origen.tester.cycle(repeat: parent.latency)
    end
  end
end
