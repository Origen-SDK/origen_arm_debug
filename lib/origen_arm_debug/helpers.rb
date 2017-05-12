module OrigenARMDebug
  # Generic helper methods shared by the various controllers
  module Helpers
    def extract_data(reg_or_val, options = {})
      if reg_or_val.respond_to?('data')
        reg_or_val.data
      else
        reg_or_val
      end
    end

    def extract_address(reg_or_val, options = {})
      addr = options[:address] || options[:addr]
      return addr if addr
      return reg_or_val.address if reg_or_val.respond_to?('address')
      return reg_or_val.addr if reg_or_val.respond_to?('addr')
      fail 'No address given, if supplying a data value instead of a register object, you must supply an :address option'
    end

    def log(msg)
      cc "[ARM Debug] #{msg}"
      if block_given?
        yield
        cc "[ARM Debug] /#{msg}"
      end
    end
  end
end
