class MyLogger

  ############################ Init\cleanup methods

  #initializer
  # Abstruct: initialize the logger class.
  # @param loggerName [string]    - the logger name
  # @param loggerFileName [string]    - the file name to log
  def initialize (loggerName,loggerFileName)
    @name =  loggerName
    @fileName =  loggerFileName
    @file = File.new(loggerFileName, "w")
    @debugLevel = 0
  end

  #closeLogger
  # Abstruct: cleanup. Close the log file
  def closeLogger()
    @file.close
    puts "logger:#{@name} file:#{@fileName} is closed"
  end




  ############################## members access
  attr_reader (:name)
  attr_reader (:debugLevel)
  attr_reader (:fileName)




  ############################### Set methods
  #debugLevel=
  # Abstruct: set log level
  # @param level [decimal]  log level: 1 | 2 | 3
  def debugLevel= (level)
    @debugLevel = level
  end



  ############################### Log messages methods
  #logWarning
  # Abstruct: Logs warning messages
  # @param msg [string]  string to log as warning
  def logWarning (msg)
    @file.puts "logger:[#{@name}:Warning] #{msg}"
  end
  #logError
  # Abstruct: Logs error messages
  # @param msg [string]  string to log as error
  def logError (msg)
    @file.puts "logger:[#{@name}:Error] #{msg}"
  end
  #logInfo
  # Abstruct: Logs info messages
  # @param msg [string]  string to log as info
  def logInfo (msg)
    sleep(1)
    @file.puts "logger:[#{@name}:Info] #{msg}"
  end
  #logDebug1
  # Abstruct: Logs debug messages level 1
  # @param msg [string]  string to log as debug messages level 1
  def logDebug1 (msg)
    if (@debugLevel > 0 ) then
      @file.puts "logger:[#{@name}:DEBUG 1] #{msg}"
    end
  end
  #logDebug2
  # Abstruct: Logs debug messages level 2
  # @param msg [string]  string to log as debug messages level 2
  def logDebug2 (msg)
    if (@debugLevel > 1 ) then
      @file.puts "logger:[#{@name}:DEBUG 2] #{msg}"
    end
  end
  #logDebug3
  # Abstruct: Logs debug messages level 3
  # @param msg [string]  string to log as debug messages level 3
  def logDebug3 (msg)
    if (@debugLevel > 2 ) then
      @file.puts "logger:[#{@name}:DEBUG 3] #{msg}"
    end
  end
end



