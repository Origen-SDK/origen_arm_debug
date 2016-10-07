Pattern.create do
  dp = dut.arm_debug.jtag_dp

  dp.idcode.partno.read!(0x12)

  dp.ctrlstat.write!(0x50000000)
  dp.ctrlstat.read!(0xF0000000)

  dp.select.apbanksel.write!(0xF)

  dp.abort.dapabort.write!(1)
end
