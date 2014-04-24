# NOTE Code Coverage block must be issued before any of your application code is required
if ENV['BBFS_COVERAGE']
  require_relative '../spec_helper.rb'
  SimpleCov.command_name 'content_data'
end

require 'rspec'
require 'tempfile'
require_relative '../../lib/content_data/content_data.rb'

# NOTE the results are not exact cause they do not run in a clean environment and influenced from
# monitoring/testing code, but they give a good approximation
# Supposition: monitoring code penalty is insignificant against time/memory usage of the tested code
describe 'Content Data Performance Test', :perf =>true do

  NUMBER_INSTANCES = 350_000
  MAX_CHECKSUM = NUMBER_INSTANCES
  INSTANCE_SIZE = 1000
  SERVER = "server"
  PATH = "file_"
  MTIME = 1000

  # in kilobytes
  LIMIT_MEMORY = 250*(1024)  # 250 MB
  # in seconds
  LIMIT_TIME = 5*60;  # 5 minutes

  before :all do
    Params.init Array.new
    Params['print_params_to_stdout'] = false
    # must preced Log.init, otherwise log containing default values will be created
    Params['log_write_to_file'] = false
    Params['log_write_to_console'] = true
    Params['log_debug_level'] = 1  # set it > 0 to enable print-outs of used time/memory
    Log.init

    # module variable contains an initialized ContentData
    @test_cd = get_initialized
  end

  let (:terminator) { Limit.new(LIMIT_TIME, LIMIT_MEMORY) }

  # Print-out status messages
  after :each do
    unless (terminator.nil?)
      Log.debug1("#{self.class.description} #{example.description}: #{terminator.msg}")
    end
    GC.start
  end

  # Initialize ContentData object with generated instances
  # @return [ContentData] an initialized object
  def get_initialized
    initialized_cd = ContentData::ContentData.new
    NUMBER_INSTANCES.times do |i|
      initialized_cd.add_instance(i.to_s, INSTANCE_SIZE+i, SERVER, PATH + i.to_s, MTIME+i)
    end
    initialized_cd
  end

  # TODO consider to separate it to 2 derived classes: one for memory, one for time monitoring
  class Limit
    attr_reader :elapsed_time, :memory_usage, :msg

    def initialize(time_limit, memory_limit)
      @elapsed_time = 0
      @memory_usage = 0
      @msg = String.new
      @time_limit = time_limit
      @memory_limit = memory_limit
    end

    def get_timer_thread(watched_thread)
      Thread.new do
        while (@elapsed_time < @time_limit && watched_thread.alive?)
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

    def get_memory_limit_thread(watched_thread)
      Thread.new do
        init_memory_usage = Process.get_memory_usage
        while (@memory_usage < @memory_limit && watched_thread.alive?)
          cur_memory_usage = Process.get_memory_usage - init_memory_usage
          if (cur_memory_usage > @memory_usage)
            @memory_usage = cur_memory_usage
          end
          sleep 1
        end
        if (watched_thread.alive?)
          Thread.kill(watched_thread)
        end
        @msg = "memory usage: #{@memory_usage}"
      end
    end
  end

  # TODO consider more general public method call_with_limit
  class Proc
    # Run a procedure.
    # Terminate it if it is running more then a time limit
    # TODO consider usage of Process::setrlimit
    # @param [Limit] limit object
    def call_with_timer(limit)
      call_thread = Thread.new { self.call }
      limit_thread = limit.get_timer_thread(call_thread)
      [call_thread, limit_thread].each { |th| th.join }
    end

    # Run a procedure.
    # Terminate it if it is running more then a memory limit
    # TODO consider usage of Process::setrlimit
    # @param [Limit] limit object
    def call_with_memory_limit(limit)
      call_thread = Thread.new { self.call }
      limit_thread = limit.get_memory_limit_thread(call_thread)
      [call_thread, limit_thread].each { |th| th.join }
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
    # @return [Integer] memory usage in kilobytes
    def Process.get_memory_usage(pid = Process.pid)
      if Gem::win_platform?
        `tasklist /FI \"PID eq #{pid}\" /NH /FO \"CSV\"`.split(',')[4]
      else
        `ps -o rss= -p #{pid}`.to_i
      end
    end
  end

  context 'Object initialization' do
    context 'Init one object' do
      it "#{NUMBER_INSTANCES} instances in less then #{LIMIT_TIME} seconds" do
        cd1 = nil
        init_proc = Proc.new { cd1 = get_initialized }
        init_proc.call_with_timer(terminator)
        terminator.elapsed_time.should < LIMIT_TIME

        # checks that test was correct
        cd1.should be
        cd1.instances_size.should == NUMBER_INSTANCES
      end

      it "#{NUMBER_INSTANCES} instances consumes less then #{LIMIT_MEMORY} KB" do
        cd1 = nil
        init_proc = Proc.new { cd1 = get_initialized }
        init_proc.call_with_memory_limit(terminator)
        terminator.memory_usage.should < LIMIT_MEMORY

        # checks that test was correct
        cd1.should be
        cd1.instances_size.should == NUMBER_INSTANCES
      end

      it "clone of #{NUMBER_INSTANCES} in less then #{LIMIT_TIME} seconds" do
        cd2 = nil
        clone_proc = Proc.new { cd2 = ContentData::ContentData.new(@test_cd) }
        clone_proc.call_with_timer(terminator)
        terminator.elapsed_time.should < LIMIT_TIME

        # checks that test
        cd2.should be
        cd2.instances_size.should == @test_cd.instances_size
      end

      it "clone of #{NUMBER_INSTANCES} consumes less then #{LIMIT_MEMORY} KB" do
        cd2 = nil
        clone_proc = Proc.new { cd2 = ContentData::ContentData.new(@test_cd) }
        clone_proc.call_with_memory_limit(terminator)
        terminator.memory_usage.should < LIMIT_MEMORY

        # checks that test was correct
        cd2.should be
        cd2.instances_size.should == @test_cd.instances_size
      end
    end


    context 'Init more then one object' do
      it "two object of #{NUMBER_INSTANCES} instances each in less then #{2*LIMIT_TIME} seconds" do
        cd1 = nil
        cd2 = nil
        build_proc = Proc.new do
          cd1 = get_initialized
          cd2 = get_initialized
        end
        build_proc.call_with_timer(terminator)
        terminator.elapsed_time.should < LIMIT_TIME

        # checks that test was correct
        cd1.should be
        cd1.instances_size.should == NUMBER_INSTANCES
        cd2.should be
        cd2.instances_size.should == NUMBER_INSTANCES
      end

      it "three object of #{NUMBER_INSTANCES} instances each in less then #{3*LIMIT_TIME} seconds" do
        cd1 = nil
        cd2 = nil
        cd3 = nil
        build_proc = Proc.new do
          cd1 = get_initialized
          cd2 = get_initialized
          cd3 = get_initialized
        end
        build_proc.call_with_timer(terminator)
        terminator.elapsed_time.should < LIMIT_TIME

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
    it "each instance on #{NUMBER_INSTANCES} instances in less then #{LIMIT_TIME}" do
      each_thread = Proc.new { @test_cd.each_instance { |ch,_,_,_,_,_,_| ch } }
      each_thread.call_with_timer(terminator)
      terminator.elapsed_time.should < LIMIT_TIME
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

    it "save/load on #{NUMBER_INSTANCES} instances in less then #{LIMIT_TIME} seconds" do
      # Checking to_file
      to_file_proc = Proc.new do
        begin
          @test_cd.to_file(@path)
        ensure
          @file.close
        end
      end
      to_file_proc.call_with_timer(terminator)
      terminator.elapsed_time.should < LIMIT_TIME

      # checking from_file
      cd2 = ContentData::ContentData.new
      from_file_proc = Proc.new do
        begin
          cd2.from_file(@path)
        ensure
          @file.close
        end
      end
      terminator = Limit.new(LIMIT_TIME, LIMIT_MEMORY)
      from_file_proc.call_with_timer(terminator)
      terminator.elapsed_time.should < LIMIT_TIME

      # checks that test was correct
      cd2.instances_size.should == @test_cd.instances_size
    end
  end

  describe 'Set operations' do
    before :all do
      @cd2 = get_initialized
      @cd2.add_instance((MAX_CHECKSUM+1).to_s, INSTANCE_SIZE, SERVER, PATH + "new", MTIME)
    end

    context "minus of two objects with #{NUMBER_INSTANCES} instances each" do
      it "finish in less then #{LIMIT_TIME} seconds" do
        res_cd = nil
        minus_proc = Proc.new { res_cd = ContentData.remove(@test_cd, @cd2) }
        minus_proc.call_with_timer(terminator)
        terminator.elapsed_time.should < LIMIT_TIME

        # checks that test was correct
        res_cd.should be
        res_cd.instances_size.should == 1
      end

      it "consume less then #{LIMIT_MEMORY} KB" do
        res_cd = nil
        minus_proc = Proc.new { res_cd = ContentData.remove(@test_cd, @cd2) }
        minus_proc.call_with_memory_limit(terminator)
        terminator.memory_usage.should < LIMIT_MEMORY

        # checks that test was correct
        res_cd.should be
        res_cd.instances_size.should == 1
      end
    end
  end
end
