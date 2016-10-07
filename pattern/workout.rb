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
end
