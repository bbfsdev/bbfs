# Author: Yaron Dror (yaron.dror.bb@gmail.com)
# Run from bbfs> ruby -Ilib examples/log_example.rb

# 1. Log configuration through params:
#
# 1.1 Logging level param:
# Param name: log_debug_level
# value 0 = Info User friendly notifications.
# value 1 = Debug 1 -Info and debug 1 messages debug logic basic data.
# value 2 = Debug 2 -info, debug 1 and debug 2 messages - debug logic extensive data.
# value 3 = Debug 3 - info, debug 1 , debug 2 and debug 3 messages - debug logic extensive  data plus code wise data
#                                                                   (enter methods etc..).
# 
# 1.2 Logging streams parameters:
# File stream (enabled by default):
# Parameter: 'log_write_to_file'. Default is true. If false, than log is not written to log file.
# Parameter: 'log_file_name' - Path to file. Default path is: ~.bbfs/log/<executable name> <rotation counter>.log4
# Parameter: 'log_rotation_size'. Default is 1M. max log file size. When reaching this size, a new file is created for
#                                 rest of log. Note that rotation counter is added to the file name right before the '.'
# 
# Console stream (disabled by default):
# Parameter: 'log_write_to_console'. Default is false. If true, than log is written to console.
# 
# email stream (disabled by default. sent on system crush)
# Parameter: 'log_write_to_email'. Default is false. If true, than log is written to email on system crush..
# Parameter: 'from_email'. From who to send the mail.
# Parameter: 'from_email_password'. Mail password of sender.
# Parameter: 'to_email'. To who to send the mail.
# 
# 1.3 Flush to stream
# Flush each message parameter (enabled by default):
# Parameter: 'log_flush_each_message'. Default is true. If false than log messages will be written to file and console
#                                      each several messages.


# 2. require phase
# Add the following requires:
require 'params'
require 'log'


# 3. Log.init
# User *MUST* Call init or else an exception will be raised.
# This method MUST be called from the BBFS project executable init sequence.
# if user does not use the project init sequence in an executable, such as
# when user run tests, then user MUST call the init method from his own code.
Log.init

# 4. use one of the following log messages methods.
# Log.warning('this is a warning msg example')
# Log.error('this is a error msg example')
# Log.info('this is an info msg example')
# Log.info('I love to %s with %s', 'work', 'friends')  # first param is format with %s. Rest are args.
# Log.debug1('this is a debug1 msg example')  # depends on debug level (see ahead)
# Log.debug1('%s become %s', 2, 1)  # first param is format with %s. Rest are args.
# Log.debug2('this is a debug2 msg example')  # depends on debug level (see ahead)
# Log.debug3('this is a debug3 msg example')  # depends on debug level (see ahead)
# Notes: optional use of %s provided only for info, debug1, debug2, debug3. Not for warning nor for error.
#        ony %s can be used. %d or others can not be used.
Log.info('info msg %s', 'example')

# 5. log debug levels.
# Will Log.debug1 , Log.debug2 and Log.debug3 methods will actual log ?
# if Params.log_debug_level is set to 0 (default value) then no debug method will log.
# if Params.log_debug_level is set to 1 then only Log.debug1 will log.
# if Params.log_debug_level is set to 2 then Log.debug1 and Log.debug2 will log.
# if Params.log_debug_level is set to 3 or greater then all debug methods will log.
Log.debug1('this debug1 msg will not be logged since debug level default is 0')
Params['log_debug_level'] = 1 # set new debug level from now on.
Log.debug1('this debug1 msg will be logged since debug level is 1')
Log.debug2('this debug2 msg will not be logged since debug level is 1')


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
#
#     [BBFS LOG] [2012-06-08 10:06:14 +0300] [INFO] [log_example.rb:59] [this is
#       an info msg example]
#
#     [BBFS LOG] [2012-06-08 10:06:14 +0300] [DEBUG-1] [log_example.rb:70] [this debug1
#       msg will be logged since debug level is 1]

