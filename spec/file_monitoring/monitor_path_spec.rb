# NOTE Code Coverage block must be issued before any of your application code is required
if ENV['BBFS_COVERAGE']
  require_relative '../spec_helper.rb'
  SimpleCov.command_name 'file_monitoring'
end
require './lib/file_monitoring/monitor_path'
require 'rspec'
require 'fileutils'

module FileMonitoring
  module Spec

    describe 'monitoring' do

      # disabling log before running 'all' tests
      before :all do
        DirStat.set_log(nil)
      end

      # Test will create a monitoring directory.
      # Test will setup dummy files for glob.
      #   1st file is a regular file. 2nd file is a symlink file.
      # Test will check that regular file added to dir
      # Test will check the symlink file was ignored (not added to dir)
      it 'should ignore symlink files during monitoring' do

        # create the directory
        dir_stat = DirStat.new('temp_path')

        # define stubs for: glob, symlink checks and file status object(lstat).
        Dir.stub(:glob).with('temp_path/*').and_return(['regular_file','symlink_file'])
        File.stub(:symlink?).with('regular_file').and_return(false)
        File.stub(:symlink?).with('symlink_file').and_return(true)
        return_lstat = File.lstat(__FILE__)
        File.stub(:lstat).with(any_args).and_return(return_lstat)

        # Perform monitoring
        dir_stat.monitor

        # check that 'regular_file' was added to Dir
        dir_stat.instance_eval{@files}['regular_file'].nil?.should be(false)
        # check that 'symlink_file' was ignored( not added to Dir)
        dir_stat.instance_eval{@files}['symlink_file'].nil?.should be(true)

      end
    end

    describe 'Path Monitor Test' do
      # directory where tested files will be placed: __FILE__/time_modification_test
      RESOURCES_DIR = File.expand_path(File.dirname(__FILE__) + '/path_monitor_test')
      MOVE_DIR = '/dir1500' # directory that will be moved
      MOVE_FILE = '/test_file.1000' # file that will be moved
      MOVE_SRC_DIR = RESOURCES_DIR + '/dir1000' # directory where moved entities where placed
      MOVE_DEST_DIR = RESOURCES_DIR # directory where moved entities will be placed
      LOG_PATH = RESOURCES_DIR + '/../log.txt'

      # simulates log4r activuty used by FileMonitoring
      class LogMock
        def initialize()
          File.unlink(LOG_PATH) if File.exists?(LOG_PATH)
          @log = File.open(LOG_PATH, 'w+')
        end

        def close()
          @log.close()
        end

        def outputters()
          [self];
        end

        def flush()
          # Do nothing
        end

        def log()
          @log
        end

        def info(str)
          @log.puts(str)
        end
      end

      before :all do
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

        @log4r_mock = LogMock.new
      end

      after :all do
        @log4r_mock.close
        File.unlink(LOG_PATH)
        ::FileUtils.rm_rf(RESOURCES_DIR) if (File.exists?(RESOURCES_DIR))
      end

=begin [yarondbb] test needs to be refactored
      it 'test monitor' do
        log = @log4r_mock.log
        FileStat.set_log(@log4r_mock)
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
          line.include?(FileStatEnum::UNCHANGED).should == true
        end
        log.lineno - log_prev_line.should == @numb_entities  # checking that all entities were monitored

        # move (equivalent to delete and create new) directory with including files to new location
        ::FileUtils.mv MOVE_SRC_DIR + MOVE_DIR, MOVE_DEST_DIR + MOVE_DIR
        log_prev_pos = log.pos
        log_prev_line = log.lineno
        test_dir.monitor
        sleep(1)
        log.pos= log_prev_pos
        log.each_line do |line|
          if (line.include?(MOVE_SRC_DIR + MOVE_DIR))
            line.include?(FileStatEnum::NON_EXISTING).should == true
          elsif (line.include?(MOVE_DEST_DIR + MOVE_DIR))
            line.include?(FileStatEnum::NEW).should == true
          elsif (line.include?(MOVE_SRC_DIR) or line.include?(MOVE_DEST_DIR))
             line.include?(FileStatEnum::UNCHANGED).should_not == true
            line.include?(FileStatEnum::CHANGED).should == true
          end
        end
        # old and new containing directories: 2
        # moved directory: 1
        # deleted directory: 1
        # moved files: @numb_of_copies + 1
        log.lineno - log_prev_line.should == 5 + @numb_of_copies  # checking that only  MOVE_DIR_SRC, MOVE_DIR_DEST states were changed

        # no changes:
        # changed and new files moved to UNCHANGED
        log_prev_pos = log.pos
        log_prev_line = log.lineno
        test_dir.monitor
        sleep(1)
        log.pos= log_prev_pos
        log.each_line do |line|
          line.include?(FileStatEnum::UNCHANGED).should == true
        end
        # old and new containing directories: 2
        # moved directory: 1
        # moved files: @numb_of_copies + 1
        log.lineno - log_prev_line.should == 4 + @numb_of_copies

        # move (equivalent to delete and create new) file
        log_prev_pos = log.pos
        log_prev_line = log.lineno
        ::FileUtils.mv MOVE_SRC_DIR + MOVE_FILE, MOVE_DEST_DIR + MOVE_FILE
        test_dir.monitor
        sleep(1)
        log.pos= log_prev_pos
        log.each_line do |line|
          if (line.include?MOVE_SRC_DIR + MOVE_FILE)
            line.include?(FileStatEnum::NON_EXISTING).should == true
          elsif (line.include?MOVE_DEST_DIR + MOVE_FILE)
            line.include?(FileStatEnum::NEW).should == true
          elsif (line.include?MOVE_SRC_DIR or line.include?MOVE_DEST_DIR)
            line.include?(FileStatEnum::CHANGED).should == true
          end
        end
        # old and new containing directories: 2
        # removed file: 1
        # new file: 1
        log.lineno - log_prev_line.should == 4

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
          line.include?(FileStatEnum::STABLE).should == true
        end
        log.lineno - log_prev_line.should == @numb_entities
      end
=end
    end
  end
end
