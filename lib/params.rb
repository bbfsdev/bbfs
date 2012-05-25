require 'params/argument_parser'
require 'yaml'
# A simple params module.
module BBFS
  module Params
    def Params.parameter(name, default_value, description)
      self.instance_variable_set '@' + name, default_value
      self.class.send('attr_accessor', name)
    end

    # Load yml params and override default values.
    # Return true, if all yml params loaded successfully.
    # Return false, if a loaded yml param does not exist.
    def Params.read_yml_params yml_params_string
      proj_params = YAML::load(yml_params_string)
      proj_params.keys.each do |param_name|
        if not self.instance_variable_get '@' + param_name
          puts "loaded yml param:'#{param_name}' which does not exist in Params module."
          return false
        end
        self.instance_variable_set '@' + param_name, proj_params[param_name]
      end
      return true
    end
  end
end

