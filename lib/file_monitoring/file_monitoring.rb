require 'algorithms'
require 'fileutils'
require 'log'
require 'params'
require 'yaml'

require 'file_monitoring/monitor_path'

module BBFS
  module FileMonitoring

    Params.string('default_log_path', File.expand_path('~/.bbfs/log/file_monitoring.log'),
                     'Default path for log file.')

    class FileMonitoring

      def set_config_path(config_path)
        @config_path = config_path
      end

      def set_event_queue(queue)
        @event_queue = queue
      end

      def monitor_files
        config_yml = YAML::load_file(@config_path)

        conf_array = config_yml['paths']

        pq = Containers::PriorityQueue.new
        conf_array.each { |elem|
          priority = (Time.now + elem['scan_period']).to_i
          dir_stat = DirStat.new(elem['path'], elem['stable_state'])
          dir_stat.set_event_queue(@event_queue) if @event_queue
          Log.info [priority, elem, dir_stat]
          pq.push([priority, elem, dir_stat], -priority)
        }

        log_path = Params['default_log_path']
        if config_yml.key?('log_path')
          log_path = File.expand_path(config_yml['log_path'])
        end

        Log.info 'Log path:' + log_path
        FileUtils.mkdir_p(File.dirname(log_path))
        log = File.open(log_path, 'w')
        FileStat.set_log(log)

        while true do
          time, conf, dir_stat = pq.pop
          #Log.info 'time:' + time.to_s()
          #Log.info 'now:' + Time.now.to_i.to_s()
          #Log.info conf

          time_span = time - Time.now.to_i
          if (time_span > 0)
            sleep(time_span)
          end
          dir_stat.monitor

          #Log.info conf['path']
          #Log.info conf['scan_period']
          priority = (Time.now + conf['scan_period']).to_i
          pq.push([priority, conf, dir_stat], -priority)
        end

        log.close
      end
    end

  end
end
