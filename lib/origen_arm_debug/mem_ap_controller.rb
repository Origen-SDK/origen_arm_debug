module OrigenARMDebug
  class MemAPController < APController
    def write_register(reg_or_val, options = {})
      if reg_or_val.try(:owner) == model
        log "Write MEM-AP (#{model.name}) register #{reg_or_val.name.to_s.upcase}: #{reg_or_val.data.to_hex}" do
          parent.dp.write_register(reg_or_val, options)
          apreg_access_wait.cycles
        end
      else

        addr = extract_address(reg_or_val, options)
        data = extract_data(reg_or_val, options)
        ovl = options.delete(:overlay)
        unless ovl.nil?
          Origen.log.warn '[ARM Debug] Overlays only supported through register model'
        end

        log "Write MEM-AP (#{model.name}) address #{addr.to_hex}: #{data.to_hex}" do
          csw.bits(:size).write!(0b010) if csw.bits(:size).data != 0b010
          tar.write!(addr) unless tar.data == addr
          drw.reset
          drw.overlay(nil)
          drw.copy_all(reg_or_val)
          drw.write!(options)
          latency.cycles
        end
        increment_addr
      end
    end

    def read_register(reg_or_val, options = {})
      if reg_or_val.try(:owner) == model
        apacc_wait_states = reg_or_val.name == :drw ? (apmem_access_wait + apreg_access_wait) : apreg_access_wait
        log "Read MEM-AP (#{model.name}) register #{reg_or_val.name.to_s.upcase}: #{Origen::Utility.read_hex(reg_or_val)}" do
          parent.dp.read_register(reg_or_val, options.merge(apacc_wait_states: apacc_wait_states))
        end

      else

        addr = extract_address(reg_or_val, options)

        log "Read MEM-AP (#{model.name}) address #{addr.to_hex}: #{Origen::Utility.read_hex(reg_or_val)}" do
          csw.bits(:size).write!(0b010) if csw.bits(:size).data != 0b010
          unless tar.data == addr
            tar.write!(addr)
          end
          drw.reset
          drw.overlay(nil)
          drw.copy_all(reg_or_val)
          parent.dp.read_register(drw, options.merge(apacc_wait_states: (apmem_access_wait + apreg_access_wait)))
        end
        increment_addr
      end

      reg_or_val.clear_flags
    end

    def address_increment_enabled?
      d = csw.addr_inc.data
      d == 1 || d == 2
    end

    private

    # Update the model if the address is auto-incrementing on chip
    def increment_addr
      if address_increment_enabled?
        case csw.bits(:size).data
          when 0 then tar.data += 1   # Increment single
          when 1 then tar.data += 2   # Increment single
          when 2 then tar.data += 4   # Increment single
        end
      elsif csw.addr_inc.data == 2
        tar.data += 4                 # Increment packed
      end

      # Reset tar if just crossed a 1kB boundary
      if address_increment_enabled? && (tar[9..0].data == 0)
        tar.write(0)
      end
    end
  end
end
