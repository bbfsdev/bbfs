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
    initial_content_data = ContentData::ContentData.new
    content_data_path = Params['local_content_data_path']
    if File.exists?(content_data_path) and !File.directory?(content_data_path)
      Log.info("reading initial content data that exist from previous system run from file:#{content_data_path}")
      initial_content_data.from_file(content_data_path)
    else
      raise("Param:'local_content_data_path':'#{content_data_path}' is a file name which does not exist" +
                " or a directory name")
    end

    # Update local dynamic content with existing content
    $local_dynamic_content_data = ContentData::DynamicContentData.new
    $local_dynamic_content_data.update(initial_content_data)

    #Start files monitor taking into consideration  existing content  data
    fm = FileMonitoring::FileMonitoring.new($local_dynamic_content_data)
    fm.set_event_queue(monitoring_events)
    # Start monitoring and writing changes to queue
    all_threads << Thread.new do
      fm.monitor_files
    end

    # # # # # # # # # # # # # #
    # Initialize/Start local indexer
    Log.debug1('Start indexer')
    queue_indexer = QueueIndexer.new(monitoring_events, $local_dynamic_content_data)
    # Start indexing on demand and write changes to queue
    all_threads << queue_indexer.run

    # # # # # # # # # # # # # # # # # # # # # # # #
    # Start dump local content data to file thread
    Log.debug1('Start dump local content data to file thread')
    all_threads << Thread.new do
      last_data_flush_time = nil
      while true do
        if last_data_flush_time.nil? || last_data_flush_time + Params['data_flush_delay'] < Time.now.to_i
          Log.info "Writing local content data to #{Params['local_content_data_path']}."
          $local_dynamic_content_data.last_content_data.to_file($tmp_content_data_file)
          File.rename($tmp_content_data_file, Params['local_content_data_path'])
          last_data_flush_time = Time.now.to_i
        end
        sleep(1)
      end
    end

    remote_content_client = RemoteContentServer.new($local_dynamic_content_data,
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


