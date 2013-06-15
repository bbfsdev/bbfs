require 'algorithms'
require 'fileutils'
require 'log'
require 'params'

require 'file_monitoring/monitor_path'

module FileMonitoring
  # Manages file monitoring of number of file system locations


  class FileMonitoring


    def initialize
      @content_data_path = Params['local_content_data_path']
      @initial_content_data = ContentData::ContentData.new
      @initial_content_data.from_file(@content_data_path) if File.exists?(@content_data_path)

      @content_data_cache = Set.new
      @initial_content_data.each_instance(){
         |checksum,size,content_modification_time,instance_modification_time,server,device,file_path|

        # save files to cache
        @content_data_cache.add(file_path)

      }

    end


    # Set event queue used for communication between different proceses.
    # @param queue [Queue]
    def set_event_queue(queue)
      @event_queue = queue
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
        dir_stat = DirStat.new(File.expand_path(elem['path']), elem['stable_state'],@content_data_cache,FileStatEnum::NON_EXISTING)
        dir_stat.set_event_queue(@event_queue) if @event_queue
        Log.debug1 "File monitoring started for: #{elem}"
        pq.push([priority, elem, dir_stat], -priority)
      }

      log_path = Params['default_monitoring_log_path']

      Log.debug1 'File monitoring log: ' + log_path
      log_dir = File.dirname(log_path)
      FileUtils.mkdir_p(log_dir) unless File.exists?(log_dir)
      log = File.open(log_path, 'w')
      FileStat.set_log(log)

      while true do
        # pull entry that should be checked next,
        # according to it's scan_period
        time, conf, dir_stat = pq.pop

        # time remains to wait before directory should be checked
        time_span = time - Time.now.to_i
        if (time_span > 0)
          sleep(time_span)
        end
        dir_stat.monitor

        # push entry with new a next time it should be checked as a priority key
        priority = (Time.now + conf['scan_period']).to_i
        pq.push([priority, conf, dir_stat], -priority)
      end

      log.close
    end
  end

end

