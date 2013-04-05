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
require 'log'
require 'networking/tcp'
require 'params'
require 'process_monitoring/thread_safe_hash'
require 'process_monitoring/monitoring'
require 'process_monitoring/monitoring_info'

# Content server. Monitors files, index local files, listen to backup server content,
# copy changes and new files to backup server.
module ContentServer
  # Content server specific flags.
  Params.integer('local_files_port', 4444, 'Remote port in backup server to copy files.')
  Params.integer('local_content_data_port', 3333, 'Listen to incoming content data requests.')

  def run_content_server
    all_threads = []

    @process_variables = ThreadSafeHash::ThreadSafeHash.new
    @process_variables.set('server_name', 'content_server')

    # # # # # # # # # # # #
    # Initialize/Start monitoring
    monitoring_events = Queue.new
    fm = FileMonitoring::FileMonitoring.new
    fm.set_event_queue(monitoring_events)
    # Start monitoring and writing changes to queue
    all_threads << Thread.new do
      fm.monitor_files
    end

    # # # # # # # # # # # # # #
    # Initialize/Start local indexer
    local_server_content_data_queue = Queue.new
    queue_indexer = QueueIndexer.new(monitoring_events,
                                     local_server_content_data_queue,
                                     Params['local_content_data_path'])
    # Start indexing on demand and write changes to queue
    all_threads << queue_indexer.run

    # # # # # # # # # # # # # # # # # # # # # #
    # Initialize/Start content data comparator
    copy_files_events = Queue.new  # TODO(kolman): Remove this initialization and merge to FileCopyServer.
    local_dynamic_content_data = ContentData::DynamicContentData.new
    all_threads << Thread.new do  # TODO(kolman): Seems like redundant, check how to update dynamic directly.
      while true do
        # Note: This thread should be the only consumer of local_server_content_data_queue
        Log.info 'Waiting on local server content data.'
        local_server_content_data = local_server_content_data_queue.pop
        local_dynamic_content_data.update(local_server_content_data)
      end
    end

    remote_content_client = RemoteContentServer.new(local_dynamic_content_data,
                                                    Params['local_content_data_port'])
    all_threads << remote_content_client.tcp_thread

    # # # # # # # # # # # # # # # #
    # Start copying files on demand
    copy_server = FileCopyServer.new(copy_files_events, Params['local_files_port'])
    all_threads.concat(copy_server.run())

    if Params['enable_monitoring']
      mon = Monitoring::Monitoring.new(@process_variables)
      Log.add_consumer(mon)
      all_threads << mon.thread
      monitoring_info = MonitoringInfo::MonitoringInfo.new(@process_variables)
    end

    # Finalize server threads.
    all_threads.each { |t| t.abort_on_exception = true }
    all_threads.each { |t| t.join }
    # Should never reach this line.
  end
  module_function :run_content_server

end # module ContentServer


