require 'net/sftp'
require 'net/ssh'

require 'email'
require 'log4r'
require 'log4r/outputter/emailoutputter'
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
    log = Log4r::Logger.new 'mylog'
    log.trace = true

    formatter = Log4r::PatternFormatter.new(:pattern => "[%l] %d #{self.class} %t :: %m")

    stdout_outputtter = Log4r::Outputter.stdout
    stdout_outputtter.formatter = formatter

    file_outputter = Log4r::FileOutputter.new('file_log', :filename =>  "#{Params['log_file_name']}.log4r")
    file_outputter.formatter = formatter

    email_outputter = Log4r::EmailOutputter.new('email_log',
        :server => 'smtp.gmail.com',
        :port => 587,
        :subject => 'Error happened in Testing server.',
        :acct => Params['from_email'],
        :from => Params['from_email'],
        :passwd => Params['from_email_password'],
        :to => Params['to_email'],
        :immediate_at => "FATAL,ERROR",
        :authtype => :plain,
        :tls => true
    )
    email_outputter.level = Log4r::ERROR
    email_outputter.formatter = formatter

    log.outputters << stdout_outputtter
    log.outputters << file_outputter
    log.outputters << email_outputter

    email_timestamp_sent = -1
    while(true) do
      begin  # Handle any type
        # Generate files in remote content server (master).
        # Assumes file_utils gem is installed.
        # Assumes run finishes after some time.
        # Assumes configuration file exists in place.
        log.info("Generating files remotely on #{Params['master_host']} with configuration file " \
                 "#{Params['master_file_generator_config']}")
        command = "file_utils --conf_file=#{Params['master_file_generator_config']} --command=generate_files"
        fg_ret = execute_remotely(command)
        log.info("#{command}: #{fg_ret}")

        # Wait some time.
        log.info("Done, sleeping #{Params['sleep_seconds_after_file_generation']} seconds.")
        sleep(Params['sleep_seconds_after_file_generation'])

        # Validate master local files.
        # Assumes index_validator gem installed.
        command = "index_validator --local_index=#{Params['remote_master_content_data']}"
        log.info("Remotely validating index: #{command}")
        iv_ret = execute_remotely(command)
        log.info("#{command}: #{iv_ret}")

        # Validate backup local files.
        log.info("Locally validating index: #{Params['backup_content_data']}")
        index = ContentData::ContentData.new
        index.from_file(Params['backup_content_data'])
        local_ret = index.validate
        log.info("Validation result: #{local_ret}")

        # Validate existence of master files in backup.
        log.info("Copy remote master index: #{Params['remote_master_content_data']} to " \
                 "#{Params['local_master_content_data']}")
        copy_master_index(Params['remote_master_content_data'], Params['local_master_content_data'])
        log.info("Validating remote index locally (#{Params['local_master_content_data']})}")
        remote_index = ContentData::ContentData.new
        remote_index.from_file(Params['local_master_content_data'])
        remote_ret = Validations::IndexValidations.validate_remote_index remote_index, index
        log.info("Validation result: #{remote_ret}")

        if (email_timestamp_sent == -1 ||
            Time.now.to_i - email_timestamp_sent > Params['email_delay_in_seconds'])
          # Send email.
          log.info("Sending email...")
          msg =<<EOF
Master index ok: #{iv_ret}
Backup index ok: #{local_ret}
Backup includes all master files: #{remote_ret}
EOF
          Email.send_email(Params['from_email'],
                           Params['from_email_password'],
                           Params['to_email'],
                           'Testing server update',
                           msg)
          email_timestamp_sent = Time.now.to_i
        end
        log.info("Done.")
      rescue SystemExit, SignalException, Interrupt => exc
        log.error("Interrupt or Exit happened in testing server: #{exc.class}, stopping process.\nBacktrace:\n#{exc.backtrace.join("\n")}")
        raise
      rescue Exception => exc
        log.error("Exception happened in testing server: #{exc.class}:#{exc.message}, restarting testing loop.\nBacktrace:\n#{exc.backtrace.join("\n")}")
        email_timestamp_sent = -1
      end
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


