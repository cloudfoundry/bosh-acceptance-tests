module Bat
  module SpecStateHelper
    def check_for_failure(spec_state, example)
      spec_state.register_fail if example.exception
    end
  end

  class SpecState
    def initialize(debug_mode)
      @debug_mode = debug_mode
      @failed = false
    end

    def skip_cleanup?
      @failed && @debug_mode
    end

    def register_fail
      @failed = true
    end
  end
end
