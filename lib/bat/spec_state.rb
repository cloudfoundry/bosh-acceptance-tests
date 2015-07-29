module Bat
	class SpecState
	  def initialize(debug_mode)
	  	@debug_mode = true
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