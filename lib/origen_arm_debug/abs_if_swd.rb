# To use this driver the $soc model must define the following pins (an alias is fine):
#   :swd_clk
#   :swd_dio
#
# API methods:
#   R_dp -  debug register read - just a dummy function in origen
#   RE_dp - debug register read/expect - expect compares not implemented
#   R_ap - read a specific address - just a dummy function in origen
#   W_dp - debug register write
#   W_ap - write a specific address
#   WR_ap - write a specific address, then read back

module OrigenARMDebug
  class ABSIF_SWD
    attr_reader :owner
    include Origen::Registers

    def initialize(owner, options = {})
      @current_apaddr = 0
      @orundetect = 0
      @owner = owner
    end

    # Highest level implementation of API - abstracted from 'read' and 'write' for future merging with JTAG debug
    def R_dp(name, rdata, options = {})
      cc 'Reading ' + name
      read_dp(name, options)
    end

    def RE_dp(name, edata, options = {})
      R_dp(name, edata, options)
    end

    def R_ap(addr, rdata, options = {})
      cc 'Reading address ' + addr.to_s(16)
      read_ap(addr, options)
    end

    def WAIT_RE_ap(addr, edata, options = {})
      options = { mask: 0xffffffff, r_attempts: 1 }.merge(options)

      # just assume that it always passes
      actual = edata

      R_ap(addr, actual, options)

      cc "ABS-IF: WAIT_RE-AP: addr = 0x#{addr.to_s(16)}, "\
                             "actual = 0x#{actual.to_s(16)}, "\
                             "expected = 0x#{edata.to_s(16)}, "\
                             "mask = 0x#{options[:mask].to_s(16)}"
    end

    def W_dp(name, wdata, options = {})
      cc 'Writing 0x' + wdata.to_s(16) + ' to ' + name
      write_dp(name, wdata, options)
    end

    def WR_dp(name, wdata, options = {})
      options = { edata: 0x00000000, mask: 0xffffffff,
                  w_attempts: 1, r_attempts: 1
                }.merge(options)

      # just assume that it always passes
      actual = options[:edata] & options[:mask]

      W_dp(name, wdata, options)
      R_dp(name, actual, options)

      cc "ABS-IF: WR-DP: #{name} write = 0x#{wdata.to_s(16)}, "\
                                "read = 0x#{actual.to_s(16)}, "\
                                "expected = 0x#{options[:edata].to_s(16)}, "\
                                "mask = 0x#{options[:mask].to_s(16)}"
    end

    def W_ap(addr, wdata, options = {})
      options = { w_attempts: 1 }.merge(options)
      cc 'Writing 0x' + wdata.to_s(16) + ' to address 0x' + addr.to_s(16)
      write_ap(addr, wdata, options)
    end

    def WR_ap(addr, wdata, options = {})
      options = { edata: 0x00000000, mask: 0xffffffff,
                  w_attempts: 1, r_attempts: 1
                }.merge(options)

      # just assume that it always passes
      actual = wdata & options[:mask]
      W_ap(addr, wdata, options)
      options.delete(:w_delay) if options.key?(:w_delay)
      R_ap(addr, actual, options)

      cc "ABS-IF: WR-AP: addr = 0x#{addr.to_s(16)}, "\
                       "write = 0x#{wdata.to_s(16)}, "\
                        "read = 0x#{actual.to_s(16)}, "\
                    "expected = 0x#{options[:edata].to_s(16)}, "\
                        "mask = 0x#{options[:mask].to_s(16)}"
    end

    # SWD-specific functions
    def read_dp(name, options = {})
      case name
         when 'IDCODE'    then dpacc_access(name, 1, 0x55555555, options)
         when 'ABORT'     then cc 'Write only register!'
         when 'CTRL/STAT' then dpacc_access(name, 1, 0x55555555, options)
         when 'SELECT'    then cc 'Write only register!'
         when 'RDBUFF'    then dpacc_access(name, 1, 0x55555555, options)
         when 'WCR'       then dpacc_access(name, 1, 0x55555555, options)
         when 'RESEND'    then dpacc_access(name, 1, 0x55555555, options)
         else cc 'Unknown SW-DP register name'
      end
    end

    def write_dp(name, wdata, options = {})
      case name
         when 'IDCODE'    then cc 'SW-DP register is read-only'
         when 'ABORT'     then dpacc_access(name, 0, wdata, options)
         when 'CTRL/STAT' then dpacc_access(name, 0, wdata, options)
         when 'SELECT'    then dpacc_access(name, 0, wdata, options)
         when 'RDBUFF'    then cc 'SW-DP register is read-only'
         when 'WCR'       then dpacc_access(name, 0, wdata, options)
         when 'RESEND'    then cc 'SW-DP register is read-only'
         else cc 'Unknown SW-DP register name'
      end
    end

    def write_ap(addr, wdata, options = {})
      apacc_access(addr, 0, wdata, options)
    end

    def read_ap(addr, options = {})
      # Create another copy of options with select keys removed. This first read is junk so we do not want to
      # store it or compare it.
      junk_options = options.clone.delete_if do |key, val|
        (key.eql?(:r_mask) && val.eql?('store')) || key.eql?(:compare_data)
      end
      # pass junk options onto the first apacc access
      apacc_access(addr, 1, 0x55555555, junk_options)
      read_dp('RDBUFF', options) # This is the real data
    end

    # Low-level access functions
    def dpacc_access(name, rwb, wdata, options = {})
      addr = get_dp_addr(name)
      if (name == 'CTRL/STAT')
        cc 'CTRL/STAT'
        set_apselect(@current_apaddr & 0xFFFFFFFE, options)
      end
      if (name == 'WCR')
        cc 'NOT IMPLEMENTED'
      end

      acc_access(addr, rwb, 0, wdata, options)

      if (name == 'WCR')
        cc 'NOT IMPLEMENTED'
      end
      if (name == 'CTRL/STAT')
        @orundetect = wdata & 0x1
      end
    end

    def apacc_access(addr, rwb, wdata, options = {})
      set_apselect((addr & 0xFFFFFFFE) | (@current_apaddr & 1), options)
      options.delete(:w_delay) if options.key?(:w_delay)
      acc_access((addr & 0xC), rwb, 1, wdata, options)
    end

    def get_dp_addr(name)
      case name
         when 'IDCODE'    then return 0x0
         when 'ABORT'     then return 0x0
         when 'CTRL/STAT' then return 0x4
         when 'WCR'       then return 0x4
         when 'RESEND'    then return 0x8
         when 'SELECT'    then return 0x8
         when 'RDBUFF'    then return 0xC
         else cc 'Unknown SW-DP register name'
      end
    end

    def acc_access(address, rwb, ap_dp, wdata, options = {})
      start      = 1
      apndp      = ap_dp
      rnw        = rwb
      addr       = address >> 2
      parity_pr  = ap_dp ^ rwb ^ (addr >> 3) ^ (addr >> 2) & (0x01) ^ (addr >> 1) & (0x01) ^ addr & 0x01
      trn        = 0
      data       = wdata
      require_dp = @orundetect
      line_reset = 0
      stop       = 0
      park       = 1

      cc 'SWD transaction'
      cc 'Packet Request Phase'

      annotate 'Send Start Bit'
      owner.owner.swd.send_data(start, 1)
      cc('Send APnDP Bit (DP or AP Access Register Bit)', prefix: true)
      owner.owner.swd.send_data(apndp,      1)
      c2 'Send RnW Bit (read or write bit)'
      owner.owner.swd.send_data(rnw,        1)
      c2 'Send Address Bits (2 bits)'
      owner.owner.swd.send_data(addr,       2)
      c2 'Send Parity Bit'
      owner.owner.swd.send_data(parity_pr,  1)
      c2 'Send Stop Bit'
      owner.owner.swd.send_data(stop,       1)
      c2 'Send Park Bit'
      owner.owner.swd.send_data(park,       1)

      cc 'Acknowledge Response phase'
      owner.owner.swd.send_data(0xf, trn + 1)
      owner.owner.swd.get_data (3)
      cc 'Read/Write Data Phase'
      if (rwb == 1)
        cc 'Read'
        if options[:r_mask] == 'store'
          owner.owner.pin(:swd_dio).store
        end
        cc 'SWD 32-Bit Read Data Start'
        owner.owner.swd.get_data(32, options)
        cc 'SWD 32-Bit Read Data End'
        cc 'Get Read Parity Bit'
        owner.owner.swd.get_data(1)
        cc 'Send Read ACK bits'
        owner.owner.swd.send_data(0xf, trn + 1)
      else
        cc 'Write'
        cc 'Send ACK Bits'
        owner.owner.swd.send_data(0xf, trn + 1)
        cc 'SWD 32-Bit Write Start'
        owner.owner.swd.send_data(data, 32, options)
        cc 'SWD 32-Bit Write End'
        cc 'Send Write Parity Bit'
        owner.owner.swd.send_data(swd_xor_calc(32, data), 1)
      end

      if options.key?(:w_delay)
        cc "SWD DIO to 0 for #{options[:w_delay]} cycles"
        owner.owner.swd.swd_dio_to_0(options[:w_delay])
      else
        cc 'SWD DIO to 0 for 10 cycles'
        owner.owner.swd.swd_dio_to_0(10)
      end
    end

    def set_apselect(addr, options = {})
      addr &= 0xff0000f1
      cc "SET_APSelect: addr = 0x#{addr.to_s(16)} "

      if (addr != @current_apaddr)
        cc 'SET_APSelect: write_dp SELECT'
        write_dp('SELECT', addr & 0xff0000ff, options)
      end

      @current_apaddr = addr
    end

    # Calculate exclusive OR
    def swd_xor_calc(size, number)
      xor = 0
      size.times do |bit|
        xor ^= (number >> bit) & 0x01
      end
      xor
    end
 end
end
