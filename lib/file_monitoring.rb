require 'file_monitoring/file_monitoring'

# TODO add description
module FileMonitoring
  # The main method. Loops on all paths each time span and monitors them.
  def monitor_files
    fm = FileMonitoring.new
    fm.monitor_files
  end
end
