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
        if reg_or_val.respond_to?(:data)
          addr = reg_or_val.addr
          data = reg_or_val.data
        else
          addr = options[:address]
          data = reg_or_val
        end
        size = options[:size] || 32

        set_size(size)
        set_addr(addr, force: true)
        drw.write!(get_wdata(size, addr, data))
        increment_addr

        cc "[ARM DEBUG] WRITE #{size.to_s(10)}: "\
          "addr=0x#{addr.to_s(16).rjust(size / 4, '0')}, "\
          "data=0x#{reg(:drw).data.to_s(16).rjust(size / 4, '0')}"

        apply_latency
      end
    end

    def read_register(reg_or_val, options = {})
      if reg_or_val.try(:owner) == model
        log "Read MEM-AP (#{model.name}) register #{reg_or_val.name.to_s.upcase}: #{Origen::Utility.read_hex(reg_or_val)}" do
          parent.dp.read_register(reg_or_val)
        end

      else
        if reg_or_val.respond_to?(:data)
          addr = reg_or_val.addr
          data = reg_or_val.data
          options[:mask] = reg_or_val.enable_mask(:read)
          options[:store] = reg_or_val.enable_mask(:store)
        else
          addr = options[:address]
          data = reg_or_val
        end
        size = options[:size] || 32

        set_size(size)
        set_addr(addr, force: true)
        apply_latency
        swd.read_ap(address: drw.address)
        apply_latency
        swd.read_ap(reg_or_val, address: drw.address)
        increment_addr

        cc "[ARM DEBUG] READ #{size.to_s(10)}: "\
          "addr=0x#{addr.to_s(16).rjust(size / 4, '0')}"
      end
    end
  end
end
