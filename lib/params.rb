require 'optparse'
require 'yaml'

# A project parameters module.
# 1. Parameter definition (lowest precedence) - requires phases:
#    e.g. Params.parameter '<param_name>', <param value>, '<description>'
#    <param value> must not be nil (since it sets teh type of the parameter).
#    <param value> supported types are String, Integer(Fixnum), Float, true\false.
#    <param value> type will define the type of the parameter throughout the entire
#    execution life time.
# 2. Params.Init
#    implementation of the init sequence which allows override of
#    defined parameters with new values through input file and\or command line args.
#    Note that only defined parameters can be overridden. If new parameters are passed
#    through file\command line, then an error will be raised.
#    2.1 Input config file (medium precedence).
#        Default configuration input file path is: '~/.bbfs/conf/<executable name>.conf'
#        This path can be overridden by the command line arguments (see 2.2)
#        If file path exists then the parameters in the file
#        will override the defined parameters.
#        Parameters format per line:<param_name>: <param value>
#        Note: Space char after the colon is mandatory
#    2.2 Command line arguments (highest precedence):
#        General format per argument is:--<param_name>=<param_value>
#        those params will override the defined and file values
#        2.2.1 Override input config file
#              User can override the input file by using:--conf_file=<new filepath>
#    3.4 Type check:
#        As mentioned before, types are set at the definition phase (nil is not acceptable).
#        Therefore, file and command line params should be of the same type as the defined
#        type, or else an error will be raised.
#        There is one exception to this rule, and that is, when the defined parameter
#        is a Float e.g. 3.2 and the user overrides with an integer e.g. 5 (either
#        through file or command line), than there will be a casting
#        to 5.0 (original types do not change at any case).
module BBFS
  module Params
    @params_initialized = false

    # setter. Mainly for testing.
    def Params.params_initialized= flag
      @params_initialized = flag
    end

    #Auxiliary method to retrieve the executable name
    def Params.executable_name
      /([a-zA-Z0-9\-_\.]+):\d+/ =~ caller[caller.size-1]
      return $1
    end

    #Auxiliary method to check if config file has been provided thorough command line.
    def Params.override_config_file_path args
      args.each do |argument|
        # check parameter format: '--conf_file=<file_path>'
        /--conf_file=([a-zA-Z0-9\-_\.]+)/ =~ argument
        if not $1.nil?
          Params.conf_file = $1
          break
        end
      end
    end


    def Params.print_all_project_parameters
      puts "\nProject initialized parameters:"
      puts "---------------------------------"
      names = Params.instance_variables  # Define all available parameters
      counter=0
      names.each do |name|
        tmp_name = name.to_s
        tmp_name.slice!(0)
        counter += 1
        value = Params.instance_variable_get name
        puts "#{counter}: #{tmp_name}=#{value}"
      end
      puts "---------------------------------\n\n"
    end

    # Initializes the project parameters
    def Params.init args
      Params.parameter 'conf_file', \
                       File.expand_path("~/.bbfs/conf/#{Params.executable_name}.conf"), \
                       'Default configuration file.'
      Params.override_config_file_path args
      #load yml params
      if (not Params.conf_file.empty?) and File.exist? Params.conf_file
        Params.read_yml_params File.open(Params.conf_file, 'r')
      end
      Params.parse_command_line_arguments args
      @params_initialized = true
      Params.print_all_project_parameters
    end

    # Define new project parameters.
    # After Params.init is called then this method will raise an error.
    # Default value can not be nil.
    def Params.parameter(name, value, description)
      if value.nil?
        raise "parameter:'#{name}' value can not be nil."
      end

      # Check if parameters already initialized
      if @params_initialized
       raise "parameters already initialized. No new definitions are allowed."
      end

      existing_value = self.instance_variable_get '@' + name
      if existing_value.nil?
        # new parameter
        self.instance_variable_set '@' + name, value
        self.class.send('attr_accessor', name)
      else
        #overriding existing parameter
        if (existing_value.class.eql? TrueClass) or (existing_value.class.eql? FalseClass)
          # true\false case
          new_value_upcase = value.to_s.upcase
          if new_value_upcase.eql? 'TRUE'
            self.instance_variable_set '@' + name, true
          elsif new_value_upcase.eql? 'FALSE'
            self.instance_variable_set '@' + name, false
          else
            raise "Defined value type is boolean but overriding value is not boolean."
          end
        else
          # not boolean case
          self.instance_variable_set '@' + name, value
        end
      end
    end

    # Load yml params and override default values.
    # raise exception if a loaded yml param does not exist. or if types mismatch occurs.
    def Params.read_yml_params yml_input_io
      proj_params = YAML::load(yml_input_io)
      proj_params.keys.each do |param_name|
        value = self.instance_variable_get '@' + param_name
        # Check if parameter has not been defined
        if value.nil?
          raise "loaded yml param:'#{param_name}' which does not exist in Params module."
        end
        puts "yml param:'#{param_name}'  Value:'#{value}'  Type:'#{value.class}'"
        if value.class.eql? proj_params[param_name].class
          # Type match. Override parameter value
          Params.parameter param_name, proj_params[param_name], ''
        else
          # Type mismatch
          if ((value.class.eql? Float) and (proj_params[param_name].class.eql? Fixnum))
            #cast from Fixnum to Float
            Params.parameter param_name, proj_params[param_name] + 0.0, ''
          else
            if (((value.class.eql? TrueClass) and (proj_params[param_name].class.eql? FalseClass)) \
               or \
               ((value.class.eql? FalseClass) and (proj_params[param_name].class.eql? TrueClass)))
              #true\false case
              Params.parameter param_name, proj_params[param_name], ''
            else
              #not cast from fixnum to float and not true\false case
              raise "loaded yml param:'#{param_name}' has different value type:'#{proj_params[param_name].class}'" + \
                  " then the defined parameter type:'#{value.class}'"
            end
          end
        end
      end
    end

    #  Parse command line arguments
    def Params.parse_command_line_arguments args
      options = Hash.new  # Hash of parsing options from Params
      names = Params.instance_variables  # Define all available parameters
      names.each do |name|
        value = Params.instance_variable_get name  # Get names values
        tmp_name = name.to_s
        tmp_name.slice!(0)  # Remove @ from instance variables
        options[tmp_name] = value  # Create list of option arguments from Params
      end

      # Define options switch for parsing
      # Define List of options see example on
      # http://ruby.about.com/od/advancedruby/a/optionparser2.htm
      opts = OptionParser.new do |opts|
        options.each do |name,value|
          tmp_name_long = "--" + name + "=MANDATORY"  # Define a command with single mandatory parameter
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
          opts.on(tmp_name_long, value_type, tmp_value) do |result|
            Params.parameter name, result, ''
          end
        end

        # Define help command for available options
        # executing --help will printout all pre-defined switch options
        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          exit
        end

        opts.parse(args)  # Parse command line
      end
    end # end of Parse function
  end
end

