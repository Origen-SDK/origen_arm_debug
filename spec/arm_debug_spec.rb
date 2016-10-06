require 'spec_helper'

# Some dummy classes to test out the protocol selection
class TopDut
  include Origen::TopLevel
  include OrigenARMDebug
  include OrigenJTAG
  #include OrigenSWD
  
  def initialize 
    add_pin :tclk
    add_pin :tdi
    add_pin :tdo
    add_pin :tms
    add_pin :trst

    add_pin :swd_clk
    add_pin :swd_dio

    add_reg :jtag_test, 0x0, 32, data: { pos: 0, bits: 32 }
    add_reg :jtag_test8, 0x0, 8, data: { pos: 0, bits: 8 }
    add_reg :jtag_test16, 0x0, 16, data: { pos: 0, bits: 16 }

    #add_reg :swd_test, 0x0, 32, data: { pos: 0, bits: 32 }

    sub_block :arm_debug, class_name: 'OrigenARMDebug::Driver'
  end
end

describe "Origen ARM Debug MEM-AP Support" do

  before :all do
    Origen.target.temporary = -> do
      TopDut.new
      Origen.mode = :debug
    end
    Origen.load_target
  end

  it "arm_debug protocol aware methods works" do
    #spi_driver = OrigenARMDebug::Driver.new($dut_spi)
    lambda { $dut.arm_debug.swd }.should raise_error


    #lambda { $dut.arm_debug.swd }.should raise_error


    #$dut.has_reg?(:swd_test).should == true
    #$dut.arm_debug.swd.should == $dut.swd
    #$dut.arm_debug.swd.trn.should == 0

    $dut.has_reg?(:jtag_test).should == true
    $dut.arm_debug.jtag.should == $dut.jtag
  end

  it "mem_ap register write/read methods works" do
    $dut.reg(:jtag_test).data = 0
    $dut.arm_debug.mem_ap.read_register($dut.reg(:jtag_test))
    $dut.arm_debug.mem_ap.read_register($dut.reg(:jtag_test).data, address: 0x20000000)

    $dut.arm_debug.mem_ap.write_register(0xAA, address: 0x20000000, size: 8)
    $dut.arm_debug.mem_ap.write_register(0xAA, address: 0x20000001, size: 8)
    $dut.arm_debug.mem_ap.write_register(0x55, address: 0x20000002, size: 8)
    $dut.arm_debug.mem_ap.write_register(0x55, address: 0x20000003, size: 8)
    $dut.arm_debug.mem_ap.read_register(0xAA, address: 0x20000000, size: 8)
    $dut.arm_debug.mem_ap.read_register(0xAA, address: 0x20000001, size: 8)
    $dut.arm_debug.mem_ap.read_register(0x55, address: 0x20000002, size: 8)
    $dut.arm_debug.mem_ap.read_register(0x55, address: 0x20000003, size: 8)

    $dut.arm_debug.mem_ap.write_register(0xCCCC, address: 0x20000000, size: 16)
    $dut.arm_debug.mem_ap.write_register(0x3333, address: 0x20000002, size: 16)
    $dut.arm_debug.mem_ap.read_register(0xCCCC, address: 0x20000000, size: 16)
    $dut.arm_debug.mem_ap.read_register(0x3333, address: 0x20000002, size: 16)

    $dut.arm_debug.jtag.ir_value.should == 10
  end

  it "swj_dp random_mode works" do
    $dut.arm_debug.swj_dp.random_mode = :unrolled
    $dut.arm_debug.swj_dp.read_ap(0x20000000, 0x55555555)
    $dut.arm_debug.swj_dp.read_ap(0x20000000, 0x55555555, r_mask: 'store')

    $dut.arm_debug.swj_dp.random_mode = :random
    $dut.arm_debug.swj_dp.read_ap(0x20000000, 0x55555555)

    $dut.arm_debug.swj_dp.random_mode = :invalid
    $dut.arm_debug.swj_dp.read_ap(0x20000000, 0x55555555, r_mask: 'store')
    $dut.arm_debug.swj_dp.read_ap(0x20000000, 0x55555555)    
  end

  it "jtag write_dp/read_dp mode works" do
    $dut.arm_debug.swj_dp.write_dp(:idcode, 0xA5A5A5A5)
    $dut.arm_debug.swj_dp.write_dp(:blah, 0xA5A5A5A5)

    $dut.arm_debug.swj_dp.read_dp(:abort, 0xA5A5A5A5)
    $dut.arm_debug.swj_dp.read_dp(:blah, 0xA5A5A5A5)

    $dut.arm_debug.swj_dp.write_read_dp(:ctrl_stat, 0xA5A5A5A5)
  end

  it "swj_dp get_dp_addr, set_ir mode works" do
    $dut.arm_debug.swj_dp.write_dp(:abort, 0xA5A5A5A5)

    $dut.arm_debug.swj_dp.write_dp(:wcr, 0xA5A5A5A5)
    $dut.arm_debug.swj_dp.write_dp(:resend, 0xA5A5A5A5)
    $dut.arm_debug.swj_dp.write_dp(:blah, 0xA5A5A5A5)

    $dut.arm_debug.swj_dp.read_dp(:abort, 0xA5A5A5A5)
    $dut.arm_debug.swj_dp.read_dp(:blah, 0xA5A5A5A5)

    $dut.arm_debug.swj_dp.write_read_dp(:ctrl_stat, 0xA5A5A5A5)
  end
  
end
