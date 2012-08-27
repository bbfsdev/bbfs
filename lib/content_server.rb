require 'fileutils'
require 'set'
require 'thread'

require 'content_data'
require 'content_server/content_receiver'
require 'content_server/queue_indexer'
require 'content_server/queue_copy'
require 'content_server/remote_content'
require 'file_copy'
require 'file_indexing'
require 'file_monitoring'
require 'log'
require 'networking/tcp'
require 'params'



# Content server. Monitors files, index local files, listen to backup server content,
# copy changes and new files to backup server.
module BBFS
  module ContentServer
    Params.string('remote_server', 'localhost', 'IP or DNS of backup server.')
    Params.integer('remote_listening_port', 3333,
                     'Listening port for backup server content data.')
    Params.string('backup_username', nil, 'Backup server username.')
    Params.string('backup_password', nil, 'Backup server password.')
    Params.integer('backup_file_listening_port', 4444, 'Listening port in backup server for files')
    Params.string('backup_destination_folder', '',
                     'Backup server destination folder, default is the relative local folder.')
    Params.string('content_data_path', File.expand_path('~/.bbfs/var/content.data'),
                     'ContentData file path.')
    Params.string('monitoring_config_path', File.expand_path('~/.bbfs/etc/file_monitoring.yml'),
                     'Configuration file for monitoring.')
    Params.integer('remote_content_port', 5555, 'Default port for remote content copy')

    def run
      all_threads = []

      # # # # # # # # # # # #
      # Initialize/Start monitoring
      monitoring_events = Queue.new
      fm = FileMonitoring::FileMonitoring.new
      fm.set_config_path(Params['monitoring_config_path'])
      fm.set_event_queue(monitoring_events)
      # Start monitoring and writing changes to queue
      all_threads << Thread.new do
        fm.monitor_files
      end

      # # # # # # # # # # # # # # # # # # # # # # # # #
      # Initialize/Start backup server content data listener
      #backup_server_content_data = nil
      #backup_server_content_data_queue = Queue.new
      #content_data_receiver = ContentDataReceiver.new(
      #    backup_server_content_data_queue,
      #    Params['remote_listening_port'])
      # Start listening to backup server
      #all_threads << Thread.new do
      #  content_data_receiver.run
      #end

      # # # # # # # # # # # # # #
      # Initialize/Start local indexer
      local_server_content_data_queue = Queue.new
      queue_indexer = QueueIndexer.new(monitoring_events,
                                       local_server_content_data_queue,
                                       Params['content_data_path'])
      # Start indexing on demand and write changes to queue
      all_threads << queue_indexer.run

      # # # # # # # # # # # # # # # # # # # # # #
      # Initialize/Start content data comparator
      copy_files_events = Queue.new
      local_dynamic_content_data = ContentData::DynamicContentData.new
      all_threads << Thread.new do
      #  backup_server_content_data = ContentData::ContentData.new
      #  local_server_content_data = nil
        while true do

          # Note: This thread should be the only consumer of local_server_content_data_queue
          Log.info 'Waiting on local server content data.'
          local_server_content_data = local_server_content_data_queue.pop
          local_dynamic_content_data.update(local_server_content_data)
      #
      #    # Note: This thread should be the only consumer of backup_server_content_data_queue
      #    # Note: The server will wait in the first time on pop until backup sends it's content data
      #    while backup_server_content_data_queue.size > 0
      #      Log.info 'Waiting on backup server content data.'
      #      backup_server_content_data = backup_server_content_data_queue.pop
      #    end

          Log.info 'Updating file copy queue.'
          Log.debug1 "local_server_content_data #{local_server_content_data}."
      #    Log.debug1 "backup_server_content_data #{backup_server_content_data}."
      #    # Remove backup content data from local server
      #    content_to_copy = ContentData::ContentData.remove(backup_server_content_data, local_server_content_data)
          content_to_copy = local_server_content_data
      #    # Add copy instruction in case content is not empty
          Log.debug1 "Content to copy: #{content_to_copy}"
          copy_files_events.push([:COPY_MESSAGE, content_to_copy]) unless content_to_copy.empty?
        end
      end

      remote_content_client = RemoteContentClient.new(local_dynamic_content_data,
                                                      Params['remote_content_port'])
      all_threads << remote_content_client.tcp_thread

      # # # # # # # # # # # # # # # #
      # Start copying files on demand
      queue_copy = QueueCopy.new(copy_files_events, Params['remote_server'],
                                 Params['backup_file_listening_port'])
      all_threads.concat(queue_copy.run())

      # Finalize server threads.
      all_threads.each { |t| t.abort_on_exception = true }
      all_threads.each { |t| t.join }
      # Should never reach this line.
    end
    module_function :run

    def run_backup_server
      all_threads = []

      # # # # # # # # # # # #
      # Initialize/Start monitoring
      monitoring_events = Queue.new
      fm = FileMonitoring::FileMonitoring.new
      fm.set_config_path(Params['monitoring_config_path'])
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
                                       Params['content_data_path'])
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
          Log.info 'Waiting on local server content data queue.'
          cd = local_server_content_data_queue.pop
      #    content_data_sender.send_content_data(cd)
          dynamic_content_data.update(cd)
        end
      end

      content_server_dynamic_content_data = ContentData::DynamicContentData.new
      remote_content = ContentServer::RemoteContent.new(content_server_dynamic_content_data,
                                                        Params['remote_server'],
                                                        Params['remote_content_port'],
                                                        Params['backup_destination_folder'])
      all_threads.concat(remote_content.run())

      queue_file_receiver = QueueFileReceiver.new(Params['backup_file_listening_port'],
                                                  dynamic_content_data)
      all_threads << queue_file_receiver.tcp_thread

      all_threads.each { |t| t.abort_on_exception = true }
      all_threads.each { |t| t.join }
      # Should never reach this line.
    end
    module_function :run_backup_server

  end # module ContentServer
end # module BBFS

