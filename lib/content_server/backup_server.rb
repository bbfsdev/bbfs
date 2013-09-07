require 'fileutils'
require 'set'
require 'thread'

require 'content_data'
require 'content_server/content_receiver'
require 'content_server/queue_indexer'
require 'content_server/queue_copy'
require 'content_server/remote_content'
require 'content_server/server'
require 'file_indexing'
require 'file_monitoring'
require 'log'
require 'networking/tcp'
require 'params'
#require 'process_monitoring/monitoring'
#require 'process_monitoring/monitoring_info'

# Content server. Monitors files, index local files, listen to backup server content,
# copy changes and new files to backup server.
module ContentServer
  # Backup server specific flags
  Params.string('content_server_hostname', nil, 'IP or DNS of backup server.')
  Params.integer('content_server_data_port', 3333, 'Port to copy content data from.')
  Params.integer('content_server_files_port', 4444, 'Listening port in backup server for files')
  Params.integer('backup_check_delay', 5, 'Delay in seconds between two content vs backup checks.')
  Params.complex('backup_destination_folder',
                 [{'path'=>File.expand_path(''), 'scan_period'=>300, 'stable_state'=>1}],
                 'Backup server destination folder, default is the relative local folder.')

  def run_backup_server
    Log.info('Start backup server')
    Thread.abort_on_exception = true
    all_threads = []

    # create general tmp dir
    FileUtils.mkdir_p(Params['tmp_path']) unless File.directory?(Params['tmp_path'])
    # init tmp content data file
    $tmp_content_data_file = File.join(Params['tmp_path'], 'backup.data')

    if Params['enable_monitoring']
      Log.info("Initializing monitoring of process params on port:#{Params['process_monitoring_web_port']}")
      $process_vars.set('server_name', 'backup_server')
    end

    # # # # # # # # # # # #
    # Initialize/start monitoring and destination folder
    Params['backup_destination_folder'][0]['path']=File.expand_path(Params['backup_destination_folder'][0]['path'])
    Log.info("backup_destination_folder is:#{Params['backup_destination_folder'][0]['path']}")
    #adding destination folder to monitoring paths
    Params['monitoring_paths'] << Params['backup_destination_folder'][0]
    Log.info('Start monitoring following directories:')
    Params['monitoring_paths'].each { |path|
      Log.info("  Path:'#{path['path']}'")
    }

    # initial global local content data object
    $local_content_data_lock = Mutex.new
    $local_content_data = ContentData::ContentData.new

    # Read here for initial content data that exist from previous system run
    content_data_path = Params['local_content_data_path']
    if File.exists?(content_data_path) and !File.directory?(content_data_path)
      Log.info("reading initial content data that exist from previous system run from file:#{content_data_path}")
      $local_content_data.from_file(content_data_path)
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
=begin
    # # # # # # # # # # # # # # # # # # # # # # # #
    # thread: Start dump local content data to file
    Log.debug1('Init thread: flush local content data to file')
    all_threads << Thread.new do
      FileUtils.mkdir_p(Params['tmp_path']) unless File.directory?(Params['tmp_path'])
      last_content_data_id = nil
      loop{
        sleep(Params['data_flush_delay'])
        Log.info('Start flush local content data to file.')
        $testing_memory_log.info('Start flush content data to file') if $testing_memory_active
        written_to_file = false
        $local_content_data_lock.synchronize{
          local_content_data_unique_id = $local_content_data.unique_id
          #if (local_content_data_unique_id != last_content_data_id)
            last_content_data_id = local_content_data_unique_id
            $local_content_data.to_file($tmp_content_data_file)
            written_to_file = true
            Log.info('End flush local content data to file.')
          #else
            #Log.info('no need to flush. content data has not changed')
          #end
        }
        File.rename($tmp_content_data_file, Params['local_content_data_path']) if written_to_file
        $testing_memory_log.info("End flush content data to file") if $testing_memory_active
      }
    end
=end
    #initialize global - remote content data
    $remote_content_data_lock = Mutex.new
    $remote_content_data = ContentData::ContentData.new
    remote_content = ContentServer::RemoteContentClient.new(Params['content_server_hostname'],
                                                            Params['content_server_data_port'],
                                                            Params['backup_destination_folder'][0]['path'])
    all_threads.concat(remote_content.run())

    file_copy_client = FileCopyClient.new(Params['content_server_hostname'],
                                          Params['content_server_files_port'])
    all_threads.concat(file_copy_client.threads)

    # Each
    Log.info('Start remote and local contents comparator')
    all_threads << Thread.new do
      loop do
        sleep(Params['backup_check_delay'])
        $local_content_data_lock.synchronize{
          $remote_content_data_lock.synchronize{
            diff = ContentData.remove($local_content_data, $remote_content_data)
            unless diff.nil? || diff.empty?
              Log.debug2("Backup content:\n#{$local_content_data}")
              Log.debug2("Remote content:\n#{$remote_content_data}")
              Log.debug2("Missing contents:\n#{diff}")
              Log.info('Start sync check. Backup and remote contents need a sync, requesting copy files:')
              file_copy_client.request_copy(diff)
            else
              Log.info("Start sync check. Local and remote contents are equal. No sync required.")
            end
            diff = ContentData::ContentData.new  # to clear the memory
          }
        }
      end
    end

    # # # # # # # # # # # # # # # # # # # # # # # #
    # Start process vars thread
    if Params['enable_monitoring']
      monitoring_info = MonitoringInfo::MonitoringInfo.new()
      all_threads << Thread.new do
        ContentServer.monitor_general_process_vars
      end
    end

    all_threads.each { |t| t.abort_on_exception = true }
    all_threads.each { |t| t.join }
    # Should never reach this line.
  end
  module_function :run_backup_server

end # module ContentServer


