# Author: Yaron Dror (yaron.dror.bb@gmail.com)
# Run from bbfs> ruby -Ilib examples/log_example.rb

# The problem: log project data
# Solution: use: 'log module' to log info\warning\error\debug messages to
#           file\console\other consumers.

###############################################################################################
# HOW TO READ THIS DOCUMENT ?
# Read sections 1 till 10 carefully.
# The document will actually setup a configuration for the logger and
# also will issue few log messages (see the uncommented lines).
# Note: The configuration used in this document is the recommended configuration for tests.
#       The default configuration is used for the BBFS production execution.
#       Read more about configuration in section 3.
# This document will elaborate on the following log setup and usage phases:
#   1. require - This will setup default configuration
#   2. change configuration if needed.
#   3. call the init method - MUST call init or else an exception is raised.
#   4. call log messages methods
# The document will also discuss debug levels and log expected format.
##################################################################################################

# 1. require phase
# Add the following requires:
# require 'params'
# require 'log'
# Note: after those lines execute, the log default parameters are defined (see section 6 ahead
#       regarding how and when to change the default configuration).
require 'params'
require 'log'

# 2. Log configuration.
#    The default configuration is used for the BBFS production execution.
#    The default configuration is set automatically after require 'log' has been called
#    The parameters and their default values:
#    2.1 Enable\disable the stdout destination:
#        Params.log_write_to_console = 'false'
#    2.2 Enable\disable the file destination:
#        Params.log_write_to_file = 'true'
#    2.3 Default log file path
#        Params.log_file_name = '~/.bbfs/log/<executable_name>.log'
#        More file related parameters:
#        2.3.1 Log data can be accumulated in a buffer before
#              it is written (flushed) to the file.
#              2 parameters control the buffer size and time limits.
#        2.3.2 Buffer size limit in mega bytes.
#              Params.log_param_number_of_mega_bytes_stored_before_flush = 1
#        2.3.3 Buffer time limit in seconds between 2 flushes.
#              Params.log_param_max_elapsed_time_in_seconds_from_last_flush = 1
#
#   The default configuration will flush the log messages only to the file and not to the console.
#   Also, size limit is 1 megabyte and time limit is 1 second.
#   When either the size limit or time limits are exceeded, the data will be flushed to the file.
#   If your messages size is less then 1 mega byte and\or your execution time is less then 1 second
#   Then you are recommended to set those values to 0 as in the following setup:
BBFS::Params.log_write_to_console = 'true' # We will also enable the console for this example run.
BBFS::Params.log_param_number_of_mega_bytes_stored_before_flush = 0
BBFS::Params.log_param_max_elapsed_time_in_seconds_from_last_flush = 0
#   Also, if your execution time is less then 1 second it is recommended to add a sleep 0.1
#   to avoid loosing the flush action due to program termination.

# 3. Log.init
# User *MUST* Call init or else an exception will be raised.
# This method MUST be called from the BBFS project executable init sequence.
# if user does not use the project init sequence in an executable, such as
# when user run tests, then user MUST call the init method from his own code.
BBFS::Log.init

# 4. use one of the following log messages methods.
# Log.info 'this is an info msg example'
# Log.warning 'this is a warning msg example'
# Log.error 'this is a error msg example'
# Log.debug1 'this is a debug1 msg example'  # depends on debug level (see ahead)
# Log.debug2 'this is a debug2 msg example'  # depends on debug level (see ahead)
# Log.debug3 'this is a debug3 msg example'  # depends on debug level (see ahead)
BBFS::Log.info 'this is an info msg example'

# 5. log debug levels.
# Will Log.debug1 , Log.debug2 and Log.debug3 methods will actual log ?
# if Params.log_debug_level is set to 0 (default value) then no debug method will log.
# if Params.log_debug_level is set to 1 then only Log.debug1 will log.
# if Params.log_debug_level is set to 2 then Log.debug1 and Log.debug2 will log.
# if Params.log_debug_level is set to 3 or greater then all debug methods will log.
BBFS::Log.debug1 'this debug1 msg will not be logged since debug level default is 0'
BBFS::Params.log_debug_level = 1  # set new debug level from now on.
BBFS::Log.debug1 'this debug1 msg will be logged since debug level is 1'
BBFS::Log.debug2 'this debug2 msg will not be logged since debug level is 1'

# 6. When to use Sleep ?
# When your execution time is less then 1 second it is recommended to add a sleep 0.1
# to avoid loosing the flush action due to quick program termination.
sleep 0.1

# 7. Log expected format.
#   [BBFS LOG] [TIME] [INFO] [File:Line] [log message]  # for INFO messages.
#   [BBFS LOG] [TIME] [WARNING] [File:Line] [log message]  # for WARNING messages.
#   [BBFS LOG] [TIME] [ERROR] [File:Line] [log message]  # for ERROR messages.
#   [BBFS LOG] [TIME] [DEBUG-1] [File:Line] [log message]  # for DEBUG-1 messages.
#   [BBFS LOG] [TIME] [DEBUG-2] [File:Line] [log message]  # for DEBUG-2 messages.
#   [BBFS LOG] [TIME] [DEBUG-3] [File:Line] [log message]  # for DEBUG-3 messages.

# 8. Example output
#    Since both stdout (console) and file are enabled in our example, the log messages
#    will be printed both to the stdout (console) and to default log
#    file:'~/.bbfs/log/log_example.rb.log`' in the following format:
#
#     [BBFS LOG] [2012-06-08 10:06:14 +0300] [INFO] [log.rb:56] [BBFS Log initialized. Log file
#       path:'C:/Users/ydror1/.bbfs/log/log_example.rb.log']
#     [BBFS LOG] [2012-06-08 10:06:14 +0300] [INFO] [log_example.rb:59] [this is
#       an info msg example]
#     [BBFS LOG] [2012-06-08 10:06:14 +0300] [DEBUG-1] [log_example.rb:70] [this debug1
#       msg will be logged since debug level is 1]

# 9. Extensibility
#    Log can easily be extended to flush the log messages to more consumers such as files,
#    remote computers, archives, mail etc. For more info regarding this pls contact Yaron (Author).

# 10. General limitations of Log that user should be informed
#     pls see sections 3 and 6.