Pattern.create name: "workout_#{dut.arm_debug.dp.name}" do

  ss "Tests of direct DP API"
  dp = dut.arm_debug.dp

  dp.idcode.partno.read!(0x12)

  dp.ctrlstat.write!(0x50000000)
  dp.ctrlstat.read!(0xF0000000)

  dp.select.apbanksel.write!(0xF)

  dp.abort.dapabort.write!(1)

  ss "Tests of direct AP API"
  ap = dut.arm_debug.mem_ap

  ap.tar.write!(0x1234_0000)

  ap.tar.read!

  ss "Tests of high-level register API"

  ss "Test write register, should write value 0xFF01"
  dut.reg(:test).write!(0x0000FF01)

  ss "Test read register, should read value 0x0000FF01"
  dut.reg(:test).read!

  ss "Test read register with mask, should read value 0xXXXxxx1"
  dut.reg(:test).read!(mask: 0x0000_000F)

  ss "Test read register with store"
  dut.reg(:test).store!

  ss "Test bit level read, should read value 0xXXXxxx1"
  dut.reg(:test).reset
  dut.reg(:test).data = 0x0000FF01
  dut.reg(:test)[0].read!
end
