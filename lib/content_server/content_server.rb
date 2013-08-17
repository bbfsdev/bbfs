require 'fileutils'
require 'set'
require 'thread'

require 'content_data'
require 'content_server/content_receiver'
require 'content_server/queue_indexer'
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
      Log.info("Initializing monitoring of process params on port:#{Params['process_monitoring_web_port']}")
      $process_vars.set('server_name', 'content_server')
    end

    # # # # # # # # # # # #
    # Initialize/Start monitoring
    Log.info('Start monitoring following directories:')
    Params['monitoring_paths'].each {|path|
      Log.info("  Path:'#{path['path']}'")
    }

    # initial global local content data object
    $local_content_data_lock = Mutex.new
    $local_content_data = ContentData::ContentData.new

    # Read here for initial content data that exist from previous system run
    content_data_path = Params['local_content_data_path']
    last_content_data_id = nil
    if File.exists?(content_data_path) and !File.directory?(content_data_path)
      Log.info("reading initial content data that exist from previous system run from file:#{content_data_path}")
      $local_content_data.from_file(content_data_path)
      last_content_data_id = $local_content_data.unique_id
    else
      if File.directory?(content_data_path)
        raise("Param:'local_content_data_path':'#{Params['local_content_data_path']}'cannot be a directory name")
      end
      # create directory if needed
      dir = File.dirname(Params['local_content_data_path'])
      FileUtils.mkdir_p(dir) unless File.exists?(dir)
    end

    Log.info("Init monitoring")
    monitoring_events = Queue.new
    fm = FileMonitoring::FileMonitoring.new()
    fm.set_event_queue(monitoring_events)
    # Start monitoring and writing changes to queue
    all_threads << Thread.new do
      fm.monitor_files
    end

    # # # # # # # # # # # # # #
    # Initialize/Start local indexer
    Log.debug1('Start indexer')
    queue_indexer = QueueIndexer.new(monitoring_events)
    # Start indexing on demand and write changes to queue
    all_threads << queue_indexer.run

    # # # # # # # # # # # # # # # # # # # # # # # #
    # thread: Start dump local content data to file
    Log.debug1('Init thread: flush local content data to file')
    all_threads << Thread.new do
      FileUtils.mkdir_p(Params['tmp_path']) unless File.directory?(Params['tmp_path'])
      loop{
        sleep(Params['data_flush_delay'])
        Log.info('Start flush local content data to file.')
        $testing_memory_log.info('Start flush content data to file') if $testing_memory_active
        written_to_file = false
        $local_content_data_lock.synchronize{
          local_content_data_unique_id = $local_content_data.unique_id
          if (local_content_data_unique_id != last_content_data_id)
            last_content_data_id = local_content_data_unique_id
            $local_content_data.to_file($tmp_content_data_file)
            written_to_file = true
          else
            Log.info('no need to flush. content data has not changed')
          end
        }
        File.rename($tmp_content_data_file, Params['local_content_data_path']) if written_to_file
        $testing_memory_log.info("End flush content data to file") if $testing_memory_active
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


