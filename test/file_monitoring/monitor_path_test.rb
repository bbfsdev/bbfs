require './lib/file_monitoring/monitor_path'
require 'test/unit'
require 'fileutils'

module FileMonitoring
  module Test
    class TestPathMonitor < ::Test::Unit::TestCase
      # directory where tested files will be placed: __FILE__/time_modification_test
      RESOURCES_DIR = File.expand_path(File.dirname(__FILE__) + '/path_monitor_test')
      MOVE_DIR = '/dir1500' # directory that will be moved
      MOVE_FILE = '/test_file.1000' # file that will be moved
      MOVE_SRC_DIR = RESOURCES_DIR + '/dir1000' # directory where moved entities where placed
      MOVE_DEST_DIR = RESOURCES_DIR # directory where moved entities will be placed
      LOG_PATH = RESOURCES_DIR + '/../log.txt'

      def setup
        @sizes = [500, 1000, 1500]
        @numb_of_copies = 2
        @numb_entities = @sizes.size * (@numb_of_copies + 1) + @sizes.size
        @test_file_name = 'test_file'   # file name format: <test_file_name_prefix>.<size>[.serial_number_if_more_then_1]
        @test_dir_name = 'dir'
        ::FileUtils.rm_rf(RESOURCES_DIR) if (File.exists?(RESOURCES_DIR))

        # prepare files for testing
        cur_dir = nil; # directory where currently files created in this iteration will be placed

        @sizes.each do |size|
          file_name = @test_file_name + '.' + size.to_s

          if (cur_dir == nil)
            cur_dir = String.new(RESOURCES_DIR)
          else
            cur_dir = cur_dir + "/#{@test_dir_name}" + size.to_s
          end
          Dir.mkdir(cur_dir) unless (File.exists?(cur_dir))
          raise "Can't create writable working directory: #{cur_dir}" unless (File.exists?(cur_dir) and File.writable?(cur_dir))

          file_path = cur_dir + '/' + file_name
          File.open(file_path, 'w') do |file|
            content = Array.new
            size.times do |i|
              content.push(sprintf('%5d ', i))
            end
            file.puts(content)
          end

          @numb_of_copies.times do |i|
            ::FileUtils.cp(file_path, "#{file_path}.#{i}")
          end
        end
      end

      def test_monitor
        log = File.open(LOG_PATH, 'w+')
        FileStat.set_log(log)
        test_dir = DirStat.new(RESOURCES_DIR)

        # Initial run of monitoring -> initializing DirStat object
        # all found object will be set to NEW state
        # no output to the log
        test_dir.monitor

        # all files will be set to UNCHANGED
        log_prev_pos = log.pos
        log_prev_line = log.lineno
        test_dir.monitor
        sleep(1) # to be sure that data was indeed written
        log.pos= log_prev_pos
        log.each_line do |line|
          assert_equal(true, line.include?(FileStatEnum::UNCHANGED))
        end
        assert_equal(@numb_entities, log.lineno - log_prev_line)  # checking that all entities were monitored

        # move (equivalent to delete and create new) directory with including files to new location
        ::FileUtils.mv MOVE_SRC_DIR + MOVE_DIR, MOVE_DEST_DIR + MOVE_DIR
        log_prev_pos = log.pos
        log_prev_line = log.lineno
        test_dir.monitor
        sleep(1)
        log.pos= log_prev_pos
        log.each_line do |line|
          if (line.include?(MOVE_SRC_DIR + MOVE_DIR))
            assert_equal(true, line.include?(FileStatEnum::NON_EXISTING))
          elsif (line.include?(MOVE_DEST_DIR + MOVE_DIR))
            assert_equal(true, line.include?(FileStatEnum::NEW))
          elsif (line.include?(MOVE_SRC_DIR) or line.include?(MOVE_DEST_DIR))
            assert_not_equal(true, line.include?(FileStatEnum::UNCHANGED))
            assert_equal(true, line.include?(FileStatEnum::CHANGED))
          end
        end
        # old and new containing directories: 2
        # moved directory: 1
        # deleted directory: 1
        # moved files: @numb_of_copies + 1
        assert_equal(5 + @numb_of_copies, log.lineno - log_prev_line)  # checking that only  MOVE_DIR_SRC, MOVE_DIR_DEST states were changed

        # no changes:
        # changed and new files moved to UNCHANGED
        log_prev_pos = log.pos
        log_prev_line = log.lineno
        test_dir.monitor
        sleep(1)
        log.pos= log_prev_pos
        log.each_line do |line|
          assert_equal(true, line.include?(FileStatEnum::UNCHANGED))
        end
        # old and new containing directories: 2
        # moved directory: 1
        # moved files: @numb_of_copies + 1
        assert_equal(4 + @numb_of_copies, log.lineno - log_prev_line)

        # move (equivalent to delete and create new) file
        log_prev_pos = log.pos
        log_prev_line = log.lineno
        ::FileUtils.mv MOVE_SRC_DIR + MOVE_FILE, MOVE_DEST_DIR + MOVE_FILE
        test_dir.monitor
        sleep(1)
        log.pos= log_prev_pos
        log.each_line do |line|
          if (line.include?MOVE_SRC_DIR + MOVE_FILE)
            assert_equal(true, line.include?(FileStatEnum::NON_EXISTING))
          elsif (line.include?MOVE_DEST_DIR + MOVE_FILE)
            assert_equal(true, line.include?(FileStatEnum::NEW))
          elsif (line.include?MOVE_SRC_DIR or line.include?MOVE_DEST_DIR)
            assert_equal(true, line.include?(FileStatEnum::CHANGED))
          end
        end
        # old and new containing directories: 2
        # removed file: 1
        # new file: 1
        assert_equal(4, log.lineno - log_prev_line)

        # all files were moved to UNCHANGED
        test_dir.monitor

        # check that all entities moved to stable
        log_prev_pos = log.pos
        log_prev_line = log.lineno
        (test_dir.stable_state + 1).times do
          test_dir.monitor
        end
        sleep(1)
        log.pos= log_prev_pos
        log.each_line do |line|
          assert_equal(true, line.include?(FileStatEnum::STABLE))
        end
        assert_equal(@numb_entities, log.lineno - log_prev_line)

        log.close
      end
    end
  end
end
