require 'params'
require 'process_monitoring/thread_safe_hash'


module ContentServer

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

  module_function :init_globals, :handle_program_termination
end