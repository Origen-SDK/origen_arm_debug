require 'origen_arm_debug/mem_ap_controller'
module OrigenARMDebug
  # Memory Access Port (MEM-AP)
  class MemAP < AP
    include Origen::Model

    # Latency to write a memory resource
    attr_reader :latency

    # Wait states for data to be transferred from Memory Resource to DRW on
    #   read request.  Should be added to apreg_access_wait for complete transaction
    #   time of memory read (read data path: memory->drw->rdbuff)
    attr_reader :apmem_access_wait

    def initialize(options = {})
      super
      @latency = options[:latency] || 0
      @apmem_access_wait = options[:apmem_access_wait] || 0

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
