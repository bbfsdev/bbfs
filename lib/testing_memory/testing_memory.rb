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

  def run_content_memory_server
    Log.info('Testing server started')
    init_log4r
    $log4r.info 'Testing server started'
    all_threads = [];

    all_threads << Thread.new do
      ContentServer.run_content_server
    end

    all_threads << Thread.new do
      fg = FileGenerator::FileGenerator.new
      fg.run
    end

    check_memory_loop
    raise("code should never reach here")
  end

  def check_memory_loop
    total_files = Params['total_created_directories']*Params['total_files_in_dir']
    $log4r.info("Start check all files:#{total_files} are indexed")
    email_report = generate_mem_report
    loop {
      sleep(Params['memory_count_delay'])
      email_report += generate_mem_report
      instances_size = $local_dynamic_content_data.last_content_data.instances_size
      email_report += "indexed files:#{instances_size}\n"
      if total_files == instances_size
        email_report += "\nAt this point all files are indexed. No mem changes should occur\n"
        sleep(10)
        email_report += generate_mem_report
        sleep(10)
        email_report += generate_mem_report
        # force write content data to file
        if !$local_dynamic_content_data.nil?
          puts("\nForce writing local content data to #{Params['local_content_data_path']}.")
          $local_dynamic_content_data.last_content_data.to_file($tmp_content_data_file)
          File.rename($tmp_content_data_file, Params['local_content_data_path'])
        end
        $log4r.info('All files have been indexed and written to file. Exiting')
        $log4r.info("Mem Report:\n#{email_report}\n")
        #send_email("Final report:#{email_report}\nprocess memory:#{memory_of_process}\n")
        exit
      end
    }
  end

  def run_backup_memory_server
    Log.info('Testing server started')
    init_log4r
    $log4r.info 'Testing server started'
    all_threads = [];

    all_threads << Thread.new do
      ContentServer.run_backup_server
    end

    all_threads << Thread.new do
      fg = FileGenerator::FileGenerator.new
      fg.run
    end

    check_memory_loop
    raise("code should never reach here")
  end

  def generate_mem_report
    # Generate memory report
    current_objects_counters = {}

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
      report += "Type:#{type} count:#{current_objects_counters[type]}   \n"

    }
    memory_of_process = `ps -o rss= -p #{Process.pid}`.to_i / 1000
    final_report = "Time:#{Time.now}.  Process memory:#{memory_of_process}[M]\nCount report:\n#{report}\n"
    #$log4r.info(final_report)
    final_report
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
  module_function :check_memory_loop, :generate_mem_report

end # module TestingServer


