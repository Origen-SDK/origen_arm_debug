require 'origen_arm_debug/mem_ap_controller'
module OrigenARMDebug
  class MemAP
    include Origen::Model

    def initialize(options = {})
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

      add_reg :tar, 0x04, reset: :undefined
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
