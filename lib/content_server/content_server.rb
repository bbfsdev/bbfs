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
    monitoring_events = Queue.new

    # Read here for initial content data that exist from previous system run
    #initial_content_data = ContentData::ContentData.new
    #content_data_path = Params['local_content_data_path']
    #if File.exists?(content_data_path) and !File.directory?(content_data_path)
    #  Log.info("reading initial content data that exist from previous system run from file:#{content_data_path}")
    #  initial_content_data.from_file(content_data_path)
    #else
    #  if File.directory?(content_data_path)
    #    raise("Param:'local_content_data_path':'#{Params['local_content_data_path']}'cannot be a directory name")
    #  end
      # create directory if needed
      dir = File.dirname(Params['local_content_data_path'])
      FileUtils.mkdir_p(dir) unless File.exists?(dir)
    #end

    # Create monitor dirs object to be used to generate content data on demand
    $monitor_dirs = []

    fm = FileMonitoring::FileMonitoring.new()
    fm.set_event_queue(monitoring_events)
    fm.set_monitor_dirs_container($monitor_dirs)
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

    remote_content_client = RemoteContentServer.new($monitor_dirs,
                                                    Params['local_content_data_port'])
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


