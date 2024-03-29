if Origen.app.target.name == 'dual_dp'
  pattern_name = 'workout_dual_dp'
elsif Origen.app.target.name == 'jtag_axi'
  pattern_name = 'workout_jtag_axi'
else
  pattern_name = "workout_#{dut.arm_debug.dp.name}"
end

Pattern.create name: pattern_name do

  ss "Tests of direct DP API"
  dp = dut.arm_debug.dp

  dp.idcode.partno.read!(0x12)

  dp.ctrlstat.write!(0x50000000)
  dp.ctrlstat.read!(0xF0000000)

  if dp.select.has_bits?(:apbanksel)
    dp.select.apbanksel.write!(0xF)
  else
    dp.select.bits(31..24).write!(0xF)
  end

  dp.abort.dapabort.write!(1)

  ss "Tests of direct AP API"
  ap = dut.arm_debug.mem_ap

  ap.tar.write!(0x1234_0000)

  ap.tar.read!

  ss "Tests of high-level register API"

  ss "Test write register, should write value 0xFF01"
  dut.reg(:test).write!(0x0000FF01)

  ss "Test write register with overlay, no subroutine"
  dut.reg(:test).overlay('write_overlay')
  dut.reg(:test).write!(0x0000FF01, no_subr: true)
  dut.reg(:test).overlay(nil)

  ss "Test write register with overlay, use subroutine if available"
  dut.reg(:test).overlay('write_overlay_subr')
  dut.reg(:test).write!(0x0000FF01)
  dut.reg(:test).overlay(nil)

  ss "Test read register, should read value 0x0000FF01"
  dut.reg(:test).read!
 
  ss "Test read register, with overlay, no subroutine, should read value 0x0000FF01"
  dut.reg(:test).overlay('read_overlay')
  dut.reg(:test).read!(no_subr: true)
  dut.reg(:test).overlay(nil)

  ss "Test read register, with overlay, use subroutine if available"
  dut.reg(:test).overlay('read_overlay_subr')
  dut.reg(:test).read!
  dut.reg(:test).overlay(nil)
  
  ss "Test read register with mask, should read value 0xXXXxxx1"
  dut.reg(:test).read!(mask: 0x0000_000F)

  ss "Test read register with store"
  dut.reg(:test).store!

  ss "Test bit level read, should read value 0xXXXxxx1"
  dut.reg(:test).reset
  dut.reg(:test).data = 0x0000FF01
  dut.reg(:test)[0].read!

  if Origen.app.target.name == 'dual_dp'
    ss "SWITCHING DP"
    dut.arm_debug.set_dp(:jtag)

    ss "Test write register, should write value 0xFF01"
    dut.reg(:test).write!(0x0000FF01)

    ss "Test write register with overlay, no subroutine"
    dut.reg(:test).overlay('write_overlay')
    dut.reg(:test).write!(0x0000FF01, no_subr: true)
    dut.reg(:test).overlay(nil)

    ss "Test write register with overlay, use subroutine if available"
    dut.reg(:test).overlay('write_overlay_subr')
    dut.reg(:test).write!(0x0000FF01)
    dut.reg(:test).overlay(nil)

    ss "Test read register, should read value 0x0000FF01"
    dut.reg(:test).read!
   
    ss "Test read register, with overlay, no subroutine, should read value 0x0000FF01"
    dut.reg(:test).overlay('read_overlay')
    dut.reg(:test).read!(no_subr: true)
    dut.reg(:test).overlay(nil)

    ss "Test read register, with overlay, use subroutine if available"
    dut.reg(:test).overlay('read_overlay_subr')
    dut.reg(:test).read!
    dut.reg(:test).overlay(nil)
    
    ss "Test read register with mask, should read value 0xXXXxxx1"
    dut.reg(:test).read!(mask: 0x0000_000F)

    ss "Test read register with store"
    dut.reg(:test).store!

    ss "Test bit level read, should read value 0xXXXxxx1"
    dut.reg(:test).reset
    dut.reg(:test).data = 0x0000FF01
    dut.reg(:test)[0].read!

    ss "RESETTING DP (to default)"
    dut.arm_debug.reset_dp
    ss "Test bit level read, should read value 0xXXXxxx1"
    dut.reg(:test).reset
    dut.reg(:test).data = 0x0000FF01
    dut.reg(:test)[0].read!
  end
end
