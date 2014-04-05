# NOTE Code Coverage block must be issued before any of your application code is required
if ENV['BBFS_COVERAGE']
  require_relative '../spec_helper.rb'
  SimpleCov.command_name 'content_data'
end

require 'rspec'
require 'tempfile'
require_relative '../../lib/content_data/content_data.rb'

describe ContentData, ' Performance Test' do

  NUMBER_INSTANCES = 350_000
  MAX_CHECKSUM = NUMBER_INSTANCES
  INSTANCE_SIZE = 1000
  SERVER = "server"
  PATH = "file_"
  MTIME = 1000

  LIMIT_MEMORY = 300*(1024**2)  # 300 MB
  LIMIT_TIME = 5*60;  # 5 minutes

  before :all do
    Params.init Array.new
    Params['print_params_to_stdout'] = false
    # must preced Log.init, otherwise log containing default values will be created
    Params['log_write_to_file'] = false
    Params['log_write_to_console'] = true
    Params['log_debug_level'] = 1  # set it > 0 to enable print-outs of used time/memory
    Log.init
  end

  before :each do
   @msg = String.new
  end

  # Print-out status messages, taken from module variable.
  after :each do
    Log.debug1(@msg) unless (@msg.nil? || @msg.empty?)
  end

  # module variable contains an initialized ContentData
  let (:test_cd) { get_initialized }
  # used to printout messages after tests
  let (:msg) { String.new }

  # Initialize ContentData object with generated instances
  # @return [ContentData] an initialized object
  def get_initialized
    initialized_cd = ContentData::ContentData.new
    NUMBER_INSTANCES.times do |i|
      initialized_cd.add_instance(i.to_s, INSTANCE_SIZE+i, SERVER, PATH + i.to_s, MTIME+i)
    end
    initialized_cd
  end

  class Timer
    # elapsed time in seconds since timer was run or zero
    attr_reader :elapsed_time

    def initialize
      @elapsed_time = 0
    end

    def get_timer_thread(watched_thread)
      Thread.new do
        while (@elapsed_time < LIMIT_TIME && watched_thread.alive?)
          @elapsed_time += 1
          sleep 1
        end
        is_succeeded = true
        if (watched_thread.alive?)
          Thread.kill(watched_thread)
          is_succeeded = false
        end
       @msg = (is_succeeded ? "" : "do not ") + "finished in #{@elapsed_time} seconds"
      end
    end
  end

  class Proc
    # Run a procedure.
    # Terminate it if it is running more then a LIMIT_TIME
    # TODO consider usage of Process::setrlimit(:CPU, LIMIT_TIME) instead
    # @return [Integer] elapsed time
    def call_with_timer
      call_thread = Thread.new { self.call }
      timer = Timer.new
      timer_thread = timer.get_timer_thread(call_thread)
      [call_thread, timer_thread].each { |th| th.join }
      timer.elapsed_time
    end
  end

  module Process
    # @return [boolean] true when process alive, false otherwise
    # @raise [Errno::EPERM] if process owned by other user, and there is no permissions to check
    #   (not our case)
    def Process.alive?(pid)
      begin
        Process.kill(0, pid)
        true
      rescue Errno::ESRCH
        false
      end
    end

    # Get memory consumed my the process
    # @param [Integer] pid, default is current pid
    def Process.get_memory_usage(pid = Process.pid)
      if Gem::win_platform?
        `tasklist /FI \"PID eq #{pid}\" /NH /FO \"CSV\"`.split(',')[4]
      else
        `ps -o rss= -p #{pid}`.to_i
      end
    end
  end

  # Means less than.
  # Added for better readability.
  RSpec::Matchers.define :end_not_later_than_within do |expected|
    match do |actual|
      actual < expected
    end
  end

  # Means less than.
  # Added for better readability.
  RSpec::Matchers.define :consume_less_memory_than do |expected|
    match do |actual|
      actual < expected
    end
  end

  context 'Object initialization' do
    context 'Init one object' do
      it "#{NUMBER_INSTANCES} instances in less then #{LIMIT_TIME} seconds" do
        cd1 = nil
        init_proc = Proc.new { cd1 = get_initialized }
        expect {
          elapsed_time = init_proc.call_with_timer
          puts elapsed_time
          elapsed_time
        }.to end_not_later_than_within LIMIT_TIME

        # checks that test was correct
        cd1 = nil
        cd1.should be
        #cd1.instances_size.should == NUMBER_INSTANCES
        @msg = "FAILED"
        puts "EXIT"
      end

      xit "clone from exist object of #{NUMBER_INSTANCES} in less thes #{LIMIT_TIME} seconds" do
        cd2 = nil
        clone_proc = Proc.new { cd2 = ContentData::ContentData.new(test_cd) }
        clone_proc.call_with_timer.should end_not_later_than_within LIMIT_TIME

        # checks that test
        cd2.should be
        cd2.instances_size.should == test_cd.instances_size
      end
    end

    # Used to check how number of ContentData objects, presented simultaneously in the system,
    # influence the system performence
    context 'Init more then one object' do
      xit "two object of #{NUMBER_INSTANCES} instances each in less then #{2*LIMIT_TIME} seconds" do
        cd1 = nil
        cd2 = nil
        build_proc = Proc.new do
          cd1 = get_initialized
          cd2 = get_initialized
        end
        build_proc.call_with_timer.should end_not_later_than_within 2*LIMIT_TIME

        # checks that test was correct
        cd1.should be
        cd1.instances_size.should == NUMBER_INSTANCES
        cd2.should be
        cd2.instances_size.should == NUMBER_INSTANCES
      end

      xit "three object of #{NUMBER_INSTANCES} instances each in less then #{3*LIMIT_TIME} seconds" do
        cd1 = nil
        cd2 = nil
        cd3 = nil
        build_proc = Proc.new do
          cd1 = get_initialized
          cd2 = get_initialized
          cd3 = get_initialized
        end
        build_proc.call_with_timer.should end_not_later_than_within 3*LIMIT_TIME

        # checks that test was correct
        cd1.should be
        cd1.instances_size.should == NUMBER_INSTANCES
        cd2.should be
        cd2.instances_size.should == NUMBER_INSTANCES
        cd3.should be
        cd3.instances_size.should == NUMBER_INSTANCES
      end
    end
  end

  context 'Iteration' do
    xit "each instance on #{NUMBER_INSTANCES} instances in less then #{LIMIT_TIME}" do
      each_thread = Proc.new { test_cd.each_instance { |ch,_,_,_,_,_,_| ch } }
      each_thread.call_with_timer.should end_not_later_than_within LIMIT_TIME
    end
  end

  context 'File operations' do
    before :all do
      @file = Tempfile.new('to_file_test')
      @path = @file.path
    end

    after :all do
      @file.close!
    end

    xit "save/load on #{NUMBER_INSTANCES} instances in less then #{LIMIT_TIME} seconds" do
      # Checking to_file
      to_file_proc = Proc.new do
        begin
          test_cd.to_file(@path)
        ensure
          @file.close
        end
      end
      to_file_proc.call_with_timer.should end_not_later_than_within LIMIT_TIME

      # checking from_file
      cd2 = ContentData::ContentData.new
      from_file_proc = Proc.new do
        begin
          cd2.from_file(@path)
        ensure
          @file.close
        end
      end
      from_file_proc.call_with_timer.should end_not_later_than_within LIMIT_TIME

      # checks that test was correct
      cd2.instances_size.should == test_cd.instances_size
    end
  end

  describe 'Set operations' do
    before :all do
      @cd2 = get_initialized
      @cd2.add_instance((MAX_CHECKSUM+1).to_s, INSTANCE_SIZE, SERVER, PATH + "new", MTIME)
    end

    context "minus of two objects with #{NUMBER_INSTANCES} instances each" do
      xit "finish in less then #{LIMIT_TIME} seconds" do
        res_cd = nil
        minus_proc = Proc.new { res_cd = ContentData.remove(test_cd, @cd2) }
        minus_proc.call_with_timer.should end_not_later_than_within LIMIT_TIME

        # checks that test was correct
        res_cd.should be
        res_cd.instances_size.should == 1
      end

      xit "(no cloning) finish in less then #{LIMIT_TIME} seconds" do
        res_cd = nil
        minus_proc = Proc.new { res_cd = ContentData.remove_no_cloning(test_cd, @cd2) }
        minus_proc.call_with_timer.should end_not_later_than_within LIMIT_TIME

        # checks that test was correct
        res_cd.should be
        res_cd.instances_size.should == 1
      end

      xit "consume less then #{LIMIT_MEMORY} bytes" do
        res_cd = nil
        memory_of_process = 0
        GC.start
        init_memory_usage = Process.get_memory_usage
        minus_thread = Thread.new { res_cd = ContentData.remove(test_cd, @cd2) }

        Log.debug1("Memory before: #{init_memory_usage}")
        memory_usage_thread = Thread.new do
          Log.debug1("Current: #{Process.pid}")
          begin
            memory_of_process = Process.get_memory_usage - init_memory_usage
            sleep 1
          end while (memory_of_process < LIMIT_MEMORY && minus_thread.alive?)
          if (minus_thread.alive?)
            Thread.kill(minus_thread)
          end
          Log.debug1("memory usage: #{memory_of_process}")
        end
        [minus_thread, memory_usage_thread].each { |th| th.join }
        Log.debug1("Memory after: #{init_memory_usage + memory_of_process}")
        memory_of_process.should < LIMIT_MEMORY

        res_cd.should be
        res_cd.instances_size.should == 1
      end

      xit "(no cloning) consume less then #{LIMIT_MEMORY} bytes" do
        res_cd = nil
        memory_of_process = 0
        GC.start
        init_memory_usage = Process.get_memory_usage
        minus_thread = Thread.new { res_cd = ContentData.remove_no_cloning(test_cd, @cd2) }

        Log.debug1("Memory before: #{init_memory_usage}")
        memory_usage_thread = Thread.new do
          Log.debug1("Current: #{Process.pid}")
          begin
            memory_of_process = Process.get_memory_usage - init_memory_usage
            sleep 1
          end while (memory_of_process < LIMIT_MEMORY && minus_thread.alive?)
          if (minus_thread.alive?)
            Thread.kill(minus_thread)
          end
          Log.debug1("memory usage: #{memory_of_process}")
        end
        [minus_thread, memory_usage_thread].each { |th| th.join }
        Log.debug1("Memory after: #{init_memory_usage + memory_of_process}")
        memory_of_process.should < LIMIT_MEMORY

        res_cd.should be
        res_cd.instances_size.should == 1
      end

      xit "(no cloning, using Process) consume less then #{LIMIT_MEMORY} bytes" do
        GC.start
        minus_pid = Process.fork do
          res_cd = ContentData.remove_no_cloning(test_cd, @cd2)
          res_cd.should be
          res_cd.instances_size.should == 1
          exit(0)
        end
        Process.detach(minus_pid)
        memory_of_process = 0
        init_memory_usage = Process.get_memory_usage(minus_pid)
        cur_memory_usage = init_memory_usage
        Log.debug1("Current: #{Process.pid}")
        Log.debug1("Minus PID: #{minus_pid}")
        Log.debug1("Memory usage before #{init_memory_usage}")
        #is_minus_process_alive = true
        #is_monitoring_failed = false
        begin
          cur_memory_usage = Process.get_memory_usage(minus_pid)
          memory_of_process = cur_memory_usage - init_memory_usage if cur_memory_usage > 0
          sleep 1
        end while (memory_of_process < LIMIT_MEMORY && Process.alive?(minus_pid))

        if (Process.alive?(minus_pid))
          Process.kill(2, minus_pid)
        end

        Log.debug1("Memory usage after: #{cur_memory_usage}")
        Log.debug1("Memory of process: #{memory_of_process}")
        memory_of_process.should < LIMIT_MEMORY
      end

      xit "(no cloning, using Process limit) consume less then #{LIMIT_MEMORY} bytes" do
        #GC.start
        minus_pid = Process.fork do
          Log.debug1("Current: #{Process.pid}")
          puts (Process.getrlimit(:DATA))
          Process.setrlimit(:DATA, 10, 10) #Process.get_memory_usage, Process.get_memory_usage)
          puts (Process.getrlimit(:DATA))
          res_cd = ContentData.remove_no_cloning(test_cd, @cd2)
          res_cd.should be
          res_cd.instances_size.should == 1
          exit(0)
        end
        Process.wait(minus_pid)
        $?.success?.should be_true
      end
    end
  end
end
