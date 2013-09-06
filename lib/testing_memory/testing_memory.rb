require 'log4r'
require 'log'
require 'params'
require 'content_server'
require 'content_server/content_server'  # specific content server impl
require 'content_server/backup_server' # specific backup server impl
require 'content_data'
require 'email'
require 'file_utils/file_generator/file_generator'

# Runs a memory test:
# 1. Run content server or backup server
# 2. Generate files.
# 3. Monitor files.
# 4. Index files.
# 5. Report memory of proces at different phases\times
# Examples:
#   testing_server --conf_file=~/.bbfs/etc/backup_testing_memory.yml --server_to_test=backup
#   testing_server --conf_file=~/.bbfs/etc/content_testing_memory.yml --server_to_test=content

module TestingMemory

  Params.path('testing_log_path', nil, 'Testing server log path.')
  Params.integer('memory_count_delay', 10, 'Memory report cycles in sec.')
  Params.string('testing_title', 'Memory report', 'title to memory report')
  Params.boolean('generate_files', true, 'if true, files will be generated.')
  Params.boolean('send_memory_mail', false, 'if true, email is sent at each memory check cycle')
  Params.integer('memory_mail_period', 5, 'time period [minutes] to send mail with memory reports')

  def init_log4r
    #init log4r
    log_path = Params['testing_log_path']
    unless log_path
      raise("pls specify testing log path through param:'testing_log_path'")
    end
    log_dir = File.dirname(log_path)
    FileUtils.mkdir_p(log_dir) unless File.exists?(log_dir)

    $testing_memory_log = Log4r::Logger.new 'BBFS testing server log'
    $testing_memory_log.trace = true
    formatter = Log4r::PatternFormatter.new(:pattern => "[%d] [%m]")
    #file setup
    file_config = {
        "filename" => Params['testing_log_path'],
        "trunc" => true
    }
    file_outputter = Log4r::FileOutputter.new("testing_log", file_config)
    file_outputter.level = Log4r::INFO
    file_outputter.formatter = formatter
    $testing_memory_log.outputters << file_outputter
  end

  def run_content_memory_server
    $testing_memory_active = true  # this activates debug messages to console

    Log.info('Testing server started')

    #Init log
    init_log4r
    $testing_memory_log.info('Testing server started')

    #create files
    if Params['generate_files']
      total_files = Params['total_created_directories']*Params['total_files_in_dir']
      $testing_memory_log.info("Creating #{total_files} files")
      fg = FileGenerator::FileGenerator.new
      fg.run
      $testing_memory_log.info('Finished creating files')
    end


    # run content
    Thread.new do
      ContentServer.run_content_server
    end

    # run memory report cycles
    check_memory_loop

    raise("code should never reach here")
  end

  def run_backup_memory_server
    $testing_memory_active = true  # this activates debug messages to console

    Log.info('Testing server started')

    #Init log
    init_log4r
    $testing_memory_log.info('Testing server started')

    #create files
    if Params['generate_files']
      total_files = Params['total_created_directories']*Params['total_files_in_dir']
      $testing_memory_log.info("Creating #{total_files} files")
      fg = FileGenerator::FileGenerator.new
      fg.run
      $testing_memory_log.info('Finished creating files')
    end

    # run backup
    Thread.new do
      ContentServer.run_backup_server
    end

    # run memory report cycles
    check_memory_loop

    raise("code should never reach here")
  end

  def check_memory_loop
    start_time = Time.now
    $testing_memory_log.info(Params['testing_title'])
    total_files = Params['total_created_directories']*Params['total_files_in_dir']
    $testing_memory_log.info("Start check all files:#{total_files} are indexed")
    Params.get_init_info_messages.each { |msg|
      $testing_memory_log.info(msg)
    }

    $objects_counters = {}
    email_report = "Memory report: (Title: #{Params['testing_title']})"

    # memory loop
    time_passed = 0
    send_mail_threshold = Params['memory_mail_period']*60
    loop do
      sleep(Params['memory_count_delay'])
      email_report += "\nAt time #{Time.now}\n#{generate_mem_report}"

      #report indexing total time
      if total_files == $indexed_file_count
        stop_time = Time.now
        str = "All files are indexed\nTotal indexing time = #{stop_time.to_i - start_time.to_i}[S]"
        email_report += "\n#{str}"
        $testing_memory_log.info(str)
      end

      # send mail if enabled and time threshold passed
      if Params['send_memory_mail']
        time_passed += Params['memory_count_delay']
        puts "time passed:#{time_passed}  send_mail_threshold=#{send_mail_threshold}"
        if time_passed >= send_mail_threshold
          send_email(email_report)
          time_passed=0
          $testing_memory_log.info("Email report sent to #{Params['to_email']}")
        end
      end

    end
  end

  def generate_mem_report
    report = ""
    unless Gem::win_platform?
      memory_of_process = `ps -o rss= -p #{Process.pid}`.to_i / 1000
      heap_stat = ''
    else

      memory_of_process = `tasklist /FI \"PID eq #{Process.pid}\" /NH /FO \"CSV\"`.split(',')[4]
      heap_stat = "#{GC.stat.dup}\n"
    end
    report += "Process memory:#{memory_of_process}\n"
    report += heap_stat
    report += "indexed files:#{$indexed_file_count}\n"

    current_objects_counters = {}
    # produce all types
    class_enum = ObjectSpace.each_object(Class)
    loop do
      type = class_enum.next rescue break
      current_objects_counters[type] = ObjectSpace.each_object(type).count
    end

    # count each type
    keys_enum = current_objects_counters.each_key
    loop do
      key = keys_enum.next rescue break
      current_val = current_objects_counters[key]
      $objects_counters[key] = 0 unless $objects_counters[key]
      val = $objects_counters[key]
      if  current_val != val
        report += "Type:#{key} count: #{current_val} changed by:#{current_val - val}\n"
      end
      $objects_counters[key] = current_val
    end

    $testing_memory_log.info(report)
    report
  end

  def send_email(report)

    msg =<<EOF
#{report}
EOF
    Email.send_email(Params['from_email'],
                     Params['from_email_password'],
                     Params['to_email'],
                     'Memory server update',
                     msg)
  end

  module_function :run_content_memory_server, :run_backup_memory_server, :init_log4r, :send_email
  module_function :check_memory_loop , :generate_mem_report

end # module TestingServer


