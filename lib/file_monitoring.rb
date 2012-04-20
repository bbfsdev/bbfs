require 'params'

require 'file_monitoring/file_monitoring'

# TODO add description
module BBFS
  module FileMonitoring
    Params.parameter("config_path","~/.bbfs/etc/file_monitoring.yml",
                     "Configuration file for monitoring.")

    # The main method. Loops on all paths each time span and monitors them.
    def monitor_files
      fm = FileMonitoring.new
      fm.monitor_files
    end
  end
end
