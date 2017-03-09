require 'origen_arm_debug/mdm_ap_controller'
module OrigenARMDebug
  # Miscellaneous Debug Module Access Port (MDM-AP)
  class MDMAP
    include Origen::Model

    # Number of wait states associated with reading/writing to AP-register
    #   Initialized to 0 but can be overwritten by ARMDebug owner
    #
    #   Ex:  arm_debug.mdmap.apreg_access_wait = 8
    attr_accessor :apreg_access_wait

    # Initialize AP parameters and registers
    def initialize(options = {})
      @apreg_access_wait = 0

      # Add standard registers associated with MDM-AP (Status & Control).
      #   Custom registers can be added by ARMDebug owner
      #
      #   Ex:  arm_debug.mdmap.add_reg(:company_ap_reg, 0x08)
      add_reg :status, 0x00
      add_reg :control, 0x04
    end
  end
end
