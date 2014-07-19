require 'fileutils'
require 'set'
require 'thread'

require 'content_data'
require 'content_server/content_receiver'
require 'content_server/queue_copy'
require 'content_server/remote_content'
require 'file_indexing'
require 'file_monitoring'
require 'content_server/server'
require 'log'
require 'networking/tcp'
require 'params'
require 'process_monitoring/monitoring_info'

# Content server. Monitors files, index local files, listen to backup server content,
# copy changes and new files to backup server.
module ContentServer
  # Content server specific flags.
  Params.integer('local_files_port', 4444, 'Remote port in backup server to copy files')
  Params.integer('local_content_data_port', 3333, 'Listen to incoming content data requests')

  def run_content_server
    Log.info('Content server start')
    all_threads = []

    # create general tmp dir
    FileUtils.mkdir_p(Params['tmp_path']) unless File.directory?(Params['tmp_path'])
    # init tmp content data file
    $tmp_content_data_file = File.join(Params['tmp_path'], 'content.data')

    if Params['enable_monitoring']
      Log.info("Initializing monitoring of process params on port:%s", Params['process_monitoring_web_port'])
      $process_vars.set('server_name', 'content_server')
    end

    # check format of monitoring_paths param to be array of hashes of 3 items
    monitoring_paths_struct_ok = true
    if Params['monitoring_paths'].kind_of?(Array)
      Params['monitoring_paths'].each { |path|
        if path.kind_of?(Hash)
          if 3 != path.size
            monitoring_paths_struct_ok = false
          end
        else
          monitoring_paths_struct_ok = false
        end
      }
    else
      monitoring_paths_struct_ok = false
    end

    if not monitoring_paths_struct_ok
      msg  = "monitoring_paths parameter bad format\n"
      msg += "Parsed structure:\n#{Params['monitoring_paths']}\nFormat example:\nmonitoring_paths:\n"
      msg += "  - path: 'some_path' # Directory path to monitor.\n"
      msg += "    scan_period: 200 # Number of seconds before initiating another directory scan.\n"
      msg += "    stable_state: 2 # Number of scan times for a file to be unchanged before his state becomes stable.\n"
      msg += "  - path: 'some_other_path' # Directory path to monitor.\n"
      msg += "    scan_period: 300 # Number of seconds before initiating another directory scan.\n"
      msg += "    stable_state: 4 # Number of scan times for a file to be unchanged before his state becomes stable."
      raise(msg)
    end

    # # # # # # # # # # # #
    # Initialize/Start monitoring
    Log.info('Start monitoring following directories:')
    Params['monitoring_paths'].each {|path|
      Log.info("  Path:'%s'", path['path'])
    }

    # initial global local content data object
    $local_content_data_lock = Mutex.new
    $local_content_data = ContentData::ContentData.new
    $last_content_data_id = $local_content_data.unique_id

    # Read here for initial content data that exist from previous system run
    content_data_path = Params['local_content_data_path']
    if File.exists?(content_data_path) and !File.directory?(content_data_path)
      Log.info("reading initial content data that exist from previous system run from file:%s", content_data_path)
      $local_content_data.from_file(content_data_path)
      $last_content_data_id = $local_content_data.unique_id
    else
      if File.directory?(content_data_path)
        raise("Param:'local_content_data_path':'%s'cannot be a directory name", Params['local_content_data_path'])
      end
      # create directory if needed
      dir = File.dirname(Params['local_content_data_path'])
      FileUtils.mkdir_p(dir) unless File.exists?(dir)
    end

    Log.info('Init monitoring')
    fm = FileMonitoring::FileMonitoring.new()
    # Start monitoring and writing changes to queue
    all_threads << Thread.new do
      fm.monitor_files
    end

    # # # # # # # # # # # # # # # # # # # # # # # #
    # thread: Start dump local content data to file
    Log.debug1('Init thread: flush local content data to file')
    all_threads << Thread.new do
      FileUtils.mkdir_p(Params['tmp_path']) unless File.directory?(Params['tmp_path'])
      loop{
        sleep(Params['data_flush_delay'])
        ContentServer.flush_content_data
      }
    end

    # initialize remote connection
    remote_content_client = RemoteContentServer.new(Params['local_content_data_port'])
    all_threads << remote_content_client.tcp_thread

    # # # # # # # # # # # # # # # #
    # Start copying files on demand
    Log.debug1('Start copy data on demand')
    copy_files_events = Queue.new  # TODO(kolman): Remove this initialization and merge to FileCopyServer.
    copy_server = FileCopyServer.new(copy_files_events, Params['local_files_port'])
    all_threads.concat(copy_server.run())

    # # # # # # # # # # # # # # # # # # # # # # # #
    # Start process vars thread
    if Params['enable_monitoring']
      monitoring_info = MonitoringInfo::MonitoringInfo.new()
      all_threads << Thread.new do
        ContentServer.monitor_general_process_vars
      end
    end
    # Finalize server threads.
    all_threads.each { |t| t.abort_on_exception = true }
    all_threads.each { |t| t.join }
    # Should never reach this line.
  end
  module_function :run_content_server

end # module ContentServer


