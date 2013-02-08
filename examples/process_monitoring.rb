# Author: Kolman Vornovitsky (kolmanv@gmail.com)
# This files gives example of how to use process monitoring module.

require 'process_monitoring'

# What are we monitoring?
# 1) Logs
require 'log'

# 2) Parameters
require 'params'

Params.init ARGV
Params['log_write_to_console'] = true

Log.init

# 3) Custom hash of variables
variables = ThreadSafeHash::ThreadSafeHash.new
variables.set('some_variable', 'this is an example :)')

# If you want this example to send emails, set Params['enable_monitoring_emails']=true
# Before you do that, check the emails parameters at 'monitoring.rb'

# Lets initialize the monitoring task.
# The command below generates new thread which can be retrieved by 'mon.thread'.
# The command below starts checking periodically for errors in logs and/or send status update emails
# to Params['monitoring_email']
mon = Monitoring::Monitoring.new(variables)

# Lets initialize the monitoring variables HTTP interface (look at localhost:5555).
# The command below generates new thread which can be retrieved by 'mon_http.thread'.
mon_http = MonitoringInfo::MonitoringInfo.new(variables)

# Lets connect the monitoring to the log.
Log.add_consumer(mon)

# Let there is a running process
number = 1
loop do
  number += 1
  variables.set('number', number)
  Log.info "number: #{number}"
  remote_mon_info = MonitoringInfo::MonitoringInfo.get_remote_monitoring_info('localhost', 5555)
  Log.info "Remote monitoring info (localhost:5555): #{remote_mon_info}" if remote_mon_info
  sleep(3)
end