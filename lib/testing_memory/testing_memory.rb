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


    # run backup
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
    $objects_max_counters = {}
    email_report = generate_mem_report

    # memory loop
    loop {
      sleep(Params['memory_count_delay'])
      email_report += generate_mem_report
      email_report += "indexed files:#{$indexed_file_count}\n"
      $testing_memory_log.info("indexed files:#{$indexed_file_count}")
      puts("indexed files:#{$indexed_file_count}")
      #puts("symobles size:#{Symbol.all_symbols.size}")
      if total_files == $indexed_file_count
        stop_time = Time.now
        email_report += "\nAt this point all files are indexed. No mem changes should occur\n"
        $testing_memory_log.info("Total indexing time = #{stop_time.to_i - start_time.to_i}[S]")
        $testing_memory_log.info("\nAt this point all files are indexed. No mem changes should occur\n")
        loop {
          sleep(Params['memory_count_delay'])
          email_report += generate_mem_report
          $testing_memory_log.info("indexed files:#{$indexed_file_count}")
          puts("indexed files:#{$indexed_file_count}")
        }
        #send_email("Final report:#{email_report}\nprocess memory:#{memory_of_process}\n")
      end
    }
  end

  def generate_mem_report
    # Generate memory report
    current_objects_counters = {}

    count = ObjectSpace.each_object(String).count
    current_objects_counters[String] = count
    count = ObjectSpace.each_object(Integer).count
    current_objects_counters[Integer] = count
    count = ObjectSpace.each_object(Hash).count
    current_objects_counters[Hash] = count
    count = ObjectSpace.each_object(Array).count
    current_objects_counters[Array] = count


    count = ObjectSpace.each_object(ContentData::ContentData).count
    current_objects_counters[ContentData::ContentData] = count
    dir_count = ObjectSpace.each_object(FileMonitoring::DirStat).count
    current_objects_counters[FileMonitoring::DirStat] = dir_count
    file_count = ObjectSpace.each_object(FileMonitoring::FileStat).count
    current_objects_counters[FileMonitoring::FileStat] = file_count-dir_count


    current_objects_counters[IO] = count
    count = ObjectSpace.each_object(IO).count
    current_objects_counters[File] = count
    count = ObjectSpace.each_object(File).count
    count = ObjectSpace.each_object(File::Stat).count
    current_objects_counters[File::Stat] = count
    count = ObjectSpace.each_object(Digest::SHA1).count
    current_objects_counters[Digest::SHA1] = count


    #ObjectSpace.each_object(Class) { |t|
    #  current_objects_counters[t] = ObjectSpace.each_object(t).count
    #}
    report = ""
    current_objects_counters.each_key { |key|
      current_val = current_objects_counters[key]
      val = $objects_max_counters[key]
      if val
        if  val < current_val
          report += "Type:#{key} raised by:#{current_val - val}. Max Count:#{current_val}  \n"
          $objects_max_counters[key] = current_val
        else
          report += "Type:#{key} Count:#{current_val}  \n"
        end
      else
        $objects_max_counters[key] = current_val
        report += "Type:#{key} Initial Count:#{current_val}  \n"
      end
    }

    # Generate report and update global counters
    #report = ""
    #current_objects_counters.each_key { |type|
    #  report += "Type:#{type} count:#{current_objects_counters[type]}   \n"
    #}
    unless Gem::win_platform?
      memory_of_process = `ps -o rss= -p #{Process.pid}`.to_i / 1000
    else
      memory_of_process = `tasklist /FI \"PID eq #{Process.pid}\" /NH /FO \"CSV\"`.split(',')[4]
    end
    final_report = "Time:#{Time.now}.  Process memory:#{memory_of_process}[M]\nCount report:\n#{report}"
    puts "Process memory:#{memory_of_process}[M]"
    $testing_memory_log.info(final_report)
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


