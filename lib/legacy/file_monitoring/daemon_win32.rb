require 'win32/daemon'
include Win32
require 'rubygems'

begin
require "./file_monitoring/file_monitoring.rb"

conf_file_path = (ARGV.length > 0 ? "#{ARGV[0]}" : '~/.bbfs/etc/file_monitoring.yml')
conf_file_path = File.expand_path(conf_file_path)

CONFIG_FILE_PATH = "#{conf_file_path}"

  class Daemon
    def service_main
      while running?
        monitor_files(CONFIG_FILE_PATH)
      end
    end

    def service_stop
      exit!
    end
  end

  Daemon.mainloop

rescue Exception => err
  raise
end