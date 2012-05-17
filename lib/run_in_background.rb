# Author: Genady Petelko (nukegluk@gmail.com)
# Description: The file contains implementation of 'RunInBackground' module.

module BBFS
  # This library provides a basic cross-platform functionality to run arbitrary ruby scripts
  # in background and control them. <br>Supported platforms: Windows, Linux, Mac
  # == General Limitations:
  # *  Only ruby scripts can be run in background.
  # *  No multiple instances with the same name.
  # == Notes:
  # *  Linux/Mac specific methods have _linux suffix
  # *  Windows specific methods have _windows suffix
  # *  While enhancing windows code, take care that paths are in windows format,
  #    <br>e.i. with "\\" file separator while ruby by default uses a "/"
  # *  Additional functionality such as restart, reload, etc. will be added on demand
  # *  Remains support to provide platform specific options for start.
  #    <br>For more information regarding such options
  #    see documentation for win32-sevice (Windows), daemons (Linux/Mac)
  # == Linux Notes:
  # *  <tt>pid_dir</tt> parameter contains absolute path to directory where pid files will be stored.
  #    <br>If directory doesn't exists then it will be created.
  #    <br>User should have a read/write permissions to this location.
  #    <br>Default location: <tt>$HOME/.bbfs/pids</tt>
  # *  User should check that default pid directory is free from pid files of "killed" daemons.
  #    <br>It may happen, for example, when system finished in abnormal way then pid files were
  #    not deleted by daemons library.
  #    <br>In such case incorrect results can be received, for example for <tt>exists?</tt> method
  #    <br>One of the suggested methods can be before starting a daemon to check with <tt>exists?</tt>
  #    method whether daemon already exists and with <tt>running?</tt> method does it running.
  module RunInBackground
    require 'params'

    Params.parameter 'pid_dir', File.expand_path(File.join(Dir.home, '.bbfs', 'pids')),
      'Absolute path to directory, where pid files will be stored. ' + \
      'User should have a read/write permissions to this location. ' + \
      'If absent then it will be created. ' + \
      'It\'s actual only for Linux/Mac. ' + \
      'For more information see documentation on daemons module. ' +\
      'Default location is: $HOME/.bbfs/pids'

    # maximal time to wait untill OS will finish a requested operation
    # e.g. daemon start/delete
    TIMEOUT = 10

    if RUBY_PLATFORM =~ /linux/ or RUBY_PLATFORM =~ /darwin/
      begin
        require 'daemons'
        require 'fileutils'
      rescue LoadError
        require 'rubygems'
        require 'daemons'
        require 'fileutils'
      end

      OS = :LINUX
      # directory used to store pid files
      PID_DIR = File.expand_path(Params.pid_dir)
      if Dir.exists? PID_DIR
        unless File.directory? PID_DIR
         raise IOError.new("pid directory #{PID_DIR} should be a directory")
        end
        unless File.readable?(PID_DIR) && File.writable?(PID_DIR)
          raise IOError.new("you should have read/write permissions to pid dir: #{PID_DIR}")
        end
      else
        FileUtils.mkdir_p PID_DIR
      end
    elsif RUBY_PLATFORM =~ /mingw/ or RUBY_PLATFORM =~ /ms/ or RUBY_PLATFORM =~ /win/
      require 'rbconfig'
      begin
        require 'win32/service'
        require 'win32/daemon'
      rescue LoadError
        require 'rubygems'
        require 'win32/service'
        require 'win32/daemon'
      end
      include Win32

      OS = :WINDOWS
      # Get ruby interpreter path. Need it to run ruby binary.
      # <br>TODO check whether this code works with Windows Ruby Version Managment (e.g. Pik)
      RUBY_INTERPRETER_PATH = File.join(Config::CONFIG["bindir"],
                                        Config::CONFIG["RUBY_INSTALL_NAME"] +
                                            Config::CONFIG["EXEEXT"]).tr!('/','\\')

      # Path has to be absolute cause Win32-Service demands it.
      wrapper = File.join(File.dirname(__FILE__), "..", "bin", File.basename(__FILE__, ".rb"), "daemon_wrapper")
      # Wrapper script, that can receive commands from Windows Service Control and run user script,
      # <br> provided as it's argument
      WRAPPER_SCRIPT = File.expand_path(wrapper).tr!('/','\\')
    else
      raise "Unsupported platform #{RUBY_PLATFORM}"
    end

    # Start a service/daemon.
    # <br>It important to delete it after usage.
    # ==== Arguments
    # * <tt>binary_path</tt> - absolute path to the script that should be run in background
    #     NOTE for Linux script should be executable and with UNIX end-of-lines (LF).
    # * <tt>binary_args</tt> - Array (not nil) of script's command line arguments
    # * <tt>name</tt> - service/daemon name.
    #     NOTE should be unique
    # * <tt>opts_specific</tt> - Hash of platform specific options (only for more specific usage)
    #    For more information regarding such options see documentation for
    #    win32-sevice (Windows), daemons (Linux/Mac)
    # ==== Example (LINUX)
    # <tt>  RunInBackground.start "/home/user/test_app", [], "daemon_test", {:monitor => true}</tt>
    def RunInBackground.start binary_path, binary_args, name, opts_specific = {}
      if binary_path == nil or binary_args == nil or name == nil
        raise ArgumentError.new("binary path, binary args, name arguments must be defined")
      end
      if OS == :WINDOWS
        new_binary_path = String.new(binary_path)
        new_binary_args = Array.new(binary_args)
        wrap_windows new_binary_path, new_binary_args
        start_windows new_binary_path, new_binary_args, name, opts_specific
      else  # OS == LINUX
        start_linux binary_path, binary_args, name, opts_specific
      end

      0.upto(TIMEOUT) do
        return if exists?(name) && running?(name)
        sleep 1
      end
      # if got here then something gone wrong and daemon/service wasn't started in timely manner
      delete name if exists? name
      raise "daemon/service #{name} wasn't started in timely manner"
    end

    def RunInBackground.start_linux binary_path, binary_args, name, opts = {}
      unless File.executable_real? binary_path
        raise ArgumentError.new("#{binary_path} can't be executed")
      end

      if opts.has_key? :dir
        raise ArgumentError.new("No support for user-defined pid directories. See help")
      end

      opts[:app_name] = name
      opts[:ARGV] = ['start']
      (opts[:ARGV] << '--').concat(binary_args) if !binary_args.nil? && binary_args.size > 0
      opts[:dir] = PID_DIR
      opts[:dir_mode] = :normal

      # Current process, that creates daemon, will transfer control to the Daemons library.
      # So to continue working with current process, daemon creation initiated from separate process.
      pid = fork do
        Daemons.run binary_path, opts
      end
      Process.waitpid pid
    end

    def RunInBackground.start_windows binary_path, binary_args, name, opts = {}
      raise ArgumentError.new("#{binary_path} doesn't exist'") unless File.exists? binary_path
      binary_path.tr!('/','\\')
      opts[:binary_path_name] = "#{RUBY_INTERPRETER_PATH} #{binary_path} #{binary_args.join(' ')}"
      opts[:service_name] = name
      opts[:description] = name unless opts.has_key? :description
      opts[:display_name] = name unless opts.has_key? :display_name
      opts[:service_type] = Service::WIN32_OWN_PROCESS unless opts.has_key? :service_type
      opts[:start_type] = Service::DEMAND_START unless opts.has_key? :start_type

      # NOTE most of examples uses these dependencies. Meanwhile no explanations were found
      opts[:dependencies] = ['W32Time','Schedule'] unless opts.has_key? :dependencies
      # NOTE most of examples uses this option as defined beneath. The default is nil.
      #opts[:load_order_group] = 'Network' unless opts.has_key? :load_order_group

      Service.create(opts)
      begin
        Service.start(opts[:service_name])
      rescue
        Service.delete(opts[:service_name]) if Service.exists?(opts[:service_name])
        raise
      end
    end

    # Rerun current script in background.
    # <br>Current process will be closed.
    # <br>It suggested to remove from ARGV any command line arguments that point
    # to run script in background, <br>otherwise an unexpexted result can be received
    def RunInBackground.start! name, opts = {}
      start(File.expand_path($0), ARGV, name, opts)
      exit!
    end

    # Run in background script that was written as Windows Service, i.e. can receive signals
    # from Service Control.
    # <br>The code that is run in this script should be an extension of Win32::Daemon class.
    # <br>For more information see Win32::Daemon help and examples.
    # <br>No need  to wrap such a script.
    def RunInBackground.start_win32service binary_path, binary_args, name, opts_specific = {}
      if OS == :WINDOWS
        start_windows binary_path, binary_args, name, opts_specific
      else  # OS == :LINUX
        raise NotImplementedError.new("Unsupported method on #{OS}")
      end
      0.upto(TIMEOUT) do
        return if exists?(name) && running?(name)
        sleep 1
      end
      # if got here then something gone wrong and daemon/service wasn't started in timely manner
      delete name if exists? name
      raise "daemon/service #{name} wasn't started in timely manner"
    end

    # Wrap an arbitrary ruby script withing script that can be run as Windows Service.
    # ==== Arguments
    # * <tt>binary_path</tt> - absolute path of the script that should be run in background
    # * <tt>binary_args</tt> - array (not nil) of scripts command line arguments
    #
    #  NOTE binary_path and binary_args contents will be change
    def RunInBackground.wrap_windows binary_path, binary_args
      raise ArgumentError.new("#{binary_path} doesn't exists") unless File.exists? binary_path
      binary_args.insert(0, RUBY_INTERPRETER_PATH, binary_path.tr('/','\\'))
      binary_path.replace(WRAPPER_SCRIPT)
    end

    # NOTE if this method will become public then may be needed to change appropriately wrapper script
    def RunInBackground.stop name
      if not exists? name
        raise ArgumentError.new("Daemon #{name} doesn't exists")
      elsif OS == :WINDOWS
        Service.stop(name)
      else  # OS == :LINUX
        opts = {:app_name => name,
                :ARGV => ['stop'],
                :dir_mode => :normal,
                :dir => PID_DIR
               }
        # Current process, that creates daemon, will transfer control to the Daemons library.
        # So to continue working with current process, daemon creation initiated from separate process.
        # It looks that it holds only for start command
        #pid = fork do
        Daemons.run "", opts
        #end
        #Process.waitpid pid
      end
    end

    # Delete service/daemon.
    # <br>If running then stop and delete.
    def RunInBackground.delete name
      if not exists? name
        raise ArgumentError.new("Daemon #{name} doesn't exists")
      elsif running? name
        stop name
      end
      if OS == :WINDOWS
        Service.delete name
      else  # OS == :LINUX
        opts = {:app_name => name,
                :ARGV => ['zap'],
                :dir_mode => :normal,
                :dir => PID_DIR
               }
        # Current process, that creates daemon, will transfer control to the Daemons library.
        # So to continue working with current process, daemon creation initiated from separate process.
        # It looks that it holds only for start command
        #pid = fork do
        Daemons.run "", opts
        #end
        #Process.waitpid pid
      end
      0.upto(TIMEOUT) do
        return unless exists? name
        sleep 1
      end
      # if got here then something gone wrong and daemon/service wasn't deleted in timely manner
      raise "daemon/service #{name} wasn't deleted in timely manner"
    end

    def RunInBackground.exists? name
      if name == nil
        raise ArgumentError.new("service/daemon name argument must be defined")
      elsif OS == :WINDOWS
        Service.exists? name
      else  # OS == :LINUX
        pid_files = Daemons::PidFile.find_files(PID_DIR, name)
        pid_files != nil && pid_files.size > 0
      end
    end

    def RunInBackground.running? name
      if not exists? name
        raise ArgumentError.new("Daemon #{name} doesn't exists")
      elsif OS == :WINDOWS
        Service.status(name).current_state == 'running'
      else  # OS == :LINUX
        Daemons::Pid.running? name
      end
    end

    private_class_method :start_linux, :start_windows, :wrap_windows, :stop
  end
end
