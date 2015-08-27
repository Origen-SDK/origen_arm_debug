Pattern.create do

  ss "Test write register, should write value 0xFF01"
  $dut.reg(:test).write!(0xFF01)
  ss "Test read register, should read value 0xFF01"
  $dut.reg(:test).read!
  ss "Test bit level read, should read value 0xXXXxxx1"
  $dut.reg(:test).bit(:bit).read!


  $dut.read_register($dut.reg(:test))
  $dut.write_register($dut.reg(:test), 0xFF02)

  $dut.arm_debug.mem_ap.R(0x10000004, 0x00000000)
  $dut.arm_debug.mem_ap.W(0x10000004, 0x55555555)
  $dut.arm_debug.mem_ap.WR(0x10000004, 0x55555555)

end
