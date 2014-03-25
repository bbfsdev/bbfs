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
  MAX_CHECKSUM = NUMBER_INSTANCES  #1000
  INSTANCE_SIZE = 1000
  SERVER = "server"
  PATH = "file_"
  MTIME = 1000

  LIMIT_MEMORY = 100*1024
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
        msg = "ContentData build for #{NUMBER_INSTANCES} " +
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

      xit "from exist object of #{NUMBER_INSTANCES} in less thes #{LIMIT_TIME} seconds" do
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
        msg = "ContentData build for #{NUMBER_INSTANCES} " +
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
      it "Two object each of #{NUMBER_INSTANCES} instances in less then #{2*LIMIT_TIME} seconds" do
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
        msg = "ContentData build for #{NUMBER_INSTANCES} " +
          (is_succeeded ? "" : "do not ") + "finished in #{timer} seconds"

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

  pending 'Set operations' do
    before :all do
      @cd1 = ContentData::ContentData.new
      NUMBER_INSTANCES.times do |i|
        @cd1.add_instance(i.to_s, INSTANCE_SIZE, SERVER, PATH + i.to_s, MTIME)
      end
      @cd2 = ContentData::ContentData.new(@cd1)
      @cd2.add_instance((MAX_CHECKSUM+1).to_s, INSTANCE_SIZE, SERVER, PATH + "new", MTIME)
    end


    pending 'should consume acceptable amount of memory' do
      puts "Memory usage test"

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

    it 'should finish in acceptable time' do
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

      puts msg if is_succeeded
    end
  end
end
