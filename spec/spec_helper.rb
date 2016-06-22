SPEC_ROOT = File.expand_path(File.dirname(__FILE__))

RSpec.configure do |config|
  config.filter_run_excluding :system_services_running => true

  unless ENV['BOSH_OS_BATS'] =~ (/^(true|yes|y|1)$/i)
    puts "!!! EXCLUDING SYSTEM SERVICE SPECS !!!"
    config.filter_run_excluding :type => :os
  end
end
