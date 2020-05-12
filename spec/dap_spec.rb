require 'spec_helper'

require 'origen_arm_debug_dev/dut.rb'
require 'origen_arm_debug_dev/dut_dual_dp.rb'
require 'origen_arm_debug_dev/dut_jtag.rb'
require 'origen_arm_debug_dev/dut_swd.rb'

module DapSpec


  describe "DAP" do

    before :all do
      Origen.environment.temporary = 'j750.rb'
    end

    it 'can have an SWD_DP' do
      load_target('swd.rb')

      dut.arm_debug.dp.name.should == :sw_dp
      dut.arm_debug.dps.size.should == 1
      dut.arm_debug.set_dp(:jtag)
      dut.arm_debug.dp.name.should == :sw_dp
      dut.arm_debug.dps.size.should == 1
    end

    it 'can have a JTAG_DP' do
      load_target('jtag.rb')

      dut.arm_debug.dp.name.should == :jtag_dp
      dut.arm_debug.dps.size.should == 1
      dut.arm_debug.set_dp(:swd)
      dut.arm_debug.dp.name.should == :jtag_dp
      dut.arm_debug.dps.size.should == 1
    end

    it 'can have both an SWD_DP and JTAG_DP' do
      load_target('dual_dp.rb')

      dut.arm_debug.dp.name.should == :sw_dp
      dut.arm_debug.dps.size.should == 2
      dut.arm_debug.set_dp(:jtag)
      dut.arm_debug.dp.name.should == :jtag_dp
      dut.arm_debug.dps.size.should == 2
      dut.arm_debug.set_dp(:swd)
      dut.arm_debug.dp.name.should == :sw_dp
      dut.arm_debug.dps.size.should == 2
      dut.arm_debug.set_dp(:jtag)
      dut.arm_debug.dp.name.should == :jtag_dp
      dut.arm_debug.dps.size.should == 2
      dut.arm_debug.set_dp(:sw)
      dut.arm_debug.dp.name.should == :sw_dp
      dut.arm_debug.dps.size.should == 2
      dut.arm_debug.set_dp(:jtag)
      dut.arm_debug.dp.name.should == :jtag_dp
      dut.arm_debug.dps.size.should == 2
      dut.arm_debug.reset_dp
      dut.arm_debug.dp.name.should == :sw_dp
      dut.arm_debug.dps.size.should == 2
      
      dut.arm_debug.set_dp(:jtag_driver)
      dut.arm_debug.dp.name.should == :sw_dp
      dut.arm_debug.dps.size.should == 2
    end


  end
end
