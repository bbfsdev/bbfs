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

  def setup
    sizes = [500, 1000, 1500]
    numb_of_copies = 2
    test_file_name = "test_file"   # file name format: <test_file_name_prefix>.<size>[.serial_number_if_more_then_1]

    FileUtils.rm_rf(RESOURCES_DIR) if (File.exists?(RESOURCES_DIR))

    # prepare files for testing
    cur_dir = nil; # dir where currently files created in this iteration will be placed

    sizes.each do |size|
      file_name = test_file_name + "." + size.to_s

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

      numb_of_copies.times do |i|
        FileUtils.cp(file_path, "#{file_path}.#{i}")
      end
    end
  end

  def test_monitor
    log = File.open(RESOURCES_DIR + "/../log.txt", "w")
    dir_stat = File.lstat(RESOURCES_DIR)
    test_dir = DirStat.new(RESOURCES_DIR, dir_stat.size, dir_stat.mtime.utc)
    FileStat.set_log(log)
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    FileUtils.mv MOVE_DIR_SRC, MOVE_DIR_DEST
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    FileUtils.mv MOVE_FILE_SRC, MOVE_FILE_DEST
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    test_dir.monitor
    puts test_dir.to_s
    log.close
  end
end
