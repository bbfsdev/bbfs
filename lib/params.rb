require 'optparse'
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
    def Params.read_yml_params yml_input_io
      proj_params = YAML::load(yml_input_io)
      proj_params.keys.each do |param_name|
        if not self.instance_variable_get '@' + param_name
          puts "loaded yml param:'#{param_name}' which does not exist in Params module."
          return false
        end
        self.instance_variable_set '@' + param_name, proj_params[param_name]
      end
      return true
    end
    #  Parse command line
    #  ==== Arguments:
    #  Pre defined in lib/params.rb as instance variables of Params module
    def self.parse(args)
      parsing_result = Hash.new  # Define parsing Results Hash
      options = Hash.new  # Hash of parsing options from Params
      names = Params.instance_variables  # Define all available parameters

      names.each do  |name|
        value = Params.instance_variable_get(name)  # Get names values
        tmp_name= name.to_s
        tmp_name.slice!(0)  # Remove @ from instance variables
        options[tmp_name] = value  # Create list of option arguments from Params
      end

      # Define options switch for parsing
      # Define List of options see example on
      # http://ruby.about.com/od/advancedruby/a/optionparser2.htm
      opts = OptionParser.new do |opts|
        options.each do |name,value|
          tmp_name = name.to_s  # cast name to string to use it with OptionParser switch
          tmp_name_long = "--" + tmp_name + "=MANDATORY"  # Define a command with single mandatory parameter
          tmp_value = "Default value:" + value.to_s  #  Description and Default value

          # Define type of the mandatory value
          # It can be string, integer or float
          value_type = String
          if value.is_a?(Integer)
            value_type = Integer
          elsif value.is_a?(Float)
            value_type = Float
          end

          # Switches definition - according to what
          # was pre-defined in the Params
          parsing_result[name] = "Parsing Failed"
          opts.on(tmp_name_long,value_type, tmp_value) do |result|
            parsing_result[name] = result
            Params.instance_variable_set'@' + name,result
          end
        end

        # Define help command for available options
        # executing --help will printout all pre-defined
        # switch options
        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          exit
        end

        opts.parse(args)  # Parse command line
      end
      return parsing_result
    end # end of Parse function

  end
end

