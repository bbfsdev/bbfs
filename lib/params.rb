
# A simple params module.
module BBFS
  module PARAMS
    def parameter(name, default_value, description)
      self.instance_variable_set '@' + name, default_value
      self.class.send('attr_reader', name)
    end
    module_function :parameter

  end
end

