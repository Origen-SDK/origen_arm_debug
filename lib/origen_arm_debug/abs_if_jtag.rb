module OrigenARMDebug
  class ABSIF_JTAG
    JTAGC_ARM_ABORT  = 0b1000
    JTAGC_ARM_DPACC  = 0b1010
    JTAGC_ARM_APACC  = 0b1011
    JTAGC_ARM_IDCODE = 0b1110
    JTAGC_ARM_BYPASS = 0b1111

    attr_reader :owner
    attr_accessor :write_ap_dly
    attr_accessor :acc_access_dly
    
    def initialize(owner, options = {})
      @owner = owner

      @write_ap_dly = 8
      @acc_access_dly = 7
      
      @current_apaddr = 0x00000000
    end

    #-------------------------------------
    #  Read tasks - high level
    #-------------------------------------
    def R_dp(name, rdata, options = {})
      options = { mask: 0xffffffff, r_attempts: 1 }.merge(options)
      read_dp(name, rdata, options)
    end

    def RE_dp(name, edata, options = {})
      options = { mask: 0xffffffff, r_attempts: 1 }.merge(options)
      actual = edata
      R_dp(name, actual, options)

      cc "ABS-IF: RE-DP: #{name} = 0x#{actual.to_s(16).rjust(8, '0')}, "\
                   "expected = 0x#{edata.to_s(16).rjust(8, '0')}, "\
                   "mask = 0x#{options[:mask].to_s(16).rjust(8, '0')}"
    end

    def R_ap(addr, rdata, options = {})
      options = { mask: 0xffffffff, r_attempts: 1 }.merge(options)
      read_ap(addr, rdata, options)
    end

    def RE_ap(addr, edata, options = {})
      options = { mask: 0xffffffff, r_attempts: 1 }.merge(options)
      actual = edata
      R_ap(addr, actual, options)

      cc "ABS-IF: RE-AP: addr = 0x#{addr.to_s(16).rjust(8, '0')}, "\
                  "actual = 0x#{actual.to_s(16).rjust(8, '0')}, "\
                  "expected = 0x#{edata.to_s(16).rjust(8, '0')}, "\
                  "mask = 0x#{options[:mask].to_s(16).rjust(8, '0')}"
    end

    def WAIT_RE_ap(addr, edata, options = {})
      options = { mask: 0xffffffff, r_attempts: 1 }.merge(options)
      actual = edata
      R_ap(addr, actual, options)

      cc "ABS-IF: WAIT_RE-AP: addr = 0x#{addr.to_s(16).rjust(8, '0')}, "\
                             "actual = 0x#{actual.to_s(16).rjust(8, '0')}, "\
                       "expected = 0x#{edata.to_s(16).rjust(8, '0')}, "\
                       "mask = 0x#{options[:mask].to_s(16).rjust(8, '0')}"
    end

    #-------------------------------------
    #  Write tasks - high level
    #-------------------------------------
    def W_dp(name, wdata, options = {})
      options = { w_attempts: 1 }.merge(options)
      write_dp(name, wdata, options)
    end

    def WR_dp(name, wdata, options = {})
      options = { edata: 0x00000000, mask: 0xffffffff, w_attempts: 1, r_attempts: 1 }.merge(options)
      actual = options[:edata] & options[:mask]

      W_dp(name, wdata, options)
      R_dp(name, actual, options)

      cc "ABS-IF: WR-DP: #{name} write = 0x#{wdata.to_s(16).rjust(8, '0')}, "\
                          "read = 0x#{actual.to_s(16).rjust(8, '0')}, "\
                          "expected = 0x#{options[:edata].to_s(16).rjust(8, '0')}, "\
                          "mask = 0x#{options[:mask].to_s(16).rjust(8, '0')}"
    end

    def W_ap(addr, wdata, options = {})
      options = { w_attempts: 1 }.merge(options)
      write_ap(addr, wdata, options)
    end

    def WR_ap(addr, wdata, options = {})
      options = { edata: 0x00000000, mask: 0xffffffff, w_attempts: 1, r_attempts: 1 }.merge(options)
      actual = wdata & options[:mask]

      W_ap(addr, wdata, options)
      R_ap(addr, actual, options)

      cc "ABS-IF: WR-AP:  addr = 0x#{addr.to_s(16).rjust(8, '0')}, "\
                   "write = 0x#{wdata.to_s(16).rjust(8, '0')}, "\
                   "read = 0x#{actual.to_s(16).rjust(8, '0')}, "\
                   "expected = 0x#{options[:edata].to_s(16).rjust(8, '0')}, "\
                   "mask = 0x#{options[:mask].to_s(16).rjust(8, '0')}"
    end

    private

    #-------------------------------------
    #  Implementation of virtual functions
    #-------------------------------------
    def read_dp(name, rdata, options = {})
      options = { r_attempts: 1 }.merge(options)

      set_ir(name) if name == 'IDCODE'
      case name
        when 'ABORT' then     puts "#{name} JTAG-DP register is write-only"
        when 'CTRL/STAT' then dpacc_access(name, 1, random, rdata, options)
        when 'SELECT' then    dpacc_access(name, 1, random, rdata, options)
        when 'RDBUFF' then    dpacc_access(name, 1, random, rdata, options)
        when 'IDCODE' then    owner.owner.jtag.write_dr(random, size: 32)          # need to make parameterized!!!
        else
          puts "Unknown JTAG-DP register name #{name}"
      end
      if name != 'IDCODE' && name != 'RDBUFF'
        read_dp('RDBUFF', rdata, options)
      end
      cc "ABS-IF: R-DP: #{name}=0x" + rdata.to_s(16).rjust(8, '0')
    end

    def write_dp(name, wdata, options = {})
      options = { w_attempts: 1 }.merge(options)

      if name == 'ABORT' && wdata != 0x00000001
        puts "#{name} register must only ever be written with the value 0x00000001"
      end
      case name
        when 'ABORT' then     dpacc_access(name, 0, wdata, random, options)
        when 'CTRL/STAT' then dpacc_access(name, 0, wdata, random, options)
        when 'SELECT' then    dpacc_access(name, 0, wdata, random, options)
        when 'RDBUFF' then    puts "#{name} JTAG-DP register is read-only"
        when 'IDCODE' then    puts "#{name} JTAG-DP register is read-only"
        else;             puts "Unknown JTAG-DP register name #{name}"
      end
      cc "ABS-IF: W-DP: #{name} = 0x#{wdata.to_s(16).rjust(8, '0')}"
    end

    def read_ap(addr, rdata, options = {});
      options = { r_attempts: 1 }.merge(options)

      apacc_access(addr, 1, random, rdata, options)
      read_dp('RDBUFF', rdata, options)

      cc "ABS-IF: R-AP:  addr=0x#{addr.to_s(16).rjust(8, '0')}, "\
                  "rdata=0x#{rdata.to_s(16).rjust(8, '0')}"
    end

    def write_ap(addr, wdata, options = {});
      options = { w_attempts: 1 }.merge(options)

      rdata = 0x00000000
      apacc_access(addr, 0, wdata, rdata, options);
      $tester.cycle(repeat: @write_ap_dly)

      cc "ABS-IF: W-AP: addr=0x#{addr.to_s(16).rjust(8, '0')}, "\
                 "wdata=0x#{wdata.to_s(16).rjust(8, '0')}"
    end

    #-------------------------------------
    #  lower level helper tasks
    #-------------------------------------
    def set_ir(name)
      new_ir = get_ir_code(name);
      owner.owner.jtag.write_ir(new_ir, size: 4)           # need to make parameterized!!!
    end

    def acc_access(name, addr, rwb, wdata, rdata, attempts, options = {});
      set_ir(name);
      concat_data = (wdata << 3) | (addr << 1) | rwb
      attempts.times do
        if name == 'RDBUFF'
          r = $dut.reg(:dap)
          if options[:r_mask] == 'store'
            r.bits(3..34).store
          elsif options.key?(:compare_data)
            r.bits(3..34).data = options[:compare_data]
          end
          options = options.merge(size: r.size)
          owner.owner.jtag.read_dr(r, options)   # need to make parameterized!!!
        else
          options = options.merge(size: 35)
          owner.owner.jtag.write_dr(concat_data, options)   # need to make parameterized!!!
        end
      end
      $tester.cycle(repeat: @acc_access_dly)
    end

    def dpacc_access(name, rwb, wdata, rdata, options = {});
      attempts = options[:r_attempts].nil? ? (options[:w_attempts].nil? ? 1 : options[:w_attempts]) : options[:r_attempts]
      addr = get_dp_addr(name);
      addr_3_2 = (addr & 0x0C) >> 2
      acc_access(name, addr_3_2, rwb, wdata, rdata, attempts, options);
    end

    def set_apselect(addr);
      _random = random
      addr = addr & 0xff0000f0;
      concat_data = (addr & 0xff000000) | (_random & 0x00ffff00) | (addr & 0x000000f0) | (_random & 0x0000000f)
      if (addr != @current_apaddr)
        write_dp('SELECT', concat_data);
      end
      @current_apaddr = addr;
    end

    def apacc_access(addr, rwb, wdata, rdata, options = {});
      attempts = options[:r_attempts].nil? ? (options[:w_attempts].nil? ? 1 : options[:w_attempts]) : options[:r_attempts]
      set_apselect(addr);
      addr_3_2 = (addr & 0x0000000C) >> 2
      acc_access('APACC', addr_3_2, rwb, wdata, rdata, attempts, options);
    end

    def get_dp_addr(name);
      case name
        when 'IDCODE' then    return 0xF
        when 'CTRL/STAT' then return 0x4
        when 'SELECT' then    return 0x8
        when 'RDBUFF' then    return 0xC
        when 'ABORT' then     return 0x0
        when 'WCR' then       puts "#{name} is a SW-DP only register"
        when 'RESEND' then    puts "#{name} is a SW-DP only register"
        else;             puts "Unknown JTAG-DP register name: #{name}"
      end
      0
    end

    def get_ir_code(name);
      case name
        when 'ABORT' then     return JTAGC_ARM_ABORT
        when 'CTRL/STAT' then return JTAGC_ARM_DPACC
        when 'SELECT' then    return JTAGC_ARM_DPACC
        when 'RDBUFF' then    return JTAGC_ARM_DPACC
        when 'APACC' then     return JTAGC_ARM_APACC
        when 'IDCODE' then    return JTAGC_ARM_IDCODE
        when 'RESEND' then    puts "#{name} is a SW-DP only register"
        else;             puts "Unknown JTAG-DP register name: #{name}"
      end
      0
    end

    def random
      # rand(4294967295)  # random 32-bit integer
      0x01234567
    end
  end
end
