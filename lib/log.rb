require ('params')
require ('thread')

module BBFS
  # Module: Log.
  # Abstruct: The Log is used to log info\warning\error\debug messages
  module Log

    VERSION = '0.0.1'

    #Global params used
    PARAMS.parameter 'log_param_auto_start',true, 'log param. If true, log will start automatically when Log module is required. Else, Init module method should be called'
    PARAMS.parameter 'log_debug_level', 0 , 'Log level.'
    PARAMS.parameter 'log_param_number_of_bytes_stored_before_flush_to_log_file', 1000000 , 'log param. Number of bytes stored before they are flushed to the log file.'
    PARAMS.parameter 'log_param_max_elapsed_time_in_seconds_from_last_flush',20, 'log param. Max elapsed time in seconds from last flush to the log file'
    PARAMS.parameter 'log_param_thread_sleep_time_in_seconds',0.1, 'log param. Controls the thread sleep time before it checks again if to flush the messages to the log file.'
    PARAMS.parameter 'log_write_to_file', true , 'If true then the logger will write the messages to a file. File name is set in log param:log_file_name.'
    PARAMS.parameter 'log_file_name', File.expand_path('log_test_out_dir/log1.txt') , 'Default log file name.'
    PARAMS.parameter 'log_write_to_console', true , 'If true then the logger will write the messages to the console.'

    #init module params
    @@messagesDB = []
    @@logFileHandler = nil
    @@timeAtLastFlush = Time.now
    @@msgDBSemaphore = Mutex.new
    @@logThread = nil

    # module method: ExtractOnlyLastCallFileNameAndLine
    # Abstruct:  Auxiliary method to parse the data of the caller object.
    #            the regular expression will find the name of the caller file and the line number of the last call
    #            i.e.'some_file.rb:12:at mothod_a' , 'some_other_file.rb:19:at mothod_b' , .. -->  some_file.rb:12
    def Log.ExtractOnlyLastCallFileNameAndLine callerDB
       #the regular expresion will find the name of the caller file and the line number of the last call
      /(.*:\d+)/ =~ callerDB[0]
      return $1
    end

    ############################### Log messages methods
    # module method: logWarning
    # Abstruct: Logs warning messages
    # @param msg [string]  string to log as warning
    def Log.logWarning msg
      inCaller = caller
      @@msgDBSemaphore.synchronize{
        @@messagesDB.push "[BBFS LOG] [#{Time.now()}] [WARNING] [#{Log.ExtractOnlyLastCallFileNameAndLine(inCaller)}] [#{msg}]"
        }
    end
    # module method: logError
    # Abstruct: Logs error messages
    # @param msg [string]  string to log as error
    def Log.logError msg
      inCaller = caller
      @@msgDBSemaphore.synchronize{
        @@messagesDB.push "[BBFS LOG] [#{Time.now()}] [ERROR] [#{Log.ExtractOnlyLastCallFileNameAndLine(inCaller)}] [#{msg}]"
        }
    end
    # module method: logInfo
    # Abstruct: Logs info messages
    # @param msg [string]  string to log as info
    def Log.logInfo msg
      inCaller = caller
      @@msgDBSemaphore.synchronize{
        @@messagesDB.push "[BBFS LOG] [#{Time.now()}] [INFO] [#{Log.ExtractOnlyLastCallFileNameAndLine(inCaller)}] [#{msg}]"
        }
    end
    # module method: logDebug1
    # Abstruct: Logs debug messages level 1
    # @param msg [string]  string to log as debug messages level 1
    def Log.logDebug1 msg
      if PARAMS.log_debug_level > 0 then
        inCaller = caller
        @@msgDBSemaphore.synchronize{
          @@messagesDB.push "[BBFS LOG] [#{Time.now()}] [DEBUG-1] [#{Log.ExtractOnlyLastCallFileNameAndLine(inCaller)}] [#{msg}]"
          }
      end
    end
    # module method: logDebug2
    # Abstruct: Logs debug messages level 2
    # @param msg [string]  string to log as debug messages level 2
    def Log.logDebug2 msg
      if PARAMS.log_debug_level > 1 then
        inCaller = caller
        @@msgDBSemaphore.synchronize{
          @@messagesDB.push "[BBFS LOG] [#{Time.now()}] [DEBUG-2] [#{Log.ExtractOnlyLastCallFileNameAndLine(inCaller)}] [#{msg}]"
          }
      end
    end
    # module method: logDebug3
    # Abstruct: Logs debug messages level 3
    # @param msg [string]  string to log as debug messages level 3
    def Log.logDebug3 msg
      if PARAMS.log_debug_level > 2 then
        inCaller = caller
        @@msgDBSemaphore.synchronize{
          @@messagesDB.push "[BBFS LOG] [#{Time.now()}] [DEBUG-3] [#{Log.ExtractOnlyLastCallFileNameAndLine(inCaller)}] [#{msg}]"
          }
      end
    end

    # module method: ThreadStart
    # Abstruct: Start Log thread.
    #           Thread algorithm:
    #           1. poles the messages DB byte size.
    #           2. if messages DB is not empty:
    #           3.    If DB byte size exceeds max number of bytes threshold then:
    #           4.        flush the DB to the log file.
    #           5.    Else
    #           6.        Calculate elapsed time from last flush
    #           7.        if elapsed time from last flush exceeds the max time threshold then:
    #           8.            flush the DB to the log file.
    #           9. Pass execution to other threads
    #           10.return to 1.
    #           Note: messages DB and File are handled using synchronized atomic operations

    def Log.ThreadStart
      # return if thread already alive
      if (nil != @@logThread) then
        stat =  @@logThread.status
        if  ('run' == stat) or ('sleep' ==  stat)
          return
        end
      end

      #Start thread execution
      @@logThread = Thread.new{
        while (true) do
          @@msgDBSemaphore.synchronize{
              if not @@messagesDB.empty?
                if @@messagesDB.inspect.size > PARAMS.log_param_number_of_bytes_stored_before_flush_to_log_file
                  #flush the DB to the log file
                  Log.FlushDB
                  @@messagesDB.clear
                  @@timeAtLastFlush = Time.now
                else
                  elapsedTimefromLastFlushInSeconds = Time.now.to_i -  @@timeAtLastFlush.to_i
                  if elapsedTimefromLastFlushInSeconds >=  PARAMS.log_param_max_elapsed_time_in_seconds_from_last_flush
                    Log.FlushDB
                    @@messagesDB.clear
                    @@timeAtLastFlush = Time.now
                  end
                end
              end
            #end
          } #@@msgDBSemaphore.synchronize
          sleep(PARAMS.log_param_thread_sleep_time_in_seconds)
        end #while
      }
      @@logThread.priority = -10
    end


    # module method: FlushDB
    # Abstruct: Flush the messages DB to a file and to console depends on log flags
    def Log.FlushDB
      if true == PARAMS.log_write_to_file  then
        begin
          @@logFileHandler = File.new PARAMS.log_file_name, 'a'
          @@logFileHandler.puts @@messagesDB
        rescue
          Exception
          puts "Failed to open log file:#{File.new PARAMS.log_file_name}"
          puts $!.class
          puts $!
        ensure
          @@logFileHandler.close
        end
      end
      if true == PARAMS.log_write_to_console  then
         puts @@messagesDB
      end
    end

    # module method: Init
    # Abstruct: Init Log
    def Log.Init
      #init params
      @@messagesDB = []
      @@logFileHandler = nil
      @@timeAtLastFlush = Time.now
      @@msgDBSemaphore = Mutex.new
      if nil != @@logThread then
        @@logThread.kill
        @@logThread = nil
      end

      #delete file if exists
      if File.exist? PARAMS.log_file_name then
         File.delete PARAMS.log_file_name
      end
      #init the thread which handles the messages DB flushing to the log file
      Log.ThreadStart

      #Log header to the log file
      Log.logInfo 'BBFS Logger started..'
    end

    # module method: GetMessagesDB
    # Abstruct: Get the messages DB. Mainly used for test purpose
    def Log.GetMessagesDB
      return @@messagesDB
    end

    #init Log automatically if flag is on
    if true == PARAMS.log_param_auto_start then
      Log.Init
    end

  end
end




