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
    $local_dynamic_content_data = nil  # will be init during execution
  end

  def handle_program_termination(exception)
    #Write exception message to console
    message = "\nInterrupt or Exit happened in server:'#{Params['service_name']}'.\n" +
      "Exception type:'#{exception.class}'.\n" +
      "Exception message:'#{exception.message}'.\n" +
      "Stopping process.\n" +
      "Backtrace:\n#{exception.backtrace.join("\n")}"
    puts(message)

    # force write content data to file
    if !$local_dynamic_content_data.nil?
      puts("\nForce writing local content data to #{Params['local_content_data_path']}.")
      $local_dynamic_content_data.last_content_data.to_file($tmp_content_data_file)
      File.rename($tmp_content_data_file, Params['local_content_data_path'])
    end

    #Write exception message to log and mail(if enabled)
    Log.error(message)
  end

  def monitor_general_process_vars
    mutex = Mutex.new
    while true do
      sleep(Params['process_vars_delay'])
      $process_vars.set('time', Time.now)
      #enable following line to see full list of object:count
      #obj_array = ''
      total_obj_count = 0
      string_count = 0
      mutex.synchronize do
        ObjectSpace.each_object(Class) {|obj|
          obj_count_per_class = ObjectSpace.each_object(obj).count
          #enable following line to see full list of object:count
          #obj_array = "#{obj_array} * #{obj.name}:#{obj_count_per_class}"
          total_obj_count = total_obj_count + obj_count_per_class
        }
        string_count = ObjectSpace.each_object(String).count
      end
      #enable following line to see full list of object:count
      #$process_vars.set('Live objs full', obj_array)
      $process_vars.set('Live objs total', total_obj_count)
      $process_vars.set('Live String size', string_count)
    end
  end

  module_function :init_globals, :handle_program_termination, :monitor_general_process_vars
end