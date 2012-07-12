require 'set'
require 'thread'

require 'content_data'
require 'content_server/content_receiver'
require 'file_copy'
require 'file_indexing'
require 'file_monitoring'
require 'log'
require 'params'
require 'content_server/queue_indexer'



# Content server. Monitors files, index local files, listen to backup server content,
# copy changes and new files to backup server.
module BBFS
  module ContentServer
    Params.parameter('remote_server', 'localhost', 'IP or DNS of backup server.')
    Params.parameter('remote_listening_port', 3333,
                     'Listening port for backup server content data.')
    Params.parameter('backup_username', nil, 'Backup server username.')
    Params.parameter('backup_password', nil, 'Backup server password.')
    Params.parameter('backup_destination_folder', '',
                     'Backup server destination folder, default is the relative local folder.')
    Params.parameter('content_data_path', File.expand_path('~/.bbfs/var/content.data'),
                     'ContentData file path.')
    Params.parameter('monitoring_config_path', File.expand_path('~/.bbfs/etc/file_monitoring.yml'),
                     'Configuration file for monitoring.')

    def run
      all_threads = []

      # # # # # # # # # # # #
      # Initialize/Start monitoring
      monitoring_events = Queue.new
      fm = FileMonitoring::FileMonitoring.new
      fm.set_config_path(Params.monitoring_config_path)
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
          Params.remote_listening_port)
      # Start listening to backup server
      all_threads << Thread.new do
        content_data_receiver.run
      end

      # # # # # # # # # # # # # #
      # Initialize/Start local indexer
      local_server_content_data_queue = Queue.new
      queue_indexer = QueueIndexer.new(monitoring_events,
                                       local_server_content_data_queue,
                                       Params.content_data_path)
      # Start indexing on demand and write changes to queue
      all_threads << queue_indexer.run

      # # # # # # # # # # # # # # # # # # # # # #
      # Initialize/Start content data comparator
      copy_files_events = Queue.new
      all_threads << Thread.new do
        backup_server_content_data = ContentData::ContentData.new
        local_server_content_data = nil
        while true do

          # Note: This thread should be the only consumer of local_server_content_data_queue
          Log.info 'Waiting on local server content data.'
          local_server_content_data = local_server_content_data_queue.pop

          # Note: This thread should be the only consumer of backup_server_content_data_queue
          # Note: The server will wait in the first time on pop until backup sends it's content data
          while backup_server_content_data_queue.size > 0
            Log.info 'Waiting on backup server content data.'
            backup_server_content_data = backup_server_content_data_queue.pop
          end

          Log.info 'Updating file copy queue.'
          Log.info "local_server_content_data #{local_server_content_data}."
          Log.info "backup_server_content_data #{backup_server_content_data}."
          # Remove backup content data from local server
          content_to_copy = ContentData::ContentData.remove(backup_server_content_data, local_server_content_data)
          # Add copy instruction in case content is not empty
          Log.info "Content to copy: #{content_to_copy}"
          copy_files_events.push(content_to_copy) unless content_to_copy.empty?
        end
      end


      # # # # # # # # # # # # # # # #
      # Start copying files on demand
      all_threads << Thread.new do
        while true do
          Log.info 'Waiting on copy files events.'
          copy_event = copy_files_events.pop

          Log.info "Copy file event: #{copy_event}"

          # Prepare source,dest map for copy.
          used_contents = Set.new
          files_map = Hash.new
          Log.info "Instances: #{copy_event.instances}"
          copy_event.instances.each { |key, instance|
            Log.info "Instance: #{instance}"
            # Add instance only if such content has not added yet.
            if !used_contents.member?(instance.checksum)
              files_map[instance.full_path] = destination_filename(
                  Params.backup_destination_folder,
                  instance.checksum)
              used_contents.add(instance.checksum)
            end
          }

          Log.info "Copying files: #{files_map}."
          # Copy files, waits until files are finished copying.
          FileCopy::sftp_copy(Params.backup_username,
                              Params.backup_password,
                              Params.remote_server,
                              files_map)
        end
      end

      all_threads.each { |t| t.abort_on_exception = true }
      all_threads.each { |t| t.join }
      # Should never reach this line.
    end
    module_function :run

    # Creates destination filename for backup server, input is base folder and sha1.
    # for example: folder:/mnt/hd1/bbbackup, sha1:d0be2dc421be4fcd0172e5afceea3970e2f3d940
    # dest filename: /mnt/hd1/bbbackup/d0/be/2d/d0be2dc421be4fcd0172e5afceea3970e2f3d940
    def destination_filename(folder, sha1)
      File.join(folder, sha1[0,2], sha1[2,2], sha1)
    end
    module_function :destination_filename

    def run_backup_server
      all_threads = []

      # # # # # # # # # # # #
      # Initialize/Start monitoring
      monitoring_events = Queue.new
      fm = FileMonitoring::FileMonitoring.new
      fm.set_config_path(Params.monitoring_config_path)
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
                                       Params.content_data_path)
      # Start indexing on demand and write changes to queue
      all_threads << queue_indexer.run

      # # # # # # # # # # # # # # # # # # # # # # # # # # #
      # Initialize/Start backup server content data sender
      content_data_sender = ContentDataSender.new(
          Params.remote_server,
          Params.remote_listening_port)
      # Start sending to backup server
      all_threads << Thread.new do
        while true do
          Log.info 'Waiting on local server content data queue.'
          content_data_sender.send_content_data(local_server_content_data_queue.pop)
        end
      end

      all_threads.each { |t| t.abort_on_exception = true }
      all_threads.each { |t| t.join }
      # Should never reach this line.
    end
    module_function :run_backup_server

  end # module ContentServer
end # module BBFS

