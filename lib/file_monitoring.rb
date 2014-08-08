require 'file_monitoring/file_monitoring'

# Daemon for monitoring directories for changes.
# Paths are checked for changes per user-defined period of time.
#
# Directory defined changed when:
# 1. Directory structure changed, i.e. sub-directories or files were added/removed
# 2. One of the files located in the directory or one of its sub-directories was changed
# 3. One of sub-directories changed (see 1. and 2. above)
#
# File monitoring controled by following configuration parameters:
# * <tt>default_monitoring_log_path</tt> - holds path of file monitoring log.
#   This log containd track of changes found during monitoring
# * <tt>monitoring_paths</tt> - path and file monitoring configuration data
#   regarding these paths.

module FileMonitoring
  Params.path('default_monitoring_log_path', '~/.bbfs/log/file_monitoring.log',
              'Default path for file monitoring log file. ' \
              'This log containd track of changes found during monitoring')
  puts "Yaron monitoring_paths 1"
  Params.complex('monitoring_paths', [], 'Array of Hashes with 3 fields: ' \
                 'path, scan_period and stable_state.')
  Params.boolean('manual_file_changes', false, 'true, indicates to application that a set of files were ' \
    ' moved/copied we we should not index them but rather copy their hashes from contents there were copied from')

  # @see FileMonitoring#monitor_files
  def monitor_files
    fm = FileMonitoring.new
    fm.monitor_files
  end
end
