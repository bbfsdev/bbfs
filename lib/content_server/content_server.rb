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
    # init tmp content data file. This will be used to create the file before override existing file.
    $tmp_content_data_file = File.join(Params['tmp_path'], \
      ContentServer.get_tmp_file_name(Params['local_content_data_path'], 'content.data'))

    tmp_file_name = 'content.data'
    if Params['local_content_data_path'].match(/\.gz$/)
      tmp_file_name = 'content.data.gz'
    end
    $tmp_content_data_file = File.join(Params['tmp_path'], tmp_file_name)

    if Params['enable_monitoring']
      Log.info("Initializing monitoring of process params on port:%s", Params['process_monitoring_web_port'])
      $process_vars.set('server_name', 'content_server')
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


