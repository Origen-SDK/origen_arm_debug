require 'origen_arm_debug/dp_controller'
module OrigenARMDebug
  class JTAG_DPController
    include Origen::Controller
    include Helpers
    include DPController

    def write_register(reg, options = {})
      unless reg.writable?
        fail "The :#{reg.name} register is not writeable!"
      end

      # DP register write
      if reg.owner == model
        # Don't log this one, not really a DP reg and will be included
        # in the JTAG driver log anyway
        if reg.name == :ir
          dut.jtag.write_ir(reg)
        else

          log "Write JTAG-DP register #{reg.name.to_s.upcase}: #{reg.data.to_hex}" do
            if reg.name == :abort
              ir.write!(reg.offset)
              dr[2..0].write(0)
              dr[34..3].copy_all(reg)
              dut.jtag.write_dr(dr)

            # DPACC
            elsif reg.name == :ctrlstat || reg.name == :select
              dr[0].write(0)
              dr[2..1].write(reg.offset >> 2)
              dr[34..3].copy_all(reg)
              ir.write!(0b1010)
              dut.jtag.write_dr(dr)

            else
              fail "Can't write #{reg.name}"
            end
          end
        end

      # AP register write
      else

        unless reg.owner.is_a?(JTAGAP) || reg.owner.is_a?(MemAP)
          fail 'The JTAG-DP can only write to DP or AP registers!'
        end

        select_ap_reg(reg)
        dr[0].write(0)
        dr[2..1].write(reg.offset >> 2)
        dr[34..3].copy_all(reg)
        ir.write!(0b1011)
        dut.jtag.write_dr(dr)
      end
    end

    def read_register(reg, options = {})
      unless reg.readable?
        fail "The :#{reg.name} register is not readable!"
      end

      if reg.owner == model
        # Don't log this one, not really a DP reg and will be included
        # in the JTAG driver log anyway
        if reg.name == :ir
          dut.jtag.read_ir(reg)
        else

          log "Read JTAG-DP register #{reg.name.to_s.upcase}: #{Origen::Utility.read_hex(reg)}" do
            if reg.name == :idcode
              ir.write!(reg.offset)
              dut.jtag.read_dr(reg)

            # DPACC
            elsif reg.name == :ctrlstat || reg.name == :select || reg.name == :rdbuff
              dr[0].write(1)
              dr[2..1].write(reg.offset >> 2)
              dr[34..3].copy_all(reg)
              ir.write!(0b1010)
              dut.jtag.read_dr(dr)

            else
              fail "Can't read #{reg.name}"
            end
          end
        end

      else
        unless reg.owner.is_a?(JTAGAP) || reg.owner.is_a?(MemAP)
          fail 'The JTAG-DP can only write to DP or AP registers!'
        end

        select_ap_reg(reg)
        dr[0].write(0)
        dr[2..1].write(reg.offset >> 2)
        dr[34..3].copy_all(reg)
        ir.write!(0b1011)
        dut.jtag.read_dr(dr)
      end
    end
  end
end
