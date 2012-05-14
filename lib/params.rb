require 'params/argument_parser'
require 'yaml'
# A simple params module.
module BBFS
  module Params
    def parameter(name, default_value, description)
      self.instance_variable_set '@' + name, default_value
      self.class.send('attr_accessor', name)
    end

    def read_from_yml file_path
      proj_params = YAML::load_file(file_path)
      proj_params.each {|param|  self.instance_variable_set '@' + param['name'], param['value']}
    end

    module_function :parameter, :read_from_yml
  end
end

