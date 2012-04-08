require 'content_data'
require 'file_copy/copy'
require 'file_monitoring'
require 'thread'
require 'params'

require_relative 'content_server/content_receiver'
require_relative 'content_server/queue_indexer'

# Content server. Monitors files, index local files, listen to backup server content,
# copy changes and new files to backup server.
module BBFS
  module ContentServer
    VERSION = '0.0.1'

    PARAMS.parameter('remote_server', 'localhost', 'IP or DNS of backup server.')
    PARAMS.parameter('remote_listening_port', 3333, 'Listening port for backup server content data.')
    PARAMS.parameter('backup_username', nil, 'Backup server username.')
    PARAMS.parameter('backup_password', nil, 'Backup server password.')
    PARAMS.parameter('backup_destination_folder', File.expand_path('~/.bbfs/data'),
                     'Backup server destination folder.')
    PARAMS.parameter('content_data_path', File.expand_path('~/.bbfs/var/content.data'),
                     'ContentData file path.')
    PARAMS.parameter('monitoring_config_path', File.expand_path('~/.bbfs/etc/file_monitoring.yml'),
                     'Configuration file for monitoring.')

    def run
      all_threads = []

      # # # # # # # # # # # #
      # Initialize/Start monitoring
      monitoring_events = Queue.new
      fm = FileMonitoring::FileMonitoring.new
      fm.set_config_path(PARAMS.monitoring_config_path)
      fm.set_event_queue(monitoring_events)
      # Start monitoring and writing changes to queue
      all_threads << Thread.new do
        fm.monitor_files
      end

      # # # # # # # # # # # # # # # # # # # # # # # # #
      # Initialize/Start backup server content data listener
      backup_server_content_data = nil
      backup_server_content_data_queue = Queue.new
      content_data_receiver = ContentDataReceiver.new(
          backup_server_content_data_queue,
          PARAMS.remote_server,
          PARAMS.remote_listening_port)
      # Start listening to backup server
      all_threads << Thread.new do
        content_data_receiver.start_server
      end

      # # # # # # # # # # # # # #
      # Initialize/Start local indexer
      copy_files_events = Queue.new
      local_server_content_data_queue = Queue.new
      queue_indexer = QueueIndexer.new(copy_files_events,
                                       local_server_content_data_queue,
                                       PARAMS.content_data_path)
      # Start indexing on demand and write changes to queue
      all_threads << queue_indexer.run

      # # # # # # # # # # # # # # # # # # # # # #
      # Initialize/Start content data comparator
      all_threads << Thread.new do
        backup_server_content = nil
        local_server_content = nil
        while true do

          # Note: This thread should be the only consumer of local_server_content_data_queue
          # Note: The server will wait in the first time on pop until local sends it's content data
          while !local_server_content || local_server_content_data_queue.size > 1
            local_server_content_data = local_server_content_data_queue.pop
          end

          # Note: This thread should be the only consumer of backup_server_content_data_queue
          # Note: The server will wait in the first time on pop until backup sends it's content data
          while !backup_server_content || backup_server_content_data_queue.size > 1
            backup_server_content_data = backup_server_content_data_queue.pop
          end

          # Remove backup content data from local server
          content_to_copy = ContentData.remove(backup_server_content_data, local_server_content)
          # Add copy instruction in case content is not empty
          output_queue.push(content_to_copy) unless content_to_copy.empty?
        end
      end


      # # # # # # # # # # # # # # # #
      # Start copying files on demand
      all_threads << Thread.new do
        while true do
          copy_event = copy_files_events.pop

          # Prepare source,dest map for copy.
          used_contents = Set.new
          files_map = Hash.new
          copy_event.instances.each { |instance|
            # Add instance only if such content has not added yet.
            if !used_contents.has_key?(instance.checksum)
              files_map[instance.full_path] = destination_filename(
                  PARAMS.backup_destination_folder,
                  instance.checksum)
              used_contents.add(instance.checksum)
            end
          }

          # Copy files, waits until files are finished copying.
          FileCopy::sftp_copy(PARAMS.backup_username,
                              PARAMS.backup_password,
                              PARAMS.remote_server,
                              files_map)
        end
      end

      all_threads.each { |t| t.join }
      # Should never reach this line.
    end
    module_function :run

    # Creates destination filename for backup server, input is base folder and sha1.
    # for example: folder:/mnt/hd1/bbbackup, sha1:d0be2dc421be4fcd0172e5afceea3970e2f3d940
    # dest filename: /mnt/hd1/bbbackup/d0/be/2d/d0be2dc421be4fcd0172e5afceea3970e2f3d940
    def destination_filename(folder, sha1)
      File.join(folder, sha1[0,2], sha1[2,2], sha1[4,2], sha1)
    end

    def run_backup_server
      all_threads = []

      # # # # # # # # # # # #
      # Initialize/Start monitoring
      monitoring_events = Queue.new
      fm = FileMonitoring::FileMonitoring.new
      fm.set_config_path(PARAMS.monitoring_config_path)
      fm.set_event_queue(monitoring_events)
      # Start monitoring and writing changes to queue
      all_threads << Thread.new do
        fm.monitor_files
      end

      # # # # # # # # # # # # # #
      # Initialize/Start local indexer
      copy_files_events = Queue.new
      local_server_content_data_queue = Queue.new
      queue_indexer = QueueIndexer.new(copy_files_events,
                                       local_server_content_data_queue,
                                       PARAMS.content_data_path)
      # Start indexing on demand and write changes to queue
      all_threads << queue_indexer.run

      # # # # # # # # # # # # # # # # # # # # # # # # # # #
      # Initialize/Start backup server content data sender
      content_data_sender = ContentDataSender.new(
          PARAMS.remote_server,
          PARAMS.remote_listening_port)
      # Start sending to backup server
      all_threads << Thread.new do
        content_data_sender.connect
        while true do
          content_data_sender.send_content_data(local_server_content_data_queue.pop)
        end
      end
    end

  end # module ContentServer
end # module BBFS
