# Author: Yaron Dror (yaron.dror.bb@gmail.com)
# Description: The file contains the code which implements the 'Log' module
# Run: Add to 'require' list. Execute Log.init

#require 'email'
require 'log4r'
require 'log4r/outputter/emailoutputter'

require 'params'

# Module: Log.
# Abstruct: The Log is used to log info\warning\error\debug messages
#           This module is actually a wrapper to log4r gem and serves
#           as a central code to use the log utility.
module Log

  #Auxiliary method to retrieve the executable name
  def Log.executable_name
    /([a-zA-Z0-9\-_\.]+):\d+/ =~ caller[caller.size-1]
    return $1
  end

  # Global params
  Params.integer('log_debug_level', 0 , \
      'Verbosity of logging. 0 will log only INFO messages. Other value, will log all DEBUG messages as well.')
  Params.boolean('log_flush_each_message', true, \
      'If true then File and Console outputters will be flushed for each message.')
  Params.boolean('log_write_to_file', true , \
      'If true then the logger will write the messages to a file.')
  Params.path('log_file_name', "~/.bbfs/log/#{Log.executable_name}.log4r" , \
      'log file name: ~/.bbfs/log/<executable_name>.log')
  Params.integer('log_rotation_size',1000000 , \
      'max log file size. when reaching this size, a new file is created for rest of log')
  Params.boolean('log_write_to_console', false , \
      'If true then the logger will write the messages to the console.')
  Params.boolean('log_write_to_email', false , \
      'If true then the logger will write the error and fatal messages to email.')
  Params.string('from_email', 'bbfsdev@gmail.com', 'From gmail address for update.')
  Params.string('from_email_password', '', 'From gmail password.')
  Params.string('to_email', 'bbfsdev@gmail.com', 'Destination email for updates.')

  #Should be called from executable right after params handling.
  # Init Log level and set output to file,stdout and email according to configuration params.
  def Log.init
    @log4r = Log4r::Logger.new 'BBFS log'
    @log4r.trace = true

    #levels setup
    log4r_level = Log4r::DEBUG
    log4r_level = Log4r::INFO if 0 == Params['log_debug_level']

    #formatters
    formatter = Log4r::PatternFormatter.new(:pattern => "[%l] [%d] [%m]")

    #stdout setup
    if Params['log_write_to_console']
      stdout_outputter = Log4r::Outputter.stdout
      stdout_outputter.formatter = formatter
      stdout_outputter.level = log4r_level
      @log4r.outputters << stdout_outputter
    end

    #file setup
    # example of log file being split by space constraint 'maxsize'


    if Params['log_write_to_file']
      if File.exist?(Params['log_file_name'])
        File.delete(Params['log_file_name'])
      else
        dir_name = File.dirname(Params['log_file_name'])
        FileUtils.mkdir_p(dir_name) unless File.directory?(dir_name)
      end
      file_config = {
          "filename" => Params['log_file_name'],
          "maxsize" => Params['log_rotation_size'],
          "trunc" => true
      }
      file_outputter = Log4r::RollingFileOutputter.new("file_log", file_config)
      file_outputter.level = log4r_level
      file_outputter.formatter = formatter
      @log4r.outputters << file_outputter
    end

    #email setup
    if Params['log_write_to_email']
      email_outputter = Log4r::EmailOutputter.new('email_log',
                                                  :server => 'smtp.gmail.com',
                                                  :port => 587,
                                                  :subject => "Error happened at server:'#{Params['local_server_name']}' run by #{ENV['USER']}. Service_name is #{Params['service_name']}",
                                                  :acct => Params['from_email'],
                                                  :from => Params['from_email'],
                                                  :passwd => Params['from_email_password'],
                                                  :to => Params['to_email'],
                                                  :immediate_at => 'FATAL,ERROR',
                                                  :authtype => :plain,
                                                  :tls => true,
                                                  :formatfirst => true,
                                                  :buffsize => 9999,
      )
      email_outputter.level = Log4r::ERROR
      email_outputter.formatter = formatter
      @log4r.outputters << email_outputter
    end

    # Write init message and user parameters
    @log4r.info('BBFS Log initialized.') # log first data

    # print params
    if Params['print_params_to_stdout']
      Params.get_init_messages().each { |msg|
        Log.info(msg)
      }
    else
      Log.info("Not printing executable parameters since param:'print_params_to_stdout' is false")
    end
  end

  # Auxiliary method to add the calling method to the message
  def Log.msg_with_caller(msg)
    /([a-zA-Z0-9\-_\.]+:\d+)/ =~ caller[1]
    $1 + ':' + msg
  end

  # Log warning massages
  def Log.warning(msg)
    Log.init if @log4r.nil?
    @log4r.warn(msg_with_caller(msg))
    Log.flush if Params['log_flush_each_message']
  end

  # Log error massages
  def Log.error(msg)
    Log.init if @log4r.nil?
    @log4r.error(msg_with_caller(msg))
    Log.flush if Params['log_flush_each_message']
  end

  # Log info massages
  def Log.info(msg)
    Log.init if @log4r.nil?
    @log4r.info(msg_with_caller(msg))
    Log.flush if Params['log_flush_each_message']
  end

  # Log debug level 1 massages
  def Log.debug1(msg)
    if Params['log_debug_level'] >= 1
      Log.init if @log4r.nil?
      @log4r.debug(msg_with_caller(msg))
      Log.flush if Params['log_flush_each_message']
    end
  end

  # Log debug level 2 massages
  def Log.debug2(msg)
    if Params['log_debug_level'] >= 2
      Log.init if @log4r.nil?
      @log4r.debug(msg_with_caller(msg))
      Log.flush if Params['log_flush_each_message']
    end
  end

  # Log debug level 3 massages
  def Log.debug3(msg)
    if Params['log_debug_level'] >= 3
      Log.init if @log4r.nil?
      @log4r.debug(msg_with_caller(msg))
      Log.flush if Params['log_flush_each_message']
    end
  end

  # Flush email log
  def Log.flush()
    return if @log4r.nil?
    @log4r.outputters.each { |o|
      # Not flushing to email since this will cause empty emails to be sent
      # Email is already configured to immediately send mail on ERROR|FATAL messages.
      o.flush unless o.is_a?(Log4r::EmailOutputter)
    }
  end

  private_class_method(:msg_with_caller)
end
