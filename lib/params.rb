require 'params/argument_parser'

# A simple params module.
module BBFS
  module Params
    def parameter(name, default_value, description)
      self.instance_variable_set '@' + name, default_value
      self.class.send('attr_accessor', name)
    end
    module_function :parameter
  end
end

