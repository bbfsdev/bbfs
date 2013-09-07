require 'algorithms'
require 'fileutils'
require 'log4r'
require 'params'
require 'content_server/server'
require 'file_monitoring/monitor_path'

module FileMonitoring
  # Manages file monitoring of number of file system locations
  class FileMonitoring

    def initialize ()
      @content_data_cache = Set.new
      $local_content_data_lock.synchronize {
        $local_content_data.each_instance(){
            |_, _, _, _, _, file_path|
          # save files to cache
          Log.info("File in cache: #{file_path.clone}")
          @content_data_cache.add(file_path.clone)
        }
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
        dir_stat = DirStat.new(File.expand_path(elem['path']), elem['stable_state'], @content_data_cache, FileStatEnum::NON_EXISTING)
        dir_stat.set_event_queue(@event_queue) if @event_queue
        Log.debug1("File monitoring started for: #{elem}")
        pq.push([priority, elem, dir_stat], -priority)
      }

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
        time, conf, dir_stat = pq.pop
        # time remains to wait before directory should be checked
        time_span = time - Time.now.to_i
        if (time_span > 0)
          sleep(time_span)
        end

        unless $testing_memory_active
          Log.info("Start monitor path:#{dir_stat.path}")
          dir_stat.monitor_add_new
          Log.info('Start remove non existing paths')
          dir_stat.removed_unmarked_paths
          Log.info("indexed file count:#{$indexed_file_count}")
          puts("indexed file count=#{$indexed_file_count}")
          #Log.info('Start index')
          #dir_stat.index
          Log.info('End monitor path')

          Log.info('Start flush local content data to file.')
          $testing_memory_log.info('Start flush content data to file') if $testing_memory_active
          $local_content_data_lock.synchronize{
            local_content_data_unique_id = $local_content_data.unique_id
            #if (local_content_data_unique_id != last_content_data_id)
            last_content_data_id = local_content_data_unique_id
            $local_content_data.to_file($tmp_content_data_file)
            Log.info('End flush local content data to file.')
            #else
            #Log.info('no need to flush. content data has not changed')
            #end
          }
          File.rename($tmp_content_data_file, Params['local_content_data_path']) if written_to_file
          $testing_memory_log.info("End flush content data to file") if $testing_memory_active
        else
          $testing_memory_log.info("Start monitor")
          dir_stat.monitor_add_new
          $testing_memory_log.info("Start remove unmarked paths")
          dir_stat.removed_unmarked_paths
          #$testing_memory_log.info("Start Index")
          #dir_stat.index
          $testing_memory_log.info("End Index & Monitor")

          Log.info('Start flush local content data to file.')
          $testing_memory_log.info('Start flush content data to file') if $testing_memory_active
          $local_content_data_lock.synchronize{
            local_content_data_unique_id = $local_content_data.unique_id
            #if (local_content_data_unique_id != last_content_data_id)
            last_content_data_id = local_content_data_unique_id
            $local_content_data.to_file($tmp_content_data_file)
            Log.info('End flush local content data to file.')
            #else
            #Log.info('no need to flush. content data has not changed')
            #end
          }
          File.rename($tmp_content_data_file, Params['local_content_data_path']) if written_to_file
          $testing_memory_log.info("End flush content data to file") if $testing_memory_active
        end
        priority = (Time.now + conf['scan_period']).to_i
        pq.push([priority, conf, dir_stat], -priority)
      end
    end
  end

end

