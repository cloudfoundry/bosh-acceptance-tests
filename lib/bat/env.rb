module Bat
  class Env
    REQUIRED_VARS = {
      stemcell_path:        'BAT_STEMCELL',
      bosh_cli_path:        'BAT_BOSH_CLI',
      deployment_spec_path: 'BAT_DEPLOYMENT_SPEC',
      dns_host:             'BAT_DNS_HOST',

      bat_infrastructure:   'BAT_INFRASTRUCTURE',
      bat_networking:       'BAT_NETWORKING',

      private_key:          'BAT_PRIVATE_KEY',
    }.freeze

    OPTIONAL_VARS = {
      debug_mode:           'BAT_DEBUG_MODE',
    }.freeze

    def self.from_env
      new(Hash[REQUIRED_VARS.merge(OPTIONAL_VARS).map { |k, v| [k, ENV[v]] }])
    end

    attr_reader(*REQUIRED_VARS.merge(OPTIONAL_VARS).keys)

    def initialize(vars)
      REQUIRED_VARS.keys.each do |name|
        val = vars[name]
        raise ArgumentError, "Missing #{name}" unless val
        instance_variable_set("@#{name}", val)
      end
      OPTIONAL_VARS.keys.each do |name|
        val = vars[name]
        instance_variable_set("@#{name}", val) if val
      end
    end
  end
end
