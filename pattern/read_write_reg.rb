Pattern.create do

  ss "Test write register, should write value 0xFF01"
  $dut.reg(:test).write!(0x0000FF01)

  ss "Test read register, should read value 0x0000FF01"
  $dut.reg(:test).read!

  ss "Test read register with mask, should read value 0xXXXxxx1"
  $dut.reg(:test).read!(mask: 0x0000_000F)

  ss "Test read register with store"
  $dut.reg(:test).store!

  ss "Test bit level read, should read value 0xXXXxxx1"
  $dut.reg(:test).reset
  $dut.reg(:test).data = 0x0000FF01
  $dut.reg(:test).bit(:bit).read!

  ss "Test read register"
  $dut.read_register($dut.reg(:test))

  ss "Test write register"
  $dut.write_register($dut.reg(:test))

  $dut.arm_debug.mem_ap.read(0x10000004, edata: 0x00000000)
  $dut.arm_debug.mem_ap.read(0x10000004, r_mask: 'store')
  $dut.arm_debug.mem_ap.write(0x10000004, 0x55555555)
  $dut.arm_debug.mem_ap.write_read(0x10000004, 0x55555555)

  $dut.arm_debug.write_register(0x55555555, address: 0x10000004, ap: :mem_ap)
  $dut.arm_debug.read_register(0x55555555, address: 0x10000004, ap: :mem_ap)
end
