module OrigenARMDebug
  class APController
    include Origen::Controller
    include Helpers

    def write_register(reg_or_val, options = {})
      if reg_or_val.try(:owner) == model
        log "Write AP (#{model.name}) register #{reg_or_val.name.to_s.upcase}: #{reg_or_val.data.to_hex}" do
          parent.dp.write_register(reg_or_val)
          apreg_access_wait.cycles
        end
      else
        fail 'No Resource-specific transport defined for MDM-AP (#model.name})'
      end
    end

    def read_register(reg_or_val, options = {})
      if reg_or_val.try(:owner) == model
        log "Read AP (#{model.name}) register #{reg_or_val.name.to_s.upcase}: #{Origen::Utility.read_hex(reg_or_val)}" do
          parent.dp.read_register(reg_or_val, apacc_wait_states: apreg_access_wait)
        end
      else
        fail 'No Resource-specific transport defined for MDM-AP (#model.name})'
      end
    end
  end
end
