module OrigenARMDebug
  class MemAPController
    include Origen::Controller
    include Helpers

    def write_register(reg_or_val, options = {})
      if reg_or_val.try(:owner) == model
        log "Write MEM-AP (#{model.name}) register #{reg_or_val.name.to_s.upcase}: #{reg_or_val.data.to_hex}" do
          parent.dp.write_register(reg_or_val)
        end
      else

        addr = extract_address(reg_or_val, options)
        data = extract_data(reg_or_val, options)

        log "Write MEM-AP (#{model.name}) address #{addr.to_hex}: #{data.to_hex}" do
          tar.write!(addr)
          drw.write!(data)
          parent.latency.cycles
        end
        # increment_addr
      end
    end

    def read_register(reg_or_val, options = {})
      if reg_or_val.try(:owner) == model
        log "Read MEM-AP (#{model.name}) register #{reg_or_val.name.to_s.upcase}: #{Origen::Utility.read_hex(reg_or_val)}" do
          parent.dp.read_register(reg_or_val)
        end

      else

        addr = extract_address(reg_or_val, options)

        log "Read MEM-AP (#{model.name}) address #{addr.to_hex}: #{Origen::Utility.read_hex(reg_or_val)}" do
          tar.write!(addr)
          parent.latency.cycles
          drw.copy_all(reg_or_val)
          parent.dp.read_register(drw)
        end
        # increment_addr
      end
    end
  end
end
