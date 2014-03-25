# NOTE Code Coverage block must be issued before any of your application code is required
if ENV['BBFS_COVERAGE']
  require_relative '../spec_helper.rb'
  SimpleCov.command_name 'content_data'
end

require 'rspec'
require 'tempfile'
#require 'random'
require_relative '../../lib/content_data/content_data.rb'

describe 'Content Data Performance Test' do

  NUMBER_INSTANCES = 350_000
  MAX_CHECKSUM = NUMBER_INSTANCES
  INSTANCE_SIZE = 1000
  SERVER = "server"
  PATH = "file_"
  MTIME = 1000

  LIMIT_MEMORY = 1024**3  # 1 GB
  LIMIT_TIME = 10*60;  # 10 minutes

  before :all do
    Params.init Array.new
    Params['print_params_to_stdout'] = false
    # must preced Log.init, otherwise log containing default values will be created
    Params['log_write_to_file'] = false
    Params['log_write_to_console'] = true
    Params['log_debug_level'] = 1  # set it > 0 to enable print-outs of used time/memory
    Log.init
  end

  class TimerThread
    def initialize
      @timer = 0
    end

    def get_timer_thread(watched_thread)
      Thread.new do
        while (@timer < LIMIT_TIME && watched_thread.alive?)
          @timer += 1
          sleep 1
        end
        if (watched_thread.alive?)
          Thread.kill(watched_thread)
        end
      end
    end

    # @return [Integer] elapsed time in seconds since timer was run or zero
    def get_elapsed_time
      @timer.to_i
    end
  end

  context 'Object initialization' do
    context 'Init one object' do
      it "#{NUMBER_INSTANCES} instances in less then #{LIMIT_TIME} seconds" do
        cd1 = nil
        build_thread = Thread.new do
          cd1 = ContentData::ContentData.new
          NUMBER_INSTANCES.times do |i|
            cd1.add_instance(i.to_s, INSTANCE_SIZE, SERVER, PATH + i.to_s, MTIME)
          end
        end

        timer = 0
        timer_thread = Thread.new do
          while (timer < LIMIT_TIME && build_thread.alive?)
            timer += 1
            sleep 1
          end
          if (build_thread.alive?)
            Thread.kill(build_thread)
          end
        end
        [build_thread, timer_thread].each { |th| th.join }

        is_succeeded = timer < LIMIT_TIME
        msg = "ContentData init for #{NUMBER_INSTANCES} " +
          (is_succeeded ? "" : "do not ") + "finished in #{timer} seconds"

        # main check
        #timer.should be < LIMIT_TIME, msg
        is_succeeded.should be_true

        # checks that test was correct
        if is_succeeded
          cd1.should be
          cd1.instances_size.should == NUMBER_INSTANCES
        end
        Log.debug1(msg)
      end

      it "from exist object of #{NUMBER_INSTANCES} in less thes #{LIMIT_TIME} seconds" do
        cd1 = ContentData::ContentData.new
        NUMBER_INSTANCES.times do |i|
          cd1.add_instance(i.to_s, INSTANCE_SIZE, SERVER, PATH + i.to_s, MTIME)
        end
        cd2 = nil
        init_thread = Thread.new { cd2 = ContentData::ContentData.new(cd1) }

        timer = 0
        timer_thread = Thread.new do
          while (timer < LIMIT_TIME && init_thread.alive?)
            timer += 1
            sleep 1
          end
          if (init_thread.alive?)
            Thread.kill(init_thread)
          end
        end
        [init_thread, timer_thread].each { |th| th.join }

        is_succeeded = timer < LIMIT_TIME
        msg = "ContentData init from exist object of #{NUMBER_INSTANCES} instances " +
          (is_succeeded ? "" : "do not ") + "finished in #{timer} seconds"

        # main check
        #timer.should be < LIMIT_TIME, msg
        is_succeeded.should be_true

        # checks that test was correct
        if is_succeeded
          cd2.should be
          cd2.instances_size.should == NUMBER_INSTANCES
        end

        Log.debug1(msg)
      end
    end

    context 'Init more then one object' do
      it "two object each of #{NUMBER_INSTANCES} instances in less then #{2*LIMIT_TIME} seconds" do
        cd1 = nil
        cd2 = nil
        build_thread = Thread.new do
          cd1 = ContentData::ContentData.new
          NUMBER_INSTANCES.times do |i|
            cd1.add_instance(i.to_s, INSTANCE_SIZE, SERVER, PATH + i.to_s, MTIME)
          end
          cd2 = ContentData::ContentData.new
          NUMBER_INSTANCES.times do |i|
            cd2.add_instance(i.to_s, INSTANCE_SIZE, SERVER, PATH + i.to_s, MTIME)
          end
        end

        timer = 0
        timer_thread = Thread.new do
          while (timer < LIMIT_TIME && build_thread.alive?)
            timer += 1
            sleep 1
          end
          if (build_thread.alive?)
            Thread.kill(build_thread)
          end
        end
        [build_thread, timer_thread].each { |th| th.join }

        is_succeeded = timer < LIMIT_TIME
        msg = "Init of 2 ContentData of #{NUMBER_INSTANCES} instances each " +
          (is_succeeded ? "" : "not ") + "finished in #{timer} seconds"

        # main check
        #timer.should be < LIMIT_TIME, msg
        is_succeeded.should be_true

        # checks that test was correct
        if is_succeeded
          cd1.should be
          cd1.instances_size.should == NUMBER_INSTANCES
          cd2.should be
          cd2.instances_size.should == NUMBER_INSTANCES
        end

        Log.debug1(msg)
      end
    end
  end

  context 'File operations' do
    before :all do
      @cd1 = ContentData::ContentData.new
      NUMBER_INSTANCES.times do |i|
        @cd1.add_instance(i.to_s, INSTANCE_SIZE, SERVER, PATH + i.to_s, MTIME)
      end
      @file = Tempfile.new('to_file_test')
    end

    after :all do
      @file.close!
    end

    it "save/load on #{NUMBER_INSTANCES} instances in less then #{LIMIT_TIME} seconds" do
      # Checking to_file
      timer = 0
      begin
        to_file_thread = Thread.new do
          path = @file.path
          @cd1.to_file(path)
        end

        timer_thread = Thread.new do
          while (timer < LIMIT_TIME && to_file_thread.alive?)
            timer += 1
            sleep 1
          end
          if (to_file_thread.alive?)
            Thread.kill(to_file_thread)
          end
        end
        [to_file_thread, timer_thread].each { |th| th.join }
      ensure
        @file.close
      end

      is_succeeded = timer < LIMIT_TIME
      msg = "To file for #{NUMBER_INSTANCES} " +
        (is_succeeded ? "" : "do not ") + "finished in #{timer} seconds"

      # main check
      #timer.should be < LIMIT_TIME, msg
      is_succeeded.should be_true
      Log.debug1(msg)

      # checking from_file
      timer = TimerThread.new
      cd2 = ContentData::ContentData.new
      begin
        from_file_thread = Thread.new do
          path = @file.path
          cd2.from_file(path)
        end


        timer_thread = timer.get_timer_thread()
        [from_file_thread, timer_thread].each { |th| th.join }
      ensure
        @file.close
      end

      is_succeeded = timer.get_elapsed_time < LIMIT_TIME
      msg = "From file for #{NUMBER_INSTANCES} " +
        (is_succeeded ? "" : "do not ") + "finished in #{timer.get_elapsed_time} seconds"

      # main check
      #timer.should be < LIMIT_TIME, msg
      is_succeeded.should be_true

      # checks that test was correct
      if is_succeeded
        @cd1.instances_size.should == cd2.instances_size
      end

      Log.debug1(msg)

    end
  end

  context 'Set operations' do
    before :all do
      @cd1 = ContentData::ContentData.new
      NUMBER_INSTANCES.times do |i|
        @cd1.add_instance(i.to_s, INSTANCE_SIZE, SERVER, PATH + i.to_s, MTIME)
      end
      @cd2 = ContentData::ContentData.new
      NUMBER_INSTANCES.times do |i|
        @cd2.add_instance(i.to_s, INSTANCE_SIZE, SERVER, PATH + i.to_s, MTIME)
      end
      @cd2.add_instance((MAX_CHECKSUM+1).to_s, INSTANCE_SIZE, SERVER, PATH + "new", MTIME)
    end

    context "minus of two objects with #{NUMBER_INSTANCES} instances each" do
      it "finish in less then #{LIMIT_TIME} seconds" do
        res_cd = nil
        minus_thread = Thread.new { res_cd = ContentData.remove(@cd1, @cd2) }

        timer = 0
        timer_thread = Thread.new do
          while (timer < LIMIT_TIME && minus_thread.alive?)
            timer += 1
            sleep 1
          end
          if (minus_thread.alive?)
            Thread.kill(minus_thread)
          end
        end
        [minus_thread, timer_thread].each { |th| th.join }

        is_succeeded = timer < LIMIT_TIME
        msg = "ContentData minus for #{NUMBER_INSTANCES} " +
          (is_succeeded ? "" : "do not ") + "finished in #{timer} seconds"

        # main check
        #timer.should be < LIMIT_TIME, msg
        is_succeeded.should be_true

        # checks that test was correct
        if is_succeeded
          res_cd.should be
          res_cd.instances_size.should == 1
        end

        Log.debug1(msg)
      end

      pending "consume less then #{LIMIT_MEMORY} bytes" do

        minus_thread = Thread.new { res_cd = ContentData.remove(@cd1, @cd2) }

        memory_of_process = 0
        memory_usage_thread = Thread.new do
          while (memory_of_process < LIMIT_MEMORY && minus_thread.alive?)
            memory_of_process = if Gem::win_platform?
                                  `tasklist /FI \"PID eq #{Process.pid}\" /NH /FO \"CSV\"`.split(',')[4]
                                else
                                  `ps -o rss= -p #{Process.pid}`.to_i / 1000
                                end
            puts Process.pid + " => " + memory_of_process
            sleep 1
          end
          if (minus_thread.alive?)
            Thread.kill(minus_thread)
          end
        end

        is_succeeded = memory_of_process
        msg = "ContentData minus for #{NUMBER_INSTANCES} " +
          (is_succeeded ? "" : "do not ") + "consume #{memory_of_process} bytes"

        # main check
        #timer.should be < LIMIT_TIME, msg
        is_succeeded.should be_true
        puts msg if is_succeeded

        # checks that test was correct
        if is_succeeded
          res_cd.should be
          res_cd.instances_size.should == 1
        end
      end
    end
  end
end
