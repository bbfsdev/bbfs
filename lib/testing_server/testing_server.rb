#require 'net/sftp'
#require 'net/ssh'
require 'log4r'
require 'log'
require 'params'
require 'content_server'
require 'content_server/content_server'  # specific content server impl
require 'content_server/backup_server' # specific backup server impl
require 'content_data'
require 'email'
require 'file_utils/file_generator/file_generator'
require 'validations'

# Testing server. Assumes that content and backup servers are running.
# The server runs 24-7, generates/deletes files and validates content at backup periodically.
module TestingServer
  # TODO get latest ContentData object directly from Content/BackupServer
  # Then need changes in Content/BackupServers API
  # TODO split to Backup/ContentTestingServers separate classes ?
  # TODO split long methods
  # TODO Tests
  # TODO No default config taken by Params
  # TODO Additional testing scenarios (remove/rename/change)

  # Messages types
  :GET_INDEX  # get index from remote master
  :PUT_INDEX  # message contains requested index from master
  # TODO in thus implementation validation called automatically on master side
  # with receiving GET_INDEX message
  # More flexible will be separating it to two separate operations:
  # GET_INDEX and VALIDATE
  #:VALIDATE  # validate index on master
  :PUT_VALIDATION  # message contains validation result from master

  Params.path('testing_log_path', nil, 'Testing server log path.')

  # init process vars
  $objects_counters = {}
  $objects_counters["Time"] = Time.now.to_i

  def init_log4r
    #init log4r
    log_path = Params['testing_log_path']
    unless log_path
      raise("pls specify testing log path through param:'testing_log_path'")
    end
    log_dir = File.dirname(log_path)
    FileUtils.mkdir_p(log_dir) unless File.exists?(log_dir)

    $log4r = Log4r::Logger.new 'BBFS testing server log'
    $log4r.trace = true
    formatter = Log4r::PatternFormatter.new(:pattern => "[%d] [%m]")
    #file setup
    file_config = {
        "filename" => Params['testing_log_path'],
        "maxsize" => Params['log_rotation_size'],
        "trunc" => true
    }
    file_outputter = Log4r::RollingFileOutputter.new("testing_log", file_config)
    file_outputter.level = Log4r::INFO
    file_outputter.formatter = formatter
    $log4r.outputters << file_outputter
  end

  def run_content_testing_server
    Log.info('Testing server started')
    init_log4r
    $log4r.info 'Testing server started'
    all_threads = [];
    messages = Queue.new

    all_threads << Thread.new do
      ContentServer.run_content_server
    end

    all_threads << Thread.new do
      fg = FileGenerator::FileGenerator.new
      fg.run
    end

    receive_msg_proc = lambda do |addr_info, message|
      $log4r.info("message received: #{message}")
      messages.push(message)
    end
    tcp = Networking::TCPServer.new(Params['testing_server_port'], receive_msg_proc)

    all_threads << tcp.tcp_thread

    while(true) do
      msg_type, validation_timestamp = messages.pop
      if msg_type == :GET_INDEX
        cur_index = ContentData::ContentData.new
        cur_index.from_file(Params['local_content_data_path'])
        tcp.send_obj([:PUT_INDEX, validation_timestamp, cur_index])
        $log4r.info "PUT_INDEX sent with timestamp #{validation_timestamp}"
        is_index_ok = cur_index.validate
        tcp.send_obj([:PUT_VALIDATION, validation_timestamp, is_index_ok])
        $log4r.info "PUT_VALIDATION sent with timestamp #{validation_timestamp}"
      end
    end
  end
  module_function :run_content_testing_server

  def run_backup_testing_server
    Log.info('Testing server started')
    init_log4r
    $log4r.info 'Testing server started'
    all_threads = [];
    messages = Queue.new
    # used for synchronization between servers
    validation_timestamp = Time.now.to_i
    # holds boolean whether all contents according to this timestamp that should be backed are backed and OK
    is_cur_synch_ok = nil
    # holds boolean whether all already backuped files are OK
    is_backup_ok = nil
    # holds boolean whether master is valid. receive from master
    is_master_ok = nil
    # number of contents must be backuped this synch
    # with current scenarios this number expected to grow
    # used to check that file_generator is actually running
    numb_backuped_contents = 0

    all_threads << Thread.new do
      ContentServer.run_backup_server
    end

    receive_msg_proc = lambda do |message|
      $log4r.info("message received: #{message}")
      messages.push(message)
    end
    tcp = Networking::TCPClient.new(Params['content_server_hostname'],
                                    Params['testing_server_port'], receive_msg_proc)
    all_threads << tcp.tcp_thread

    # used to request index from master per validation interval of time
    all_threads << Thread.new do
      while(true) do
        sleep Params['validation_interval']
        validation_timestamp = Time.now.to_i
        tcp.send_obj([:GET_INDEX, validation_timestamp])
        $log4r.info "GET_INDEX sent with timestamp #{validation_timestamp}"
      end
    end

    # gets messages from master via queue
    # handles them according to type
    while(true) do
      msg_type, response_validation_timestamp, msg_body = messages.pop
      $log4r.info "#{msg_type} : #{validation_timestamp} : #{msg_body.class}"
      unless (validation_timestamp == response_validation_timestamp)
        # TODO problem of servers synch. What should be done here?
        $log4r.warning "Timestamps differs: requested #{validation_timestamp} : received #{response_validation_timestamp}"
      end

      case msg_type
      when :PUT_INDEX
        # index of already backuped contents
        backuped_index = ContentData::ContentData.new
        backuped_index.from_file Params['local_content_data_path']
        # index contains only master current contents
        # that must be backuped according to backup_time_requirement parameter
        index_must_be_backuped = ContentData::ContentData.new(msg_body)
        # we backup contents, so content mtime used to determine contents should be validated
        index_must_be_backuped.each_content do |checksum, size, mtime|
          if (validation_timestamp - mtime < Params['backup_time_requirement'])
            index_must_be_backuped.remove_content checksum
          end
        end
        is_cur_synch_ok =
          Validations::IndexValidations.validate_remote_index index_must_be_backuped, backuped_index
        is_backup_ok = backuped_index.validate
        numb_backuped_contents = index_must_be_backuped.contents_size
      when :PUT_VALIDATION
        is_master_ok = msg_body
      else
        $log4r.error "Incorrect message received: #{msg_type}"
      end

      unless (is_master_ok.nil? || is_cur_synch_ok.nil? || is_backup_ok.nil?)
        send_email is_master_ok, is_cur_synch_ok, is_backup_ok, numb_backuped_contents
        is_master_ok = nil
        is_cur_synch_ok = nil
        is_backup_ok = nil
        numb_backuped_contents = 0
      end
    end
  end


  def generate_mem_report
    # Generate memory report
    current_objects_counters = {}
    time = Time.now
    current_objects_counters['Time'] = time.to_i
    count = ObjectSpace.each_object(String).count
    current_objects_counters['String'] = count
    count = ObjectSpace.each_object(ContentData::ContentData).count
    current_objects_counters['ContentData'] = count
    dir_count = ObjectSpace.each_object(FileMonitoring::DirStat).count
    current_objects_counters['DirStat'] = dir_count
    file_count = ObjectSpace.each_object(FileMonitoring::FileStat).count
    current_objects_counters['FileStat'] = file_count-dir_count

    # Generate report and update global counters
    report = ""
    current_objects_counters.each_key { |type|
      $objects_counters[type] = 0 unless $objects_counters[type]
      diff =  current_objects_counters[type] - $objects_counters[type]
      report += "Type:#{type} raised in:#{diff}   \n"
      $objects_counters[type] = current_objects_counters[type]
    }
    final_report = "Memory report at Time:#{time}:\n#{report}\n"
    $log4r.Info(final_report)
    final_report
  end
  def send_email(is_master_ok, is_cur_synch_ok, is_backup_ok, numb_backuped_contents)

    msg =<<EOF
Master index ok: #{is_master_ok}
Backup index ok: #{is_backup_ok}
Backup includes all master files upto -#{Params['backup_time_requirement']} sec: #{is_cur_synch_ok}
Number of contents must be back-up: #{numb_backuped_contents}
#{generate_mem_report}
EOF
    Email.send_email(Params['from_email'],
                     Params['from_email_password'],
                     Params['to_email'],
                     'Testing server update',
                     msg)
  end

  module_function :send_email, :run_backup_testing_server, :init_log4r, :generate_mem_report

end # module TestingServer


