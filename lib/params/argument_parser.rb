require 'optparse'

module BBFS
  module Params
    class ParseArgs
      def self.Parse(args)
        parsing_result = Hash.new         #Define parsing Results Hash
        options = Hash.new                #Hash of parsing options
        names = Params.instance_variables #Define all available parameters

        names.each do  |name|
          value = Params.instance_variable_get(name)    # Get names values
          tmp_name= name.to_s
          tmp_name.slice!(0)
          options[tmp_name] = value  # Create options Hash
        end

        opts = OptionParser.new do |opts|   # Define options for parsing
          # List of flags.
          options.each do |name,value|
            tmp_name = name.to_s
            tmp_name = "--"+ tmp_name

            parsing_result[name] = "Parsing Failed"
            opts.on(tmp_name,value.to_s,name.to_s) do |result|
              parsing_result[name] = result
            end

          end
          opts.parse(args) # Parse request
        end

        return parsing_result
      end  # End of parsing Function
    end

  end
end
