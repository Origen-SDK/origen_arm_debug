Pattern.create do

  $dut_swd.arm_debug.swj_dp.read_dp("IDCODE")
  $dut_swd.arm_debug.swj_dp.read_expect_dp("IDCODE", 0xba5eba11)
  $dut_swd.arm_debug.swj_dp.write_read_dp("CTRL/STAT", 0x50000000, edata: 0xf0000000)
  $dut_swd.arm_debug.swj_dp.read_ap(0x010000FC)
  $dut_swd.arm_debug.swj_dp.write_read_ap(0x01000004, 0x10101010)
  $dut_swd.arm_debug.swj_dp.read_expect_ap(0x01000004, 0x10101010)

end
