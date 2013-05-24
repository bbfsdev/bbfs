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
  # Backup server specific flags
  Params.string('content_server_hostname', nil, 'IP or DNS of backup server.')
  Params.integer('content_server_data_port', 3333, 'Port to copy content data from.')
  Params.integer('content_server_files_port', 4444, 'Listening port in backup server for files')

  Params.integer('backup_check_delay', 5, 'Delay in seconds between two content vs backup checks.')

  def run_backup_server
    Thread.abort_on_exception = true
    all_threads = []

    @process_variables = ThreadSafeHash::ThreadSafeHash.new
    @process_variables.set('server_name', 'backup_server')

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

    # # # # # # # # # # # # # # # # # # # # # # # # # # #
    # Initialize/Start backup server content data sender
    dynamic_content_data = ContentData::DynamicContentData.new
    #content_data_sender = ContentDataSender.new(
    #    Params['remote_server'],
    #    Params['remote_listening_port'])
    # Start sending to backup server
    all_threads << Thread.new do
      while true do
        Log.debug1 'Waiting on local server content data queue.'
        cd = local_server_content_data_queue.pop
        #    content_data_sender.send_content_data(cd)
        dynamic_content_data.update(cd)
      end
    end

    Params['backup_destination_folder'] = File.expand_path(Params['monitoring_paths'][0]['path'])
    content_server_dynamic_content_data = ContentData::DynamicContentData.new
    remote_content = ContentServer::RemoteContentClient.new(content_server_dynamic_content_data,
                                                            Params['content_server_hostname'],
                                                            Params['content_server_data_port'],
                                                            Params['backup_destination_folder'])
    all_threads.concat(remote_content.run())

    file_copy_client = FileCopyClient.new(Params['content_server_hostname'],
                                          Params['content_server_files_port'],
                                          dynamic_content_data,
                                          @process_variables)
    all_threads.concat(file_copy_client.threads)

    # Each
    all_threads << Thread.new do
      loop do
        sleep(Params['backup_check_delay'])
        local_cd = dynamic_content_data.last_content_data()
        remote_cd = content_server_dynamic_content_data.last_content_data()
        diff = ContentData::ContentData.remove(local_cd, remote_cd)
        Log.debug1("Local and remote contents are equal?: #{diff.empty?}")
        #file_copy_client.request_copy(diff) unless diff.empty?
        if !diff.empty?
          Log.debug2('Backup and remote contents need a sync:')
          Log.debug2("Backup content:\n#{local_cd}")
          Log.debug2("Remote content:\n#{remote_cd}")
          Log.debug2("Missing contents:\n#{diff}")
          Log.debug2('Requesting a copy')
          file_copy_client.request_copy(diff)
        end
      end
    end

    if Params['enable_monitoring']
      mon = Monitoring::Monitoring.new(@process_variables)
      Log.add_consumer(mon)
      all_threads << mon.thread
      monitoring_info = MonitoringInfo::MonitoringInfo.new(@process_variables)
    end

    all_threads.each { |t| t.abort_on_exception = true }
    all_threads.each { |t| t.join }
    # Should never reach this line.
  end
  module_function :run_backup_server

end # module ContentServer


