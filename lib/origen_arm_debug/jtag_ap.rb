require 'origen_arm_debug/jtag_ap_controller'
module OrigenARMDebug
  class JTAGAP < AP
    include Origen::Model

    def initialize(options = {})
      super
    end
  end
end
