Pattern.create do
  $dut_jtag = $dut
  $dut_jtag.arm_debug.swj_dp.read_dp(:idcode, 0xba5eba11, mask: 0x00000000)
  $dut_jtag.arm_debug.abs_if.read_dp(:idcode, 0xba5eba11)
  $dut_jtag.arm_debug.dpapi.write_dp(:ctrl_stat, 0x50000000)
  $dut_jtag.arm_debug.swj_dp.read_dp(:ctrl_stat, 0xf0000000)
  $dut_jtag.arm_debug.apapi.read_ap(0x010000FC, 0x00000000, mask: 0x00000000)
  $dut_jtag.arm_debug.swj_dp.write_ap(0x01000004, 0x10101010)
  $dut_jtag.arm_debug.swj_dp.read_ap(0x01000004, 0x10101010)

  # Some deprecated methods
  $dut_jtag.arm_debug.swj_dp.read_expect_ap(0x01000004, edata: 0x10101010)
  $dut_jtag.arm_debug.swj_dp.write_read_ap(0x01000004, 0x01010101)
  $dut_jtag.arm_debug.swj_dp.write_read_ap(0x01000004, 0x10101010, edata: 0x10100000)
  
  $dut_jtag.arm_debug.jtag.ir_value
end
