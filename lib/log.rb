# Author: Yaron Dror (yaron.dror.bb@gmail.com)
# Description: The file contains the code which implements the 'Log' module
# Run: Add to 'require' list.

require 'email'
require 'log4r'
require 'log4r/outputter/emailoutputter'

require 'params'
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
  Params.integer('log_debug_level', 0 , 'Log level.')
  Params.boolean('log_write_to_file', true , \
      'If true then the logger will write the messages to a file.')
  Params.boolean('log_write_to_console', false , \
      'If true then the logger will write the messages to the console.')
  Params.path('log_file_name', File.expand_path("~/.bbfs/log/#{Log.executable_name}.log") , \
      'Default log file name: ~/.bbfs/log/<executable_name>.log')
  Params.string('from_email', 'bbfsdev@gmail.com', 'From gmail address for update.')
  Params.string('from_email_password', 'Only2Gether', 'From gmail password.')
  Params.string('to_email', 'bbfsdev@gmail.com', 'Destination email for updates.')

  def Log.init
    @log4r = Log4r::Logger.new 'BBFS log'
    @log4r.trace = true

    #log4r levels
    if 0 == Params['log_debug_level']
      log4r_level = Log4r::INFO
    else
      log4r_level = Log4r::DEBUG
    end

    formatter = Log4r::PatternFormatter.new(:pattern => "[%l] [%d] [%m]")

    stdout_outputter = Log4r::Outputter.stdout
    stdout_outputter.formatter = formatter
    stdout_outputter.level = log4r_level

    file_outputter = Log4r::FileOutputter.new('file_log', :filename => "#{Params['log_file_name']}.log4r")
    file_outputter.level = log4r_level
    file_outputter.formatter = formatter

    server_name = `hostname`.strip
    email_outputter = Log4r::EmailOutputter.new('email_log',
                                                :server => 'smtp.gmail.com',
                                                :port => 587,
                                                :subject => "Error happened in #{server_name} server run by #{ENV['USER']}.",
                                                :acct => Params['from_email'],
                                                :from => Params['from_email'],
                                                :passwd => Params['from_email_password'],
                                                :to => Params['to_email'],
                                                :immediate_at => 'FATAL,ERROR',
                                                :authtype => :plain,
                                                :tls => true)
    email_outputter.level = log4r_level
    email_outputter.formatter = formatter

    @log4r.outputters << stdout_outputter if Params['log_write_to_console']
    @log4r.outputters << file_outputter if Params['log_write_to_file']
    #@log4r.outputters << email_outputter

    # Write init message and user parameters
    @log4r.info 'BBFS Log initialized.'  # log first data
    Params.get_init_messages().each { |msg|
      @log4r.info(msg)
    }
  end

  def Log.msg_with_caller(msg)
    /([a-zA-Z0-9\-_\.]+:\d+)/ =~ caller[1]
    $1 + ':' + msg
  end

  # Log warning massages
  def Log.warning(msg)
    @log4r.warn(msg_with_caller(msg))
  end

  # Log error massages
  def Log.error(msg)
    @log4r.error(msg_with_caller(msg))
  end

  # Log info massages
  def Log.info(msg)
    @log4r.info(msg_with_caller(msg))
  end

  # Log debug level 1 massages
  def Log.debug1(msg)
    @log4r.debug(msg_with_caller(msg))
  end

  # Log debug level 2 massages
  def Log.debug2(msg)
    @log4r.debug(msg_with_caller(msg))
  end

  # Log debug level 3 massages
  def Log.debug3(msg)
    @log4r.debug(msg_with_caller(msg))
  end

  private_class_method(:msg_with_caller)
end
