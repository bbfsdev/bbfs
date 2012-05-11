# Author: Yaron Dror (yaron.dror.bb@gmail.com)
# Description: The file contains the code which implements the 'Log' module
# Run: Add to 'require' list.
# Note: The logger will be automatically initialized if log_param_auto_start is true
#       If log_param_auto_start is false then 'Log.init' method will be called
#       on the first attempt to log.

require ('params')
require ('thread')
require ('log/log_consumer.rb')

module BBFS
  # Module: Log.
  # Abstruct: The Log is used to log info\warning\error\debug messages
  # Note: The logger will be automatically initialized if log_param_auto_start is true
  #       If log_param_auto_start is false then 'Log.init' method will be called
  #       on the first attempt to log.
  module Log
    #Auxiliary method to retrieve the executable name
    def Log.executable_name
      /([a-zA-Z0-9\-_\.]+):\d+/ =~ caller[caller.size-1]
      return $1
    end

    # Global params
    Params.parameter 'log_param_auto_start',false, \
      'log param. If true, log will start automatically. ' + \
      'Else, init should be called. ' + \
      'Else Init will be called automatically on the first attempt to log.'
    Params.parameter 'log_debug_level', 0 , 'Log level.'
    Params.parameter 'log_param_number_of_mega_bytes_stored_before_flush', 1 , \
      'log param. Number of mega bytes stored before they are flushed.'
    Params.parameter 'log_param_max_elapsed_time_in_seconds_from_last_flush',1, \
      'log param. Max elapsed time in seconds from last flush'
    Params.parameter 'log_write_to_file', true , \
      'If true then the logger will write the messages to a file.'
    Params.parameter 'log_write_to_console', true , \
      'If true then the logger will write the messages to the console.'
    Params.parameter 'log_file_name', File.expand_path("~/.bbfs/log/#{Log.executable_name}.log") , \
      'Default log file name: ~/.bbfs/log/<executable_name>.log'

    @consumers = []
    @log_initialized = false

    #Note that the logger will be automatically initialized if log_param_auto_start is true
    if Params.log_param_auto_start then
      Log.init
    end

    # Init the Log consumers
    def Log.init
      Log.clear_consumers
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
      @log_initialized = true
      Log.info 'BBFS Log initialized.'  # log first data
    end

    # Clears consumers
    def Log.clear_consumers
      @consumers.clear
    end

    # Adding consumer to the logger
    def Log.add_consumer consumer
      @consumers.push consumer
    end

    # formatting the data and push to consumers
    def Log.basic msg, type
      Log.init if not @log_initialized
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
