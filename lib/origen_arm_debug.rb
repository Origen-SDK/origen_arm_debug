require 'origen'
require_relative '../config/application.rb'
require 'origen_jtag'
require 'origen_swd'

# Include this module to add a ARM Debug driver to your class
module OrigenARMDebug
  autoload :Driver, 'origen_arm_debug/driver'
  autoload :SWJ_DP, 'origen_arm_debug/swj_dp'
  autoload :MemAP,  'origen_arm_debug/mem_ap'

  # Returns an instance of the OrigenARMDebug::Driver
  def arm_debug
    @arm_debug ||= Driver.new(self)
  end
end
