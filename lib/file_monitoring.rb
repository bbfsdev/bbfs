require_relative 'file_monitoring/monitor_path'
require 'algorithms'
require 'fileutils'
require 'yaml'

# TODO add description
module FileMonitoring
  VERSION = "0.0.4"

  string_parameter("config_path","~/.bbfs/etc/file_monitoring.yml",
                   "Configuration file for monitoring.")

  # The main method. Loops on all paths each time span and monitors them.
  def monitor_files
    fm = FileMonitoring.new
    fm.monitor_files
  end
end
