Pattern.create do

  ss "Test write register, should write value 0xFF01"
  $dut.reg(:test).write!(0xFF01)
  ss "Test read register, should read value 0xFF01"
  $dut.reg(:test).read!
  ss "Test bit level read, should read value 0xXXXxxx1"
  $dut.reg(:test).bit(:bit).read!


  $dut.read_register($dut.reg(:test))
  $dut.write_register($dut.reg(:test), 0xFF02)


  $dut_swd.arm_debug.swj_dp.read_dp("IDCODE");
  $dut_swd.arm_debug.swj_dp.write_read_dp("CTRL/STAT", 0x50000000, edata: 0xf0000000);
  $dut_swd.arm_debug.swj_dp.read_ap(0x010000FC);
  $dut_swd.arm_debug.swj_dp.write_read_ap(0x01000004, 0x10101010);

end
