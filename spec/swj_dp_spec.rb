require 'spec_helper'

# Some dummy classes to test out the protocol selection
class JtagDut1
  include OrigenARMDebug
  include Origen::Callbacks
  include Origen::Registers
  include Origen::Pins
  include OrigenJTAG

  def initialize 
    add_pin :tclk
    add_pin :tdi
    add_pin :tdo
    add_pin :tms
    add_pin :trst

    add_reg :test, 0x0, 32, data: { pos: 0, bits: 32 }
  end
end

class SwdDut1
  include OrigenARMDebug
  include Origen::Callbacks
  include Origen::Registers
  include Origen::Pins
  include OrigenSWD

  def initialize
    add_pin :swd_clk
    add_pin :swd_dio

    add_reg :test, 0x0, 32, data: { pos: 0, bits: 32 }
  end
end


describe "Origen ARM Debug SWJ-DP Support" do

  before :all do
    Origen.load_target("specs")
    $dut_jtag = JtagDut1.new
    $dut_swd = SwdDut1.new
  end

  it "swj_dp_read_dp_swd method works" do
    $dut_swd.arm_debug.swj_dp.read_dp('IDCODE')
    $dut_swd.arm_debug.swj_dp.read_dp('ABORT')
    $dut_swd.arm_debug.swj_dp.read_dp('CTRL/STAT')
    $dut_swd.arm_debug.swj_dp.read_dp('SELECT')
    $dut_swd.arm_debug.swj_dp.read_dp('RDBUFF')
    $dut_swd.arm_debug.swj_dp.read_dp('WCR')
    $dut_swd.arm_debug.swj_dp.read_dp('RESEND')
    $dut_swd.arm_debug.swj_dp.read_dp('INVALID')
  end

  it "swj_dp_write_dp_swd method works" do
    $dut_swd.arm_debug.swj_dp.write_dp('IDCODE', 0x55555555)
    $dut_swd.arm_debug.swj_dp.write_dp('ABORT', 0x55555555)
    $dut_swd.arm_debug.swj_dp.write_dp('CTRL/STAT', 0x55555555)
    $dut_swd.arm_debug.swj_dp.write_dp('SELECT', 0x55555555)
    $dut_swd.arm_debug.swj_dp.write_dp('RDBUFF', 0x55555555)
    $dut_swd.arm_debug.swj_dp.write_dp('WCR', 0x55555555)
    $dut_swd.arm_debug.swj_dp.write_dp('RESEND', 0x55555555)
    $dut_swd.arm_debug.swj_dp.write_dp('INVALID', 0x55555555)
  end

  it "swj_dp_read_dp_jtag method works" do
    $dut_jtag.arm_debug.swj_dp.read_dp('IDCODE')
    $dut_jtag.arm_debug.swj_dp.read_dp('ABORT')
    $dut_jtag.arm_debug.swj_dp.read_dp('CTRL/STAT')
    $dut_jtag.arm_debug.swj_dp.read_dp('SELECT')
    $dut_jtag.arm_debug.swj_dp.read_dp('RDBUFF')
    $dut_jtag.arm_debug.swj_dp.read_dp('WCR')
    $dut_jtag.arm_debug.swj_dp.read_dp('RESEND')
    $dut_jtag.arm_debug.swj_dp.read_dp('INVALID')
  end

  it "swj_dp_write_dp_jtag method works" do
    $dut_jtag.arm_debug.swj_dp.write_dp('IDCODE', 0x55555555)
    $dut_jtag.arm_debug.swj_dp.write_dp('ABORT', 0x55555555)
    $dut_jtag.arm_debug.swj_dp.write_dp('CTRL/STAT', 0x55555555)
    $dut_jtag.arm_debug.swj_dp.write_dp('SELECT', 0x55555555)
    $dut_jtag.arm_debug.swj_dp.write_dp('RDBUFF', 0x55555555)
    $dut_jtag.arm_debug.swj_dp.write_dp('WCR', 0x55555555)
    $dut_jtag.arm_debug.swj_dp.write_dp('RESEND', 0x55555555)
    $dut_jtag.arm_debug.swj_dp.write_dp('INVALID', 0x55555555)
  end

  it "swj_dp_random_mode works" do
    $dut_jtag.arm_debug.swj_dp.random_mode = :unrolled
    $dut_jtag.arm_debug.swj_dp.read_ap(0x20000000, compare_data: 0x55555555)
    $dut_jtag.arm_debug.swj_dp.read_ap(0x20000000, r_mask: 'store')

    $dut_swd.arm_debug.swj_dp.random_mode = :random
    $dut_swd.arm_debug.swj_dp.read_ap(0x20000000, compare_data: 0x55555555)

    $dut_swd.arm_debug.swj_dp.random_mode = :invalid
    $dut_swd.arm_debug.swj_dp.read_ap(0x20000000, r_mask: 'store')
    $dut_swd.arm_debug.swj_dp.read_ap(0x20000000, compare_data: 0x55555555)    
  end
  
end
