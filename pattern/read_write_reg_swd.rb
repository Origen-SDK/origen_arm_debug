Pattern.create do
  $dut_swd = $dut
  $dut_swd.arm_debug.swj_dp.read_dp(:idcode, 0xba5eba11, mask: 0x00000000)
  $dut_swd.arm_debug.swj_dp.read_dp(:idcode, 0xba5eba11)
  $dut_swd.arm_debug.swj_dp.read_dp(:wcr, 0x00000000)
  $dut_swd.arm_debug.swj_dp.read_dp(:resend, 0x00000000)
  $dut_swd.arm_debug.swj_dp.read_dp(:abort, 0xba5eba11)
  $dut_swd.arm_debug.swj_dp.read_dp(:blah, 0xba5eba11)
  $dut_swd.arm_debug.swj_dp.write_dp(:idcode, 0x5555AAAA)
  $dut_swd.arm_debug.swj_dp.write_dp(:blah, 0xAAAA5555)
  $dut_swd.arm_debug.swj_dp.write_dp(:ctrl_stat, 0x50000000)
  $dut_swd.arm_debug.swj_dp.read_dp(:ctrl_stat, 0xf0000000)
  $dut_swd.arm_debug.swj_dp.read_ap(0x010000FC, 0x00000000, mask: 0x00000000)
  $dut_swd.arm_debug.swj_dp.write_ap(0x01000004, 0x10101010)
  $dut_swd.arm_debug.swj_dp.read_ap(0x01000004, 0x10101010)

  $dut_swd.arm_debug.swd.trn
end
