# Author: Yaron Dror (yaron.dror.bb@gmail.com)
# Description: The file contains the code which implements the 'Log' module
# Run: Add to 'require' list.
# Note: The logger will be automatically initialized if log_param_auto_start is true

require ('params')
require ('thread')
require ('log/log_consumer.rb')

module BBFS
  # Module: Log.
  # Abstruct: The Log is used to log info\warning\error\debug messages
  # Note that the logger will be automatically initialized if log_param_auto_start is true
  module Log
    # Global params used
    Params.parameter 'log_param_auto_start',false, \
      'log param. If true, log will start automatically when Log module is required. ' + \
      'Else, Init module method should be called'
    Params.parameter 'log_debug_level', 0 , 'Log level.'
    Params.parameter 'log_param_number_of_mega_bytes_stored_before_flush', 1 , \
      'log param. Number of mega bytes stored before they are flushed.'
    Params.parameter 'log_param_max_elapsed_time_in_seconds_from_last_flush',1, \
      'log param. Max elapsed time in seconds from last flush'
    Params.parameter 'log_write_to_file', true , \
      'If true then the logger will write the messages to a file.'
    Params.parameter 'log_write_to_console', true , \
      'If true then the logger will write the messages to the console.'
    /([a-zA-Z0-9\-_\.]+):\d+/ =~ caller[caller.size-1]
    Params.parameter 'log_file_name', File.expand_path("~/.bbfs/#{$1}.log") , \
      'Default log file name: ~/.bbfs/<executable_name>.log'

    @consumers = []

    #Note that the logger will be automatically initialized if log_param_auto_start is true
    if Params.log_param_auto_start then
      Log.init
    end

    # Init the Log consumers
    def Log.init
      Log.clear
      # Console - If enabled, will flush the log immediately to the console
      if Params.log_write_to_console then
        console_consumer = ConsoleConsumer.new
        @consumers.push console_consumer
      end
      # BufferConsumerProducer - If enabled, will use the file consumer to flush a buffer to a file
      if Params.log_write_to_file then
        file_consumer = FileConsumer.new Params.log_file_name
        buffer_consumer_producer = BufferConsumerProducer.new \
          Params.log_param_number_of_mega_bytes_stored_before_flush, \
          Params.log_param_max_elapsed_time_in_seconds_from_last_flush
        buffer_consumer_producer.add_consumer file_consumer
        @consumers.push buffer_consumer_producer
      end
      Log.info 'BBFS Log started.'  # log first data
    end

    # Clears consumers
    def Log.clear
      @consumers.clear
    end

    # Adding consumer to the logger
    def Log.add_consumer consumer
      @consumers.push consumer
    end

    # Returns the file name and line number from caller data
    def Log.basic msg, type
       /([a-zA-Z0-9\-_\.]+\.rb:\d+)/ =~ caller[1]
       data = "[BBFS LOG] [#{Time.now()}] [#{type}] [#{$1}] [#{msg}]"
       @consumers.each { |consumer| consumer.push_data data  }
    end

    # Log warning massages
    def Log.warning msg
      Log.basic msg, 'WARNING'
    end

    # Log error massages
    def Log.error msg
      Log.basic msg, 'ERROR'
    end

    # Log info massages
    def Log.info msg
      Log.basic msg, 'INFO'
    end

    # Log debug level 1 massages
    def Log.debug1 msg
      if Params.log_debug_level > 0 then
        Log.basic msg, 'DEBUG-1'
      end
    end

    # Log debug level 2 massages
    def Log.debug2 msg
      if Params.log_debug_level > 1 then
        Log.basic msg, 'DEBUG-2'
      end
    end

    # Log debug level 3 massages
    def Log.debug3 msg
      if Params.log_debug_level > 2 then
        Log.basic msg, 'DEBUG-3'
      end
    end
  end
end




