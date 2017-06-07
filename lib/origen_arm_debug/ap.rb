module OrigenARMDebug
  # Generic Access Port (AP)
  class AP
    include Origen::Model

    # Wait states for data to be transferred from AP-Reg to RDBUFF (on read)
    attr_reader :apreg_access_wait

    def initialize(options = {})
      @apreg_access_wait = options[:apreg_access_wait] || 0
    end
  end
end
