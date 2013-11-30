#todo: stable state not working. after 2 cycles...

require 'algorithms'
require 'fileutils'
require 'log4r'
require 'params'
require 'content_server/server'
require 'file_monitoring/monitor_path'

module FileMonitoring
  # Manages file monitoring of number of file system locations
  class FileMonitoring

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

      # create root dirs of monitoring
      dir_stat_array = []
      conf_array.each { |elem|
        dir_stat = DirStat.new(File.expand_path(elem['path']))
        dir_stat_array.push([dir_stat, elem['stable_state']])
      }

      #Look over loaded content data if not empty
      # If file is under monitoring path - Add to DirStat tree as stable with path,size,mod_time read from file
      # If file is NOT under monitoring path - skip (not a valid usage)
      unless $local_content_data.empty?
        Log.info("Start build data base from loaded file")
        inst_count = 0
        $local_content_data.each_instance {
            |_, size, _, mod_time, _, path|
          # construct sub paths array from full file path:
          # Example:
          #   instance path = /dir1/dir2/file_name
          #   Sub path 1: /dir1
          #   Sub path 2: /dir1/dir2
          #   Sub path 3: /dir1/dir2/file_name
          # sub paths would create DirStat objs or FileStat(FileStat create using last sub path).
          split_path = path.split(File::SEPARATOR)
          sub_paths = (0..split_path.size-1).inject([]) { |paths, i|
            paths.push(File.join(*split_path.values_at(0..i)))
          }
          # sub_paths holds array => ["/dir1","/dir1/dir2","/dir1/dir2/file_name"]

          # Loop over monitor paths to start build tree under each
          dir_stat_array.each { | dir_stat|
            # check if monitor path is one of the sub paths and find it's sub path index
            # if index is found then it the monitor path
            # the next index indicates the next sub path to insert to the tree
            # the index will be raised at each recursive call down the tree
            sub_paths_index = sub_paths.index(dir_stat[0].path)
            next if sub_paths_index.nil?  # monitor path was not found. skip this instance.

            # monitor path was found. Add to tree
            # start the recursive call with next sub path index
            ::FileMonitoring.stable_state = dir_stat[1]
            inst_count += 1
            dir_stat[0].load_instance(sub_paths, sub_paths_index+1, size, mod_time)
            break
          }
        }
        Log.info("End build data base from loaded file. loaded instances:#{inst_count}")
        $last_content_data_id = $local_content_data.unique_id
      end

      # Directories states stored in the priority queue,
      # where the key (priority) is a time when it should be checked next time.
      # Priority queue means that all entries arranged by key (time to check) in increasing order.
      pq = Containers::PriorityQueue.new
      conf_array.each_with_index { |elem, index|
        priority = (Time.now + elem['scan_period']).to_i
        #Log.info("File monitoring started for: #{elem}")
        pq.push([priority, elem, dir_stat_array[index][0]], -priority)
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
      ::FileMonitoring::DirStat.set_log(@log4r)

      while true do
        # pull entry that should be checked next,
        # according to it's scan_period
        time, elem, dir_stat = pq.pop
        # time remains to wait before directory should be checked
        time_span = time - Time.now.to_i
        if (time_span > 0)
          sleep(time_span)
        end

        # Start monitor
        Log.info("Start monitor path:%s ", dir_stat.path)
        $testing_memory_log.info("Start monitor path:#{dir_stat.path}") if $testing_memory_active
        ::FileMonitoring.stable_state=elem['stable_state']
        dir_stat.monitor

        # Start index
        Log.info("Start index path:%s ", dir_stat.path)
        $testing_memory_log.info("Start index path:#{dir_stat.path}") if $testing_memory_active
        dir_stat.index

        # print number of indexed files
        Log.debug1("indexed file count:%s", $indexed_file_count)
        $testing_memory_log.info("indexed file count: #{$indexed_file_count}") if $testing_memory_active

        # remove non existing (not marked) files\dirs
        Log.info('Start remove non existing paths')
        $testing_memory_log.info('Start remove non existing paths') if $testing_memory_active
        dir_stat.removed_unmarked_paths
        Log.info('End monitor path and index')
        $testing_memory_log.info('End monitor path and index') if $testing_memory_active

        #flush content data if changed
        ContentServer.flush_content_data

        #Add back to queue
        priority = (Time.now + elem['scan_period']).to_i
        pq.push([priority, elem, dir_stat], -priority)
      end
    end
  end

end

