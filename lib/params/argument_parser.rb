module BBFS
  module PARAMS

    class ReadArgs
      def self.read_arguments(argv, parsed_arguments, commands = nil)
        argv.each { |arg|
          if arg.start_with?("--")
            words = arg[2,arg.length-2].split('=')
            parsed_arguments[words[0]]=words[1]
          elsif commands != nil and not commands.key?(arg)
            puts "Unknown command '%s'." % arg
            return false
          else
            if parsed_arguments.key? arg
              puts "Parse error, two commands found %s and %s" % parsed_arguments["command"], arg
              return false
            end
            parsed_arguments["command"] = arg
          end
        }

        return false unless commands == nil or parsed_arguments["command"] != nil
        return false unless commands == nil or parsed_arguments["command"] != ""

        return true
      end
    end

  end
end
