require 'net/sftp'
require 'net/ssh'

require 'email'
require 'log'
require 'params'
require 'validations'

# Testing server. Assumes that content and backup servers are running.
# The server runs 24-7, generates/deletes files and validates content at backup periodically.
module TestingServer

  #Parameters
  Params.string('master_host', nil, 'Remote host name of master (content) server.')
  Params.string('master_username', nil, 'Remote master (content) server username.')
  Params.string('master_file_generator_config', nil, 'Path to config file in remote master (content) server.')
  Params.string('remote_master_content_data', nil, 'Path to remote master (content) server index (content data) file.')
  Params.string('remote_master_validation_log', nil, 'Path to ')
  Params.string('local_master_content_data', nil, 'Local path to copy master server index file to.')
  Params.path('backup_content_data', '', 'Local path to index (content data) file.')

  Params.string('from_email', nil, 'From gmail address for update.')
  Params.string('from_email_password', nil, 'From gmail password.')
  Params.string('to_email', nil, 'Destination email for updates.')

  Params.integer('sleep_seconds_after_file_generation', 120, '')

  Params.integer('email_delay_in_seconds', 60*60*6, 'Number of seconds before sending email again.')

  def run_testing_server
    email_timestamp_sent = Time.now.to_i
    while(true) do
      # Generate files in remote content server (master).
      # Assumes file_utils gem is installed.
      # Assumes run finishes after some time.
      # Assumes configuration file exists in place.
      Log.info("Generating files remotely on #{Params['master_host']} with configuration file " \
               "#{Params['master_file_generator_config']}")
      command = "file_utils --conf_file=#{Params['master_file_generator_config']} --command=generate_files"
      fg_ret = execute_remotely(command)
      Log.info("#{command}: #{fg_ret}")

      # Wait some time.
      Log.info("Done, sleeping #{Params['sleep_seconds_after_file_generation']} seconds.")
      sleep(Params['sleep_seconds_after_file_generation'])

      # Validate master local files.
      # Assumes index_validator gem installed.
      command = "index_validator --local_index=#{Params['remote_master_content_data']}"
      Log.info("Remotely validating index: #{command}")
      iv_ret = execute_remotely(command)
      Log.info("#{command}: #{iv_ret}")

      # Validate backup local files.
      Log.info("Localy validating index: #{Params['backup_content_data']}")
      index = ContentData::ContentData.new
      index.from_file(Params['backup_content_data'])
      local_ret = index.validate
      Log.info("Validation result: #{local_ret}")

      # Validate existence of master files in backup.
      Log.info("Copy remote master index: #{Params['remote_master_content_data']} to " \
               "#{Params['local_master_content_data']}")
      copy_master_index(Params['remote_master_content_data'], Params['local_master_content_data'])
      Log.info("Validating remote index locally (#{Params['local_master_content_data']})}")
      remote_index = ContentData::ContentData.new
      remote_index.from_file(Params['local_master_content_data'])
      remote_ret = Validations::IndexValidations.validate_remote_index remote_index, index
      Log.info("Validation result: #{remote_ret}")

      if (Time.now.to_i - email_timestamp_sent > Params['email_delay_in_seconds'])
        # Send email.
        Log.info("Sending email...")
        msg =<<EOF
Master index ok: #{iv_ret}
Backup index ok: #{local_ret}
Backup includes all master files: #{remote_ret}
EOF
        Email.send_email(Params['from_email'],
                         Params['from_email_password'],
                         Params['to_email'],
                         msg)
      end
      Log.info("Done.")
    end
  end
  module_function :run_testing_server

  # Copies master (remote) content data (index) locally and returns the pass.
  def copy_master_index(from, to, host=Params['master_host'], username=Params['master_username'])
    Net::SFTP.start(host, username) do |sftp|
      sftp.download!(from, to)
    end
  end
  module_function :copy_master_index

  # Returns the text output
  def execute_remotely(cmd,
      host=Params['master_host'],
      username=Params['master_username'])
    ret = nil
    Net::SSH.start(host, username) do |ssh|
      ssh.exec!(cmd) do |ch, stream, data|
        ret = data
      end
    end
    return ret
  end
  module_function :execute_remotely

end # module TestingServer


