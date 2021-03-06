require 'log'
require 'params'
require 'process_monitoring/thread_safe_hash'


module ContentServer

  # Flags combined for content and backup server.
  Params.string('local_server_name', `hostname`.strip, 'local server name')
  Params.path('tmp_path', '~/.bbfs/tmp', 'tmp path for temporary files')

  # ContentData flush parameters
  Params.integer('data_flush_delay', 3000, 'Number of seconds to delay content data file flush to disk.')
  Params.integer('diff_data_flush_delay', 300, 'Number of seconds to delay content data file flush to disk.')

  # Monitoring
  Params.boolean('enable_monitoring', false, 'Whether to enable process monitoring or not.')
  Params.integer('process_vars_delay', 3, 'pulling time of variables')

  # Handling thread exceptions.
  Params.boolean('abort_on_exception', true, 'Any exception in any thread will abort the run.')


  #using module method fot globals initialization due to the use of 'Params'.
  def init_globals
    $process_vars = ThreadSafeHash::ThreadSafeHashMonitored.new(Params['enable_monitoring'])
    $tmp_content_data_file = nil  # will be init during execution
    $testing_memory_active = false
    $testing_memory_log = nil
    $indexed_file_count = 0
    $local_content_data = nil
    $local_content_data_lock = nil
    $remote_content_data_lock = nil
    $remote_content_data = nil
    $last_content_data_id = nil
  end

  def handle_program_termination(exception)
    #Write exception message to console
    message = "\nInterrupt or Exit happened in server:''.\n" +
      "Exception type:'#{exception.class}'.\n" +
      "Exception message:'#{exception.message}'.\n" +
      "Stopping process.\n" +
      "Backtrace:\n#{exception.backtrace.join("\n")}"
    puts(message)

    # Block force write to file resolving Issue 217 https://github.com/bbfsdev/bbfs/issues/217
    # force write content data to file
    #if $local_content_data
     # puts("\nForce writing local content data to #{Params['local_content_data_path']}.")
      #$local_content_data.to_file($tmp_content_data_file)
      #File.rename($tmp_content_data_file, Params['local_content_data_path'])
    #end

    #Write exception message to log and mail(if enabled)
    Log.error(message)
  end

  def monitor_general_process_vars
    objects_counters = {}
    objects_counters["Time"] = Time.now.to_i
    while true do
      current_objects_counters = {}
      sleep(Params['process_vars_delay'])
      time = Time.now
      $process_vars.set('time', time)
      current_objects_counters['Time'] = time.to_i
      count = ObjectSpace.each_object(String).count
      $process_vars.set('String count', count)
      current_objects_counters['String'] = count
      count = ObjectSpace.each_object(ContentData::ContentData).count
      $process_vars.set('ContentData count', count)
      current_objects_counters['ContentData'] = count
      dir_count = ObjectSpace.each_object(FileMonitoring::DirStat).count
      $process_vars.set('DirStat count', dir_count)
      current_objects_counters['DirStat'] = dir_count
      file_count = ObjectSpace.each_object(FileMonitoring::FileStat).count
      $process_vars.set('FileStat count', file_count-dir_count)
      current_objects_counters['FileStat'] = file_count

      # Generate report and update global counters
      report = ""
      current_objects_counters.each_key { |type|
        objects_counters[type] = 0 unless objects_counters[type]
        diff =  current_objects_counters[type] - objects_counters[type]
        report += "Type:#{type} raised in:#{diff}   \n"
        objects_counters[type] = current_objects_counters[type]
      }
      Log.info("MEM REPORT:\n%s\n", report)
    end
  end

  def flush_content_data(is_full_flush = false)
    Log.debug1('Start flush local content data to file.')
    $testing_memory_log.info('Start flush content data to file') if $testing_memory_active

    $local_content_data_lock.synchronize {
      local_content_data_unique_id = $local_content_data.unique_id
      if (local_content_data_unique_id != $last_content_data_id)
        $last_content_data_id = local_content_data_unique_id
        #$local_content_data.to_file($tmp_content_data_file)
        #File.rename($tmp_content_data_file, Params['local_content_data_path'])
        ContentDataDb.save($local_content_data, is_full_flush)
        Log.debug1('End flush local content data to file.')
        $testing_memory_log.info('End flush content data to file') if $testing_memory_active
      else
        Log.debug1('no need to flush. content data has not changed')
        $testing_memory_log.info('no need to flush. content data has not changed') if $testing_memory_active
      end
    }
  end

  def raise_monitoring_paths_error(expected_paths_size, name, structure)
    expected_paths_size.times { |index|
      paths_string = <<EOF
#{paths_string}
  - path: 'some_path_#{index+1}' # Directory path to monitor.\n"
    scan_period: 200 # Number of seconds before initiating another directory scan.\n"
    stable_state: 2 # Number of scan times for a file to be unchanged before his state becomes stable.\n"
EOF
    }
    msg = <<EOF
parameter:#{name} bad format
Parsed structure:#{name}:#{structure}
Format example:
#{name}:
#{paths_string}
EOF
    raise(msg)
  end

  # check format of monitoring paths parameters to be array of hashes of 3 items
  # input - name - name of the user input parameter
  # input - expected_paths_size - the expected number of paths.
  #               For backup_destination_dir number of paths is 1
  #               number of paths=0 indicates any number of paths (used for monitoring_path)
  def check_monitoring_path_structure(name, expected_paths_size)
    structure = Params[name]
    if structure.kind_of?(Array)
      if (0 != expected_paths_size) and (expected_paths_size != structure.size)
        ContentServer.raise_monitoring_paths_error(expected_paths_size, name, structure)
      end
      structure.each { |path_hash|
        if path_hash.kind_of?(Hash)
          if 3 != path_hash.size
            ContentServer.raise_monitoring_paths_error(expected_paths_size, name, structure)
          end
        else
          ContentServer.raise_monitoring_paths_error(expected_paths_size, name, structure)
        end
      }
    else
      ContentServer.raise_monitoring_paths_error(expected_paths_size, name, structure)
    end
  end


  # create general tmp dir
  def get_tmp_file_name(file_path, tmp_base_name)
    tmp_file_name = tmp_base_name
    if file_path.match(/\.gz$/)
      tmp_file_name = tmp_base_name + '.gz'
    end
    tmp_file_name
  end

  module_function :init_globals, :handle_program_termination, :monitor_general_process_vars, :flush_content_data, \
                  :check_monitoring_path_structure, :get_tmp_file_name
end
