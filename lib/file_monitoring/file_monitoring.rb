require 'algorithms'
require 'fileutils'
require 'yaml'

require_relative 'monitor_path'

module BBFS
  module FileMonitoring

    class FileMonitoring

      def set_config_path(config_path)
        @config_path = config_path
      end

      def set_event_queue(queue)
        @event_queue = queue
      end

      def monitor_files
        config_yml = YAML::load_file(@config_path)

        conf_array = config_yml["paths"]

        pq = Containers::PriorityQueue.new
        conf_array.each { |elem|
          priority = (Time.now + elem["scan_period"]).to_i
          dir_stat = DirStat.new(elem["path"], elem["stable_state"])
          dir_stat.set_event_queue(@event_queue) if @event_queue
          pq.push([priority, elem, dir_stat], -priority)
        }

        log_path = File.expand_path("~/.bbfs/log/file_monitoring.log")
        if config_yml.key?("log_path")
          log_path = File.expand_path(config_yml["log_path"])
        end

        puts "Log path:" + log_path
        FileUtils.mkdir_p(File.dirname(log_path))
        log = File.open(log_path, 'w')
        FileStat.set_log(log)

        while true do
          time, conf, dir_stat = pq.pop
          #puts "time:" + time.to_s()
          #puts "now:" + Time.now.to_i.to_s()
          #puts conf

          time_span = time - Time.now.to_i
          if (time_span > 0)
            sleep(time_span)
          end

          dir_stat.monitor

          #puts conf["path"]
          #puts conf["scan_period"]
          priority = (Time.now + conf["scan_period"]).to_i
          pq.push([priority, conf, dir_stat], -priority)
        end

        log.close
      end
    end

  end
end
