#require 'net/sftp'
#require 'net/ssh'
require 'log'
require 'params'
require 'content_server'
require 'content_data'
require 'email'
require 'file_utils/file_generator/file_generator'
require 'validations'

# Testing server. Assumes that content and backup servers are running.
# The server runs 24-7, generates/deletes files and validates content at backup periodically.
module TestingServer
  # TODO get latest ContentData object from Content/BackupServer
  # Therefore need changes in Content/BackupServers
  # TODO split to Backup/ContentTestingServers ?
  # TODO split long methods
  # TODO Tests
  # TODO No default config taken by Params

  # Messages types
  :GET_INDEX  # get index from remote master
  :PUT_INDEX  # message contains requested index from master
  # TODO in thus implementation validation called automatically on master side
  # with receiving GET_INDEX message
  # More flexible will be separating it to two separate operations:
  # GET_INDEX and VALIDATE
  #:VALIDATE  # validate index on master
  :PUT_VALIDATION  # message contains validation result from master

  def run_content_testing_server
    Log.info 'Testing server started'
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
      Log.debug2("message received: #{message}")
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
        Log.debug2 "PUT_INDEX sent with timestamp #{validation_timestamp}"
        is_index_ok = cur_index.validate
        tcp.send_obj([:PUT_VALIDATION, validation_timestamp, is_index_ok])
        Log.debug2 "PUT_VALIDATION sent with timestamp #{validation_timestamp}"
      end
    end
  end
  module_function :run_content_testing_server

  def run_backup_testing_server
    Log.info 'Testing server started'
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

    all_threads << Thread.new do
      ContentServer.run_backup_server
    end

    receive_msg_proc = lambda do |message|
      Log.debug2("message received: #{message}")
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
        Log.debug2 "GET_INDEX sent with timestamp #{validation_timestamp}"
      end
    end

    # gets messages from master via queue
    # handles them according to type
    while(true) do
      msg_type, response_validation_timestamp, msg_body = messages.pop
      Log.debug2 "#{msg_type} : #{validation_timestamp} : #{msg_body.class}"
      unless (validation_timestamp == response_validation_timestamp)
        # TODO problem of servers synch. What should be done here?
        Log.warning "Timestamps differs: requested #{validation_timestamp} : received #{response_validation_timestamp}"
      end

      case msg_type
      when :PUT_INDEX
        time_now = Time.now.to_i
        # index of already backuped contents
        backuped_index = ContentData::ContentData.new
        backuped_index.from_file Params['local_content_data_path']
        # index contains only master current contents
        # that must be backuped according to backup_time_requirement parameter
        index_must_be_backuped = ContentData::ContentData.new(msg_body)
        # we backup contents, so content mtime used to determine contents should be validated
        index_must_be_backuped.each_content do |checksum, size, mtime|
          if (mtime - time_now < Params['backup_time_requirement'])
            index_must_be_backuped.remove_content checksum
          end
        end
        is_cur_synch_ok =
          Validations::IndexValidations.validate_remote_index index_must_be_backuped, backuped_index
        is_backup_ok = backuped_index.validate
      when :PUT_VALIDATION
        is_master_ok = msg_body
      else
        Log.error "Incorrect message received: #{msg_type}"
      end

      unless (is_master_ok.nil? || is_cur_synch_ok.nil? || is_backup_ok.nil?)
        send_email is_master_ok, is_cur_synch_ok, is_backup_ok
      end
    end
  end
  module_function :run_backup_testing_server

  def send_email(is_master_ok, is_cur_synch_ok, is_backup_ok)
    msg =<<EOF
Master index ok: #{is_master_ok}
Backup index ok: #{is_backup_ok}
Backup includes all master files upto -#{Params['backup_time_requirement']} sec: #{is_cur_synch_ok}
EOF
    Email.send_email(Params['from_email'],
                     Params['from_email_password'],
                     Params['to_email'],
                     'Testing server update',
                     msg)
  end
  module_function :send_email

end # module TestingServer


