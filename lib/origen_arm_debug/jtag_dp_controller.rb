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
              dr.reset
              dr.overlay(nil)
              dr[2..0].write(0)
              dr[34..3].copy_all(reg)
              dut.jtag.write_dr(dr)

            # DPACC
            elsif reg.name == :ctrlstat || reg.name == :select
              dr.reset
              dr.overlay(nil)
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

        unless reg.owner.is_a?(AP)
          fail 'The JTAG-DP can only write to DP or AP registers!'
        end

        select_ap_reg(reg)
        dr.reset
        dr.overlay(nil)
        dr[0].write(0)
        dr[2..1].write(reg.offset >> 2)
        dr[34..3].copy_all(reg)
        ir.write!(0b1011)
        dut.jtag.write_dr(dr, options)
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

              # Part 1 - Request read from DP-Register by writing to DPACC with RnW=1
              dr.reset
              dr.overlay(nil)
              dr[0].write(1)
              dr[2..1].write(reg.offset >> 2)
              dr[34..3].write(0)
              ir.write!(0b1010)
              dut.jtag.write_dr(dr)

              # Part 2 - Now read real data from RDBUFF (DP-Reg)
              dr.reset
              dr.overlay(nil)
              dr[0].write(1)
              dr[2..1].write(rdbuff.offset >> 2)
              dr[34..3].copy_all(reg)
              options[:mask] = options[:mask] << 3 unless options[:mask].nil?
              dut.jtag.read_dr(dr, options)

            else
              fail "Can't read #{reg.name}"
            end
          end
        end

      # AP register read
      else
        unless reg.owner.is_a?(AP)
          fail 'The JTAG-DP can only write to DP or AP registers!'
        end

        # Part 1 - Request read from AP-Register by writing to APACC with RnW=1
        select_ap_reg(reg)
        dr.reset
        dr.overlay(nil)
        dr[0].write(1)
        dr[2..1].write(reg.offset >> 2)
        dr[34..3].write(0)
        ir.write!(0b1011)
        dut.jtag.write_dr(dr)

        # Calling AP should provide any delay parameter for wait states between AP read request
        #   and when the data is available at the RDBUFF DP-Reg
        if options[:apacc_wait_states]
          options[:apacc_wait_states].cycles
        end

        # Part 2 - Now read real data from RDBUFF (DP-Reg)
        dr.reset
        dr.overlay(nil)
        dr[0].write(1)
        dr[2..1].write(rdbuff.offset >> 2)
        dr[34..3].copy_all(reg)
        options[:mask] = options[:mask] << 3 unless options[:mask].nil?
        ir.write!(0b1010)
        dut.jtag.read_dr(dr, options)
      end
    end

    def base_address
      model.base_address
    end
  end
end
