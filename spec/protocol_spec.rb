require 'spec_helper'

# Some dummy classes to test out the protocol selection
class SpiDut1  
  include OrigenARMDebug
  include Origen::Callbacks
  include Origen::Registers
  include Origen::Pins

  def initialize 
    add_pin :sclk
    add_pin :mosi
    add_pin :miso
    add_pin :ss

    add_reg :test, 0x0, 32, data: { pos: 0, bits: 32 }
  end
end

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


describe "Origen ARM Debug Protocol Support" do

  before :all do
    Origen.load_target("specs")
    $dut_spi = SpiDut1.new
    $dut_jtag = JtagDut1.new
    $dut_swd = SwdDut1.new
  end

  it "unsupported protocol raises exception" do
    lambda { OrigenARMDebug::SWJ_DP.new(OrigenARMDebug::Driver.new($dut_spi), :spi) }.should raise_error
  end

  it "arm_debug_driver method works" do
    spi_driver = OrigenARMDebug::Driver.new($dut_spi)
    lambda { spi_driver.inspect_driver }.should raise_error

    $dut_jtag.has_pin?(:tclk).should == true
    $dut_jtag.arm_debug.swj_dp.read_dp("IDCODE")
    $dut_jtag.arm_debug.mem_ap
    $dut_jtag.arm_debug.inspect_driver

    $dut_swd.has_pin?(:swd_clk).should == true
    $dut_swd.arm_debug.swj_dp.read_dp("IDCODE")
    $dut_swd.arm_debug.inspect_driver
  end

  it "arm_debug_read_register method works" do
    lambda { $dut_jtag.arm_debug.read_register }.should raise_error
    $dut_jtag.arm_debug.read_register($dut_jtag.reg(:test))
    $dut_jtag.arm_debug.read_register($dut_jtag.reg(:test), ap: $dut_jtag.arm_debug.mem_ap)
  end

  it "arm_debug_write_register method works" do
    lambda { $dut_jtag.arm_debug.write_register }.should raise_error
    $dut_jtag.arm_debug.write_register($dut_jtag.reg(:test))
    $dut_jtag.arm_debug.write_register($dut_jtag.reg(:test), ap: $dut_jtag.arm_debug.mem_ap)
  end
end
