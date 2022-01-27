module OrigenARMDebug
  class JTAG_DP
    include Origen::Model

    attr_reader :dpacc_select, :apacc_select

    def initialize(options = {})
      options = {
        ir_size:       4,
        idcode_select: 0b1110,
        abort_select:  0b1000,
        dpacc_select:  0b1010,
        apacc_select:  0b1011
      }.merge(options)
      @dpacc_select = options[:dpacc_select]
      @apacc_select = options[:apacc_select]
      add_reg :ir, 0, size: options[:ir_size]

      # Virtual reg used to represent all of the various 35-bit scan chains
      reg :dr, 0, size: 35 do |reg|
        reg.bit 34..3, :data
        reg.bit 2..1, :a
        reg.bit 0, :rnw
      end

      reg :idcode, options[:idcode_select], access: :ro do |reg|
        reg.bit 31..28, :version
        reg.bit 27..12, :partno
        reg.bit 11..1, :designer
        reg.bit 0, :bit0, reset: 1
      end

      reg :ctrlstat, 0x4 do |reg|
        reg.bit 31, :csyspwrupack
        reg.bit 30, :csyspwrupreq
        reg.bit 29, :cdbgpwrupack
        reg.bit 28, :cdbgpwrupreq
        reg.bit 27, :cdbgrstack
        reg.bit 26, :cdbgrstreq
        reg.bit 23..12, :trncnt
        reg.bit 11..8, :masklane
        reg.bit 5, :stickyerr
        reg.bit 4, :stickycmp
        reg.bit 3..2, :trnmode
        reg.bit 1, :stickyorun
        reg.bit 0, :orundetect
      end

      reg :select, 0x8 do |reg|
        reg.bit 31..24, :apsel
        reg.bit 23..8,  :reserved
        reg.bit 7..4, :apbanksel
      end

      select.write options[:dp_select_reset] if options[:dp_select_reset]

      add_reg :rdbuff, 0xC, access: :ro, reset: 0

      reg :abort, options[:abort_select], access: :wo do |reg|
        reg.bit 0, :dapabort
      end
    end

    def select
      reg(:select)
    end

    def abort
      reg(:abort)
    end

    def is_jtag?
      true
    end

    def is_swd?
      false
    end
    alias_method :is_sw?, :is_swd?
  end
end
