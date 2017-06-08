module OrigenARMDebug
  class SW_DP
    include Origen::Model

    def initialize(options = {})
      reg :idcode, 0, access: :ro do |reg|
        reg.bit 31..28, :version
        reg.bit 27..12, :partno
        reg.bit 11..1, :designer
        reg.bit 0, :bit0, reset: 1
      end

      reg :abort, 0, access: :wo do |reg|
        reg.bit 4, :orunerrclr
        reg.bit 3, :wderrclr
        reg.bit 2, :stkerrclr
        reg.bit 1, :stkcmpclr
        reg.bit 0, :dapabort
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
        reg.bit 7, :wdataerr
        reg.bit 6, :readok
        reg.bit 5, :stickyerr
        reg.bit 4, :stickycmp
        reg.bit 3..2, :trnmode
        reg.bit 1, :stickyorun
        reg.bit 0, :orundetect
      end

      reg :wcr, 0x4 do |reg|
        reg.bit 9..8, :turnround
        reg.bit 7..6, :wiremode
        reg.bit 2..0, :prescaler
      end

      add_reg :resend, 0x8, access: :ro

      reg :select, 0x8, access: :wo do |reg|
        reg.bit 31..24, :apsel
        reg.bit 7..4, :apbanksel
        reg.bit 0, :ctrlsel
      end

      add_reg :rdbuff, 0xC, access: :ro
    end

    def select
      reg(:select)
    end

    def abort
      reg(:abort)
    end
  end
end
