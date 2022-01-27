module OrigenARMDebug
  # Memory Access Port (MEM-AP)
  class MemAP < AP
    # Latency to write a memory resource
    attr_accessor :latency

    # Wait states for data to be transferred from Memory Resource to DRW on
    #   read request.  Should be added to apreg_access_wait for complete transaction
    #   time of memory read (read data path: memory->drw->rdbuff)
    attr_accessor :apmem_access_wait

    # Wait states to occur in between configuring the DAP for a read, and for the the read transaction to begin.
    #   For JTAG, this is the wait states in between setting the AP and for the read transaction to occur.
    #   For SWD, this is the wait states in between setting the AP, initiating and completing a dummy read, and beginning the actual read transaction.
    attr_accessor :apacc_wait_states

    # Boolean value indicating whether this is an AXI-AP
    attr_accessor :is_axi
    
    # Value to be read from DP CSW for interleaved status checks (debug feature)
    attr_accessor :csw_status_check
    
    # Boolean value indicating whether to interleave status checks during transactions (debug feature)
    attr_accessor :interleave_status_check
    
    def initialize(options = {})
      super

      @is_axi = options[:is_axi]
      @csw_status_check = options[:csw_status_check]
      @interleave_status_check = options[:interleave_status_check]
      
      
      @latency = options[:latency] || 0
      @apmem_access_wait = options[:apmem_access_wait] || 0

      if @is_axi
        reg :csw, 0x0 do |reg|
          reg.bit 31,     :reserved
          reg.bit 30..28, :prot, res: 3
          reg.bit 27..24, :cache
          reg.bit 23,     :spiden
          reg.bit 22..15, :reserved2
          reg.bit 14..13, :domain, res: 3
          reg.bit 12,     :ace_enable
          reg.bit 11..8,  :mode
          reg.bit 7,      :tr_in_prog
          reg.bit 6,      :dbg_status, res: 1
          reg.bit 5..4,   :addr_inc
          reg.bit 3,      :reserved3
          reg.bit 2..0,   :size, res: 2
        end
      else
        reg :csw, 0x0 do |reg|
          reg.bit 31,     :dbg_sw_enable
          reg.bit 30..24, :prot
          reg.bit 23,     :spiden
          reg.bit 11..8,  :mode
          reg.bit 7,      :tr_in_prog
          reg.bit 6,      :device_en
          reg.bit 5..4,   :addr_inc
          reg.bit 2..0,   :size
        end
      end
      reg(:csw).write(options[:csw_reset]) if options[:csw_reset]

      # Doesn't really reset to all 1's, but just to make sure the address
      # optimization logic does not kick in on the first transaction
      add_reg :tar, 0x04, reset: 0xFFFFFFFF
      add_reg :drw, 0x0C, reset: :undefined
      add_reg :bd0, 0x10, reset: :undefined
      add_reg :bd1, 0x14, reset: :undefined
      add_reg :bd2, 0x18, reset: :undefined
      add_reg :bd3, 0x1C, reset: :undefined

      reg :cfg, 0xF4, access: :ro do |reg|
        reg.bit 0, :big_endian
      end

      reg :base, 0xF8, access: :ro do |reg|
        reg.bit 31..12, :baseaddr
        reg.bit 1, :format, reset: 1
        reg.bit 0, :entry_present
      end

      add_reg :idr, 0xFC, access: :ro
    end
  end
end
