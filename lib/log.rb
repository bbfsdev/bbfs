require ('params')
require ('thread')
require ('log/log_consumer.rb')

module BBFS
  # Module: Log.
  # Abstruct: The Log is used to log info\warning\error\debug messages
  module Log
    #Global params used
    Params.parameter 'log_param_auto_start',false, 'log param. If true, log will start automatically when Log module is required. Else, Init module method should be called'
    Params.parameter 'log_debug_level', 0 , 'Log level.'
    Params.parameter 'log_param_number_of_mega_bytes_stored_before_flush', 1 , 'log param. Number of mega bytes stored before they are flushed.'
    Params.parameter 'log_param_max_elapsed_time_in_seconds_from_last_flush',1, 'log param. Max elapsed time in seconds from last flush'
    Params.parameter 'log_write_to_file', true , 'If true then the logger will write the messages to a file. File name is set in log param:log_file_name.'
    Params.parameter 'log_write_to_console', true , 'If true then the logger will write the messages to the console.'
    Params.parameter 'log_file_name', File.expand_path('bbfs_log.txt') , 'Default log file name.'

    @consumers = []

    def Log.init
      #log consumers.
      # 1. console consumer - If enabled, will flush the log immediately to the console
      # 2. bufferConsumerProducer - If enabled, will use the file consumer to flush a buffer to a file
      @consumers.clear
      if Params.log_write_to_console then
        consoleConsumer = ConsoleConsumer.new
        @consumers.push consoleConsumer
      end
      if Params.log_write_to_file then
        fileConsumer = FileConsumer.new Params.log_file_name
        bufferConsumerProducer = BufferConsumerProducer.new Params.log_param_number_of_mega_bytes_stored_before_flush, Params.log_param_max_elapsed_time_in_seconds_from_last_flush
        bufferConsumerProducer.addConsumer fileConsumer
        @consumers.push bufferConsumerProducer
      end
    end

    if Params.log_param_auto_start then
      Log.init
    end

    def Log.addConsumer consumer
      @consumers.push consumer
    end

    # module method: ExtractOnlyLastCallFileNameAndLine
    # Abstruct:  Auxiliary method to parse the data of the caller object.
    #            the regular expression will find the name of the caller file and the line number of the last call
    #            i.e.'some_file.rb:12:at mothod_a' , 'some_other_file.rb:19:at mothod_b' , .. -->  some_file.rb:12
    def Log.ExtractOnlyLastCallFileNameAndLine callerInfo
       #the regular expression will find the name of the caller file and the line number of the last call
       /([a-zA-Z0-9\-_\.]+\.rb:\d+)/ =~ callerInfo[0]
      return $1
    end

    ############################### Log messages methods
    # module method: logWarning
    # Abstruct: Logs warning messages
    # @param msg [string]  string to log as warning
    def Log.logWarning msg
      data =  "[BBFS LOG] [#{Time.now()}] [WARNING] [#{Log.ExtractOnlyLastCallFileNameAndLine(caller)}] [#{msg}]"
      @consumers.each { |consumer| consumer.pushData data  }
    end
    # module method: logError
    # Abstruct: Logs error messages
    # @param msg [string]  string to log as error
    def Log.logError msg
      data =  "[BBFS LOG] [#{Time.now()}] [ERROR] [#{Log.ExtractOnlyLastCallFileNameAndLine(caller)}] [#{msg}]"
      @consumers.each { |consumer| consumer.pushData data  }
    end
    # module method: logInfo
    # Abstruct: Logs info messages
    # @param msg [string]  string to log as info
    def Log.logInfo msg
      inCaller = caller
      data = "[BBFS LOG] [#{Time.now()}] [INFO] [#{Log.ExtractOnlyLastCallFileNameAndLine(caller)}] [#{msg}]"
      @consumers.each { |consumer| consumer.pushData data  }
    end
    # module method: logDebug1
    # Abstruct: Logs debug messages level 1
    # @param msg [string]  string to log as debug messages level 1
    def Log.logDebug1 msg
      if Params.log_debug_level > 0 then
        data = "[BBFS LOG] [#{Time.now()}] [DEBUG-1] [#{Log.ExtractOnlyLastCallFileNameAndLine(caller)}] [#{msg}]"
        @consumers.each { |consumer| consumer.pushData data  }
      end
    end
    # module method: logDebug2
    # Abstruct: Logs debug messages level 2
    # @param msg [string]  string to log as debug messages level 2
    def Log.logDebug2 msg
      if Params.log_debug_level > 1 then
        data = "[BBFS LOG] [#{Time.now()}] [DEBUG-2] [#{Log.ExtractOnlyLastCallFileNameAndLine(caller)}] [#{msg}]"
        @consumers.each { |consumer| consumer.pushData data  }
      end
    end
    # module method: logDebug3
    # Abstruct: Logs debug messages level 3
    # @param msg [string]  string to log as debug messages level 3
    def Log.logDebug3 msg
      if Params.log_debug_level > 2 then
        data = "[BBFS LOG] [#{Time.now()}] [DEBUG-3] [#{Log.ExtractOnlyLastCallFileNameAndLine(caller)}] [#{msg}]"
        @consumers.each { |consumer| consumer.pushData data  }
      end
    end

    Log.logInfo 'BBFS Log started.'
  end
end




