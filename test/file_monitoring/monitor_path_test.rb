require './src/file_monitoring/monitor_path'
require 'test/unit'
require 'fileutils'

class TestPathMonitor < Test::Unit::TestCase
  # directory where tested files will be placed: <application_root_dir>/tests/../resources/time_modification_test
  RESOURCES_DIR = File.expand_path(File.dirname(__FILE__) + "/../../resources/path_monitor_test")
  MOVE_DIR_SRC = RESOURCES_DIR + "/dir1000/dir1500"
  MOVE_DIR_DEST = RESOURCES_DIR
  MOVE_FILE_SRC = RESOURCES_DIR + "/dir1000/test_file.1000"
  MOVE_FILE_DEST = RESOURCES_DIR
  LOG_PATH = RESOURCES_DIR + "/../log.txt"
  #@numb_entities = 0


  def setup
  @sizes = [500, 1000, 1500]
  @numb_of_copies = 2
  @numb_entities = @sizes.size * (@numb_of_copies + 1) + @sizes.size
  @test_file_name = "test_file"   # file name format: <test_file_name_prefix>.<size>[.serial_number_if_more_then_1]
    FileUtils.rm_rf(RESOURCES_DIR) if (File.exists?(RESOURCES_DIR))

    # prepare files for testing
    cur_dir = nil; # dir where currently files created in this iteration will be placed

    @sizes.each do |size|
      file_name = @test_file_name + "." + size.to_s

      if (cur_dir == nil)
        cur_dir = String.new(RESOURCES_DIR)
      else
        cur_dir = cur_dir + "/dir" + size.to_s
      end
      Dir.mkdir(cur_dir) unless (File.exists?(cur_dir))
      raise "Can't create writable working directory: #{cur_dir}" unless (File.exists?(cur_dir) and File.writable?(cur_dir))

      file_path = cur_dir + "/" + file_name
      File.open(file_path, "w") do |file|
        content = Array.new
        size.times do |i|
          content.push(sprintf("%5d ", i))
        end
        file.puts(content)
      end

      @numb_of_copies.times do |i|
        FileUtils.cp(file_path, "#{file_path}.#{i}")
      end
    end
  end

  def test_monitor
    log = File.open(LOG_PATH, "w+")
    dir_stat = File.lstat(RESOURCES_DIR)
    FileStat.set_log(log)
    test_dir = DirStat.new(RESOURCES_DIR, dir_stat.size, dir_stat.mtime.utc)

    # Initial run of monitoring -> initializing DirStat object
    # all found object will be set to NEW state
    # no output to the log
    test_dir.monitor(true)

    log_prev_pos = log.pos
    log_prev_line = log.lineno
    # all files will be set to UNCHANGED
    test_dir.monitor
    sleep(1)
    log_cur_pos = log.pos
    log.pos= log_prev_pos
    log.each_line do |line|
      assert_equal(true, line.include?(FileStatEnum::UNCHANGED))
    end
    log.pos= log_cur_pos
    assert_equal(@numb_entities, log.lineno - log_prev_line)  # checking that all entities were monitored

    # move (equivalent to delete and create new) directory with including files to new location
    FileUtils.mv MOVE_DIR_SRC, MOVE_DIR_DEST
    log_prev_pos = log.pos
    log_prev_line = log.lineno
    test_dir.monitor
    sleep(1)
    log_cur_pos = log.pos
    log.pos= log_prev_pos
    log.each_line do |line|
      assert_not_equal(true, line.include?(FileStatEnum::UNCHANGED))
      assert_equal(true, (line.include?(FileStatEnum::CHANGED) or line.include?(FileStatEnum::NEW)))
    end
    log.pos= log_cur_pos
    # old and new containing directories: 2
    # moved directory: 1
    # moved files: @numb_of_copies + 1
    assert_equal(2 + 1 + @numb_of_copies + 1, log.lineno - log_prev_line)  # checking that only  MOVE_DIR_SRC, MOVE_DIR_DEST states were changed

    # no changes:
    # changed and new files moved to UNCHANGED
    log_prev_pos = log.pos
    log_prev_line = log.lineno
    test_dir.monitor
    sleep(1)
    log_cur_pos = log.pos
    log.pos= log_prev_pos
    log.each_line do |line|
      assert_equal(true, line.include?(FileStatEnum::UNCHANGED))
    end
    log.pos= log_cur_pos
    assert_equal(2 + 1 + @numb_of_copies + 1, log.lineno - log_prev_line)

    log_prev_pos = log.pos
    log_prev_line = log.lineno
    # move (equivalent to delete and create new) file
    FileUtils.mv MOVE_FILE_SRC, MOVE_FILE_DEST
    test_dir.monitor
    sleep(1)
    log_cur_pos = log.pos
    log.pos= log_prev_pos
    log.each_line do |line|
      #
    end
    log.pos= log_cur_pos
    assert_equal(3, log.lineno - log_prev_line)

    # all files were moved to UNCHANGED
    test_dir.monitor

    # check that all entities moved to stable
    log_prev_pos = log.pos
    log_prev_line = log.lineno
    last_changed_dir_stable = test_dir.get_dir(File.dirname(MOVE_FILE_SRC)).stable_state
    (last_changed_dir_stable + 1).times do
      test_dir.monitor
      #puts test_dir.to_s
    end
    sleep(1)
    log_cur_pos = log.pos
    log.pos= log_prev_pos
    log.each_line do |line|
      puts line unless (line.include?(FileStatEnum::STABLE))
      assert_equal(true, line.include?(FileStatEnum::STABLE))
    end
    log.pos= log_cur_pos
    assert_equal(@numb_entities, log.lineno - log_prev_line)
    log.close
  end
end
