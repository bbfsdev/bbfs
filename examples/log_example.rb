# Author: Yaron Dror (yaron.dror.bb@gmail.com)
# Run from bbfs> ruby -Ilib examples/log_example.rb

# The problem: log project data
# Solution: use: 'log module' to log info\warning\error\debug messages to
#           file\console\other consumers.

#How to use Log module from your code?
# 1. add the following requires:
# require 'params'
# require 'log'
# note: at this time the log default parameters are defined (see section 6 ahead
#       regarding how and when to change the default behavior).
require 'params'
require 'log'

# 2. messages destination.
# The default log messages destination:
#   1. stdout (usually the console).
#   2. file - default file path: '~/.bbfs/log/<executable_name>.log'

# 3. Change default configuration (if needed).
# In order to change the log default behaviour use the
# following parameters (after require, before init).
# 3.1 To enable\disable the stdout destination (default is disabled):
BBFS::Params.log_write_to_console = 'true'
# 3.2 To enable\disable the stdout destination (default is enabled):
#     BBFS::Params.log_write_to_file = 'false'
# 3.3 Default file path is ~/.bbfs/log/<executable_name>.log
#     To change it:
#     BBFS::Params.log_file_name = '<file path>'
# 3.4 More file related parameters:
#     Log data can be accumulated in a buffer before
#     it is written (flushed) to the file.
#     2 parameters control the buffer size and time limits.
# 3.4.1 Buffer size limit in mega bytes (default is 1 mega byte).
#       BBFS::Params.log_param_number_of_mega_bytes_stored_before_flush = 2
# 3.4.2 Buffer time limit in seconds between 2 flushes. default is 1 second.
#       BBFS::Params.log_param_max_elapsed_time_in_seconds_from_last_flush = 2
BBFS::Params.log_param_number_of_mega_bytes_stored_before_flush = 0
BBFS::Params.log_param_max_elapsed_time_in_seconds_from_last_flush = 0
# Note: The above configuration will set the size and time limits to 0.
#       This means that the data will be written to the file
#       immediately when the logging methods are called.

# 4. Call BBFS::Log.init
# This method should be called from the project executable init sequence.
# if you do not use the project init sequence in an executable, such as
# when you run tests, then call the init method from your own code.
BBFS::Log.init

# 5. use one of the following log messages methods.
# BBFS::Log.info 'this is an info msg example'
# BBFS::Log.warning 'this is a warning msg example'
# BBFS::Log.error 'this is a error msg example'
# BBFS::Log.debug1 'this is a debug1 msg example'  # depends on debug level (see ahead)
# BBFS::Log.debug2 'this is a debug2 msg example'  # depends on debug level (see ahead)
# BBFS::Log.debug3 'this is a debug3 msg example'  # depends on debug level (see ahead)
BBFS::Log.info 'this is an info msg example'

# 6. log debug level.
# Will BBFS::Log.debug1 \ debug2 \ debug3 methods will log?
# if BBFS::Params.log_debug_level is set to 0 (default value)
# then no debug method will log.
# if BBFS::Params.log_debug_level is set to 1 then only BBFS::Log.debug1 will log
# if BBFS::Params.log_debug_level is set to 2 then debug1 and debug2 will log
# if BBFS::Params.log_debug_level is set to 3 or greater then all debug methods will log
BBFS::Log.debug1 'this debug1 msg will not be logged since debug level default is 0'
BBFS::Params.log_debug_level = 1  # set new debug level from now on.
BBFS::Log.debug1 'this debug1 msg will be logged since debug level is 1'
BBFS::Log.debug2 'this debug2 msg will not be logged since debug level is 1'

# wait a bit opr else the program will terminate
# quickly before the log writes the messages
sleep 0.1

# 7. Log format
# log should be printed both to the stdout (console) and to default log file:'~/.bbfs/log/log_example.rb.log`'
#   [BBFS LOG] [TIME] [INFO] [File:Line] [log message]  # for INFO messages.
#   [BBFS LOG] [TIME] [WARNING] [File:Line] [log message]  # for WARNING messages.
#   [BBFS LOG] [TIME] [ERROR] [File:Line] [log message]  # for ERROR messages.
#   [BBFS LOG] [TIME] [DEBUG-1] [File:Line] [log message]  # for DEBUG-1 messages.
#   [BBFS LOG] [TIME] [DEBUG-2] [File:Line] [log message]  # for DEBUG-2 messages.
#   [BBFS LOG] [TIME] [DEBUG-3] [File:Line] [log message]  # for DEBUG-3 messages.

# 8. Example
#     [BBFS LOG] [2012-06-08 10:06:14 +0300] [INFO] [log.rb:56] [BBFS Log initialized. Log file
#       path:'C:/Users/ydror1/.bbfs/log/log_example.rb.log']
#     [BBFS LOG] [2012-06-08 10:06:14 +0300] [INFO] [log_example.rb:59] [this is
#       an info msg example]
#     [BBFS LOG] [2012-06-08 10:06:14 +0300] [DEBUG-1] [log_example.rb:70] [this debug1
#       msg will be logged since debug level is 1]