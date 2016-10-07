module OrigenARMDebug
  class JTAG_DPController
    include Origen::Controller
    include Helpers

    def write_register(reg, options = {})
      unless reg.owner == model
        fail 'The JTAG_DP write_register method can only be used for writing its own registers!'
      end
      unless reg.writable?
        fail "The :#{reg.name} register is not writeable!"
      end

      # Don't log this one
      if reg.name == :ir
        dut.jtag.write_ir(reg)
      else

        log "Write DP register #{reg.name.to_s.upcase}: #{reg.data.to_hex}" do
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
    end

    def read_register(reg, options = {})
      unless reg.owner == model
        fail 'The JTAG_DP read_register method can only be used for reading its own registers!'
      end
      unless reg.readable?
        fail "The :#{reg.name} register is not readable!"
      end

      log "Read DP register #{reg.name.to_s.upcase}: #{Origen::Utility.read_hex(reg)}" do
        if reg.name == :ir
          dut.jtag.read_ir(reg)

        elsif reg.name == :idcode
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
  end
end
