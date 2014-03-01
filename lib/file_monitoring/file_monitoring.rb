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
      
     conf_array = Params['monitoring_paths']

      # create root dirs of monitoring
      dir_stat_array = []
      conf_array.each { |elem|
        dir_stat = DirStat.new(File.expand_path(elem['path']))
        dir_stat_array.push([dir_stat, elem['stable_state']])
      }

      file_attr_to_checksum = {}  # This structure is used to optimize indexing when user specifies a directory was moved.

      #Look over loaded content data if not empty
      unless $local_content_data.empty?
        Log.info("Start build data base from loaded file. This could take several minutes")
        inst_count = 0
        # If file is under monitoring path - Add to DirStat tree as stable with path,size,mod_time read from file
        # If file is NOT under monitoring path - skip (not a valid usage)
        $local_content_data.each_instance {
            |checksum, size, _, mod_time, _, path, index_time|

          if Params['manual_file_changes']
            file_attr_key = [File.basename(path), size, mod_time]
            ident_file_info = file_attr_to_checksum[file_attr_key]
            unless ident_file_info
              #  Add file checksum to map
              file_attr_to_checksum[file_attr_key] = IdentFileInfo.new(checksum, index_time)
            else
              # File already in map. Need to mark as not unique
              ident_file_info.unique = false  # file will be skipped if found at new location
            end
          end
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

        # If symlink file is under monitoring path - Add to DirStat tree
        # If file is NOT under monitoring path - skip (not a valid usage)
        symlink_count = 0
        $local_content_data.each_symlink {
            |_, symlink_path, symlink_target|

          # construct sub paths array from symlink path:
          # Example:
          #   symlink path = /dir1/dir2/file_name
          #   Sub path 1: /dir1
          #   Sub path 2: /dir1/dir2
          #   Sub path 3: /dir1/dir2/file_name
          # sub paths should match the paths of DirStat objs in the tree to reach the symlink location in Tree.
          split_path = symlink_path.split(File::SEPARATOR)
          sub_paths = (0..split_path.size-1).inject([]) { |paths, i|
            paths.push(File.join(*split_path.values_at(0..i)))
          }
          # sub_paths holds array => ["/dir1","/dir1/dir2","/dir1/dir2/file_name"]

          # Loop over monitor paths to start enter tree
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
            symlink_count += 1
            dir_stat[0].load_symlink(sub_paths, sub_paths_index+1, symlink_path, symlink_target)
            break
          }
        }
        Log.info("End build data base from loaded file. loaded instances:#{inst_count}  loaded symlinks:#{symlink_count}")
        $last_content_data_id = $local_content_data.unique_id

        if Params['manual_file_changes']
          # -------------------------- MANUAL MODE
          # ------------ LOOP DIRS
          dir_stat_array.each { | dir_stat|
            log_msg = "In Manual mode. Start monitor path:#{dir_stat[0].path}. moved or copied files (same name, size and time " +
                'modification) will use the checksum of the original files and be updated in content data file'
            Log.info(log_msg)
            $testing_memory_log.info(log_msg) if $testing_memory_active

            # ------- MONITOR
            dir_stat[0].monitor(file_attr_to_checksum)

            # ------- REMOVE PATHS
            # remove non existing (not marked) files\dirs
            log_msg = 'Start remove non existing paths'
            Log.info(log_msg)
            $testing_memory_log.info(log_msg) if $testing_memory_active
            dir_stat[0].removed_unmarked_paths
            log_msg = 'End monitor path and index'
            Log.info(log_msg)
            $testing_memory_log.info(log_msg) if $testing_memory_active
          }

          # ------ WRITE CONTENT DATA
          ContentServer.flush_content_data
          raise("Finished manual changes and update file:#{Params['local_content_data_path']}. Exit application\n")
        end
      else
        if Params['manual_file_changes']
          Log.info('Feature: manual_file_changes is ON. But No previous content data found. ' +
                   'No change is required. Existing application')
          raise('Feature: manual_file_changes is ON. But No previous content data found at ' +
                   "file:#{Params['local_content_data_path']}. No change is required. Existing application\n")
        end
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

        # remove non existing (not marked) files\dirs
        Log.info('Start remove non existing paths')
        $testing_memory_log.info('Start remove non existing paths') if $testing_memory_active
        dir_stat.removed_unmarked_paths
        Log.info('End monitor path and index')
        $testing_memory_log.info('End monitor path and index') if $testing_memory_active

        # Start index
        Log.info("Start index path:%s ", dir_stat.path)
        $testing_memory_log.info("Start index path:#{dir_stat.path}") if $testing_memory_active
        dir_stat.index

        # print number of indexed files
        Log.debug1("indexed file count:%s", $indexed_file_count)
        $testing_memory_log.info("indexed file count: #{$indexed_file_count}") if $testing_memory_active

        #flush content data if changed
        ContentServer.flush_content_data

        #Add back to queue
        priority = (Time.now + elem['scan_period']).to_i
        pq.push([priority, elem, dir_stat], -priority)
      end
    end
  end

end

