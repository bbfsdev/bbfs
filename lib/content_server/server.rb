require 'log'
require 'params'
require 'process_monitoring/thread_safe_hash'


module ContentServer

  # Flags combined for content and backup server.
  Params.string('local_server_name', `hostname`.strip, 'local server name')
  Params.path('tmp_path', '~/.bbfs/tmp', 'tmp path for temporary files')

  Params.path('local_content_data_path', '', 'ContentData file path.')

  # Monitoring
  Params.boolean('enable_monitoring', false, 'Whether to enable process monitoring or not.')
  Params.integer('process_vars_delay', 3, 'pulling time of variables')

  # Handling thread exceptions.
  Params.boolean('abort_on_exception', true, 'Any exception in any thread will abort the run.')

  Params.integer('data_flush_delay', 300, 'Number of seconds to delay content data file flush to disk.')

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
  end

  def handle_program_termination(exception)
    #Write exception message to console
    message = "\nInterrupt or Exit happened in server:''.\n" +
      "Exception type:'#{exception.class}'.\n" +
      "Exception message:'#{exception.message}'.\n" +
      "Stopping process.\n" +
      "Backtrace:\n#{exception.backtrace.join("\n")}"
    puts(message)

    # force write content data to file
    if $local_content_data
      puts("\nForce writing local content data to #{Params['local_content_data_path']}.")
      $local_content_data.to_file($tmp_content_data_file)
      File.rename($tmp_content_data_file, Params['local_content_data_path'])
    end

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
      current_objects_counters['FileStat'] = file_count-dir_count

      # Generate report and update global counters
      report = ""
      current_objects_counters.each_key { |type|
        objects_counters[type] = 0 unless objects_counters[type]
        diff =  current_objects_counters[type] - objects_counters[type]
        report += "Type:#{type} raised in:#{diff}   \n"
        objects_counters[type] = current_objects_counters[type]
      }
      Log.info("MEM REPORT at:#{time}:\n#{report}\n")
    end
  end

  module_function :init_globals, :handle_program_termination, :monitor_general_process_vars
end