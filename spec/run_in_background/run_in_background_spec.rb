# NOTE Code Coverage block must be issued before any of your application code is required
if ENV['BBFS_COVERAGE']
  require_relative '../spec_helper.rb'
  SimpleCov.command_name 'run_in_background'
end
require 'rspec'
require 'run_in_background'

# TODO break to number of small tests according to functionality
# TODO rewrite with Shoulda/RSpec
describe 'Run In Background Test' do
  Params.init([])

  if RUBY_PLATFORM =~ /linux/ or RUBY_PLATFORM =~ /darwin/
    OS = :LINUX
  elsif RUBY_PLATFORM =~ /mingw/ or RUBY_PLATFORM =~ /ms/ or RUBY_PLATFORM =~ /win/
    require 'sys/uname'
    OS = :WINDOWS
  else
    raise "Unsupported platform #{RUBY_PLATFORM}"
  end

  before :all do
    @good_daemon = "good_daemon_test"
    @good_daemonize = "good_daemonize_test"
    @good_win32daemon = "good_win32daemon_test"
    @bad_daemon = "bad_daemon_test"
    @binary = File.join(File.dirname(File.expand_path(__FILE__)), 'test_app')
    @binary.tr!('/','\\') if OS == :WINDOWS
    File.chmod(0755, @binary) if OS == :LINUX && !File.executable?(@binary)
    @absent_binary = File.join(File.dirname(File.expand_path(__FILE__)), "test_app_absent")
  end

  it 'test functionality' do
    if OS == :WINDOWS && Sys::Uname.sysname =~ /(Windows 7)/
      pending "This test shouldn't be run on #{$1}"
    end

    # test start
    # test application should actually start here
    expect { RunInBackground.start(@binary, ["1000"], @good_daemon) }.not_to raise_exception
    expect { RunInBackground.start(@absent_binary, ["1000"], @bad_daemon) }.to raise_exception(ArgumentError)

    # start arguments have to be defined
    expect { RunInBackground.start(["1000"], @bad_daemon) }.to raise_exception(ArgumentError)
    expect { RunInBackground.start(nil, ["1000"], @bad_daemon) }.to raise_exception(ArgumentError)
    expect { RunInBackground.start(@absent_binary, nil, @bad_daemon) }.to raise_exception(ArgumentError)
    expect { RunInBackground.start(@absent_binary, ["1000"], nil) }.to raise_exception(ArgumentError)

    # test exists?
    expect { RunInBackground.exists? }.to raise_exception(ArgumentError)
    RunInBackground.exists?(@bad_daemon).should == false
    RunInBackground.exists?(@good_daemon).should == true

    # test running?
    # if stop method will be public need to add test checks actually stopped daemon
    expect { RunInBackground.running? }.to raise_exception(ArgumentError)
    expect { RunInBackground.running?(@bad_daemon) }.to raise_exception(ArgumentError)
    RunInBackground.running?(@good_daemon).should == true

    # test daemonazing (start!)
    # from the nature of daemonization need to run it from another process that will be daemonized
    ruby = (OS == :WINDOWS ? RunInBackground::RUBY_INTERPRETER_PATH : "ruby")
    cmd = "#{ruby} -Ilib #{@binary} 50 #{@good_daemonize}"
    pid = spawn(cmd)
    Process.waitpid pid
    # checking that it indeed was daemonized
    # e.i. process was killed and code rerun in background
    # it takes time to the OS to remove process, so using a timeout here
    0.upto(RunInBackground::TIMEOUT) do
      begin
        Process.kill(0, pid)
      rescue Errno::ESRCH
        break
      end
      sleep 1
    end
    expect { Process.kill(0, pid) }.to raise_exception(Errno::ESRCH)
    RunInBackground.exists?(@good_daemonize).should == true
    RunInBackground.running?(@good_daemonize).should == true

    # test running win32 specific daemon (start_win32service)
    # wrapper script will be run
    if OS == :WINDOWS
      win32service_arg = [RunInBackground::RUBY_INTERPRETER_PATH, @binary, 1000]
      expect { RunInBackground.start_win32service(RunInBackground::WRAPPER_SCRIPT, win32service_arg, @good_win32daemon) }.not_to raise_exception
      RunInBackground.exists?(@good_win32daemon).should == true
      RunInBackground.running?(@good_win32daemon).should == true
    else
      expect { RunInBackground.start_win32service(@absent_binary, [], @bad_daemon) }.to raise_exception(NotImplementedError)
    end

    # uncomment following lines if there is a suspicion that something gone wrong
    # inspired by bug caused by coworking of daemon_wrapper an logger
    #sleep 10
    #RunInBackground.running?(@good_daemon).should == true
    #RunInBackground.running?(@good_daemonize).should == true
    #RunInBackground.running?(@good_win32daemon).should == true

    # test delete
    # test application should actually stop here
    expect { RunInBackground.delete }.to raise_exception(ArgumentError)
    expect { RunInBackground.delete(@bad_daemon) }.to raise_exception(ArgumentError)
    expect { RunInBackground.delete(@good_daemon) }.not_to raise_exception
    RunInBackground.exists?(@good_daemon).should == false

    expect { RunInBackground.delete(@good_daemonize) }.not_to raise_exception
    RunInBackground.exists?(@good_daemonize).should == false

    # actuall only for Windows platform
    if RunInBackground.exists?(@good_win32daemon)
      expect { RunInBackground.delete(@good_win32daemon) }.not_to raise_exception
      RunInBackground.exists?(@good_win32daemon).should == false
    end
  end

  after :all do
    RunInBackground.delete @good_daemon if RunInBackground.exists? @good_daemon
    RunInBackground.delete @good_daemonize if RunInBackground.exists? @good_daemonize
    RunInBackground.delete @good_win32daemon if RunInBackground.exists? @good_win32daemon
  end
end
