require ('./params.rb')

module BBFS
  # Module: BBFSLogger.
  # Abstruct: The BBFSLogger is used to log debug\info\error messages
  module Logger

    VERSION = '0.0.1'

    #Global params used
    PARAMS.parameter('log_file', File.expand_path('log1.txt') , 'log file name.')
    PARAMS.parameter('logger_debug_level', 0 , 'Logger level.')

    #Open the Logger file
    @@file = File.new(PARAMS.log_file, "w")

    #Log to output
    puts "BBFS logger: file:#{PARAMS.log_file} is opened\nStart Logging..\n"

    # module method: closeLogger
    # Abstruct: cleanup. Close the log file
    def Logger.closeLogger()
      @@file.close
      puts "BBFS logger: file:#{PARAMS.log_file} is closed.\nEnd Logging."
    end
    # module method: ReformatCallerData
    # Abstruct:  Auxiliary method to parse the data of the caller object.
    #            the regular expresion will find the name of the caller file and the line number of the last call
    #            i.e.'some_file.rb:12:at mothod_a' , 'some_other_file.rb:19:at mothod_b' , .. -->  some_file.rb:12
    def Logger.ExtractOnlyLastCallFileNameAndLine(callerDB)
       #the regular expresion will find the name of the caller file and the line number of the last call
      /(.*:\d+)/ =~ callerDB[0]
      return $1
    end

    ############################### Log messages methods
    # module method: logWarning
    # Abstruct: Logs warning messages
    # @param msg [string]  string to log as warning
    def Logger.logWarning (msg)
      @@file.puts "BBFS logger #{Time.new()}[WARNING]:#{Logger.ExtractOnlyLastCallFileNameAndLine(caller)}:#{msg}"
    end
    # module method: logError
    # Abstruct: Logs error messages
    # @param msg [string]  string to log as error
    def Logger.logError (msg)
      @@file.puts "BBFS logger #{Time.new()}[ERROR]:#{Logger.ExtractOnlyLastCallFileNameAndLine(caller)}:#{msg}"
    end
    # module method: logInfo
    # Abstruct: Logs info messages
    # @param msg [string]  string to log as info
    def Logger.logInfo (msg)
      @@file.puts "BBFS logger #{Time.new()}[INFO]:#{Logger.ExtractOnlyLastCallFileNameAndLine(caller)}:#{msg}"
    end
    # module method: logDebug1
    # Abstruct: Logs debug messages level 1
    # @param msg [string]  string to log as debug messages level 1
    def Logger.logDebug1 (msg)
      if (PARAMS.logger_debug_level > 0 ) then
        @@file.puts "BBFS logger #{Time.new()}[DEBUG-1]:#{Logger.ExtractOnlyLastCallFileNameAndLine(caller)}:#{msg}"
      end
    end
    # module method: logDebug2
    # Abstruct: Logs debug messages level 2
    # @param msg [string]  string to log as debug messages level 2
    def Logger.logDebug2 (msg)
      if (PARAMS.logger_debug_level > 1 ) then
        @@file.puts "BBFS logger #{Time.new()}[DEBUG-2]:#{Logger.ExtractOnlyLastCallFileNameAndLine(caller)}:#{msg}"
      end
    end
    # module method: logDebug3
    # Abstruct: Logs debug messages level 3
    # @param msg [string]  string to log as debug messages level 3
    def Logger.logDebug3 (msg)
      if (PARAMS.logger_debug_level > 2 ) then
        @@file.puts "BBFS logger #{Time.new()}[DEBUG-3]:#{Logger.ExtractOnlyLastCallFileNameAndLine(caller)}:#{msg}"
      end
    end
  end
end




