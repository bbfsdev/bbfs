require 'algorithms'
require 'fileutils'
require 'log4r'
require 'params'

require 'file_monitoring/monitor_path'

module FileMonitoring
  # Manages file monitoring of number of file system locations
  class FileMonitoring

    def initialize (initial_content_data=nil)
      @content_data_cache = Set.new
      return if initial_content_data.nil?
      initial_content_data.each_instance(){
          |checksum, size, content_modification_time,
           instance_modification_time, server, file_path|
        # save files to cache
        Log.info("File in cache: #{file_path}")
        @content_data_cache.add(file_path)
      }
    end


    # Set event queue used for communication between different proceses.
    # @param queue [Queue]
    def set_event_queue(queue)
      @event_queue = queue
    end

    def set_monitor_dirs_container(monitor_dirs)
      @monitor_dirs = monitor_dirs
    end

    # The main method. Loops on all paths, each time span and monitors them.
    #
    # =Algorithm:
    # There is a loop that performs at every iteration:
    #   1.Pull entry with a minimal time of check from queue
    #   2.Recursively check path taken from entry for changes
    #     a.Notify subscribed processes on changes
    #   3.Push entry to the queue with new time of next check
    #
    # This methods controlled by <tt>monitoring_paths</tt> configuration parameter,
    # that provides path and file monitoring configuration data
    def monitor_files
      conf_array = Params['monitoring_paths']
      # Directories states stored in the priority queue,
      # where the key (priority) is a time when it should be checked next time.
      # Priority queue means that all entries arranged by key (time to check) in increasing order.
      pq = Containers::PriorityQueue.new
      conf_array.each { |elem|
        priority = (Time.now + elem['scan_period']).to_i
        dir_stat = DirStat.new(nil, File.expand_path(elem['path']), elem['stable_state'], @content_data_cache, FileStatEnum::NON_EXISTING)
        dir_stat.set_event_queue(@event_queue) if @event_queue
        Log.debug1 "File monitoring started for: #{elem}"
        pq.push([1, priority, elem, dir_stat], -priority)
        @monitor_dirs.push(dir_stat)
      }
      priority = (Time.now + Params['data_flush_delay']).to_i
      pq.push([2, priority], -priority)

      #init log4r
      monitoring_log_path = Params['default_monitoring_log_path']
      Log.debug1 'File monitoring log: ' + Params['default_monitoring_log_path']
      monitoring_log_dir = File.dirname(monitoring_log_path)
      FileUtils.mkdir_p(monitoring_log_dir) unless File.exists?(monitoring_log_dir)

      @log4r = Log4r::Logger.new 'BBFS monitoring log'
      @log4r.trace = true
      formatter = Log4r::PatternFormatter.new(:pattern => "[%d] [%m]")
      #file setup
      file_config = {
          "filename" => Params['default_monitoring_log_path'],
          "maxsize" => Params['log_rotation_size'],
          "trunc" => true
      }
      file_outputter = Log4r::RollingFileOutputter.new("monitor_log", file_config)
      file_outputter.level = Log4r::INFO
      file_outputter.formatter = formatter
      @log4r.outputters << file_outputter
      FileStat.set_log(@log4r)

      while true do
        # pull entry that should be checked next,
        # according to it's scan_period
        type, time, conf, dir_stat = pq.pop
        # time remains to wait before directory should be checked
        time_span = time - Time.now.to_i
        if (time_span > 0)
          sleep(time_span)
        end
        if 1 == type
          dir_stat.monitor
          # push entry with new a next time it should be checked as a priority key
          priority = (Time.now + conf['scan_period']).to_i
          pq.push([1, priority, conf, dir_stat], -priority)
        else
          Log.info "Start Writing local content data to #{Params['local_content_data_path']}."
          content_data = ContentData::ContentData.new
          @monitor_dirs.each { |dir| dir.add_to_content_data(content_data)}
          #$local_dynamic_content_data.last_content_data.to_file($tmp_content_data_file)
          content_data.to_file($tmp_content_data_file)
          #content_data.clear
          File.rename($tmp_content_data_file, Params['local_content_data_path'])
          content_data = ContentData::ContentData.new  # for some reason this line enables GC to release the mem. Nil does not.
          Log.info "End Writing local local content data"
          priority = (Time.now + Params['data_flush_delay']).to_i
          pq.push([2, priority], -priority)
        end
      end

      log.close
    end
  end

end

