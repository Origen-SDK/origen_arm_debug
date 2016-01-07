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
    add_reg :test8, 0x0, 8, data: { pos: 0, bits: 8 }
    add_reg :test16, 0x0, 16, data: { pos: 0, bits: 16 }
  end
end

describe "Origen ARM Debug MEM-AP Support" do

  before :all do
    Origen.load_target("specs")
    $dut_jtag = JtagDut1.new
    $dut_swd = SwdDut1.new
  end

  it "mem_ap_read_register method works" do
    $dut_jtag.arm_debug.mem_ap.read_register($dut_jtag.reg(:test))

    $dut_jtag.arm_debug.mem_ap.read_register(0x20000000)

    $dut_jtag.arm_debug.mem_ap.r(0x2000000, 0x5555AAAA)

    $dut_jtag.arm_debug.mem_ap.read_register(0x20000000, size: 8)
    $dut_jtag.arm_debug.mem_ap.read_register(0x20000001, size: 8)
    $dut_jtag.arm_debug.mem_ap.read_register(0x20000002, size: 8)
    $dut_jtag.arm_debug.mem_ap.read_register(0x20000003, size: 8)
    $dut_jtag.arm_debug.mem_ap.read_register(0x20000000, size: 16)
    $dut_jtag.arm_debug.mem_ap.read_register(0x20000002, size: 16)
  end

  it "mem_ap_read_register method works" do
    $dut_jtag.reg(:test).data = 0x5555AAAA
    $dut_jtag.arm_debug.mem_ap.write_register($dut_jtag.reg(:test))

    $dut_jtag.arm_debug.mem_ap.write_register(0x20000000, wdata: 0x5555AAAA)

    $dut_jtag.arm_debug.mem_ap.w(0x2000000, 0x5555AAAA)
    $dut_jtag.arm_debug.mem_ap.wr(0x2000000, 0x5555AAAA)

    $dut_jtag.arm_debug.mem_ap.write_register(0x20000000, wdata: 0x55, size: 8)
    $dut_jtag.arm_debug.mem_ap.write_register(0x20000001, wdata: 0x55, size: 8)
    $dut_jtag.arm_debug.mem_ap.write_register(0x20000002, wdata: 0xAA, size: 8)
    $dut_jtag.arm_debug.mem_ap.write_register(0x20000003, wdata: 0xAA, size: 8)
    $dut_jtag.arm_debug.mem_ap.write_register(0x20000000, wdata: 0x5555, size: 16)
    $dut_jtag.arm_debug.mem_ap.write_register(0x20000002, wdata: 0xAAAA, size: 16)
  end

  
end
