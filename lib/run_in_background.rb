

module BBFS
  # This library provides a basic cross-platform functionality to run arbitrary ruby scripts
  # in backgroubd and control them. <br>Supported platforms: Windows, Linux, Mac
  # == General Limitations:
  # *  Only ruby scripts can be run in background.
  # *  No multiple instances with the same name  
  # == Limitations on Linux:
  # *  No support for user defined pid directories.
  # *  All pid files are stored in the pre-defined directory: $HOME/.bbfs/pids  
  # *  User should check that default pid directory is free from pid files of "killed" daemons.
  #    <br>It may happen, for example, when system finished in abnormal way than pid files were
  #    not deleted by daemons library.
  #    <br>In such case incorrect results can be received, for example for exists? method
  # == Notes:
  # *  Linux specific methods have _linux suffix
  # *  Windows specific methods have _windows suffix
  # *  While enhancing windows code, take care that paths are in windows format, 
  #    e.i. with "\\" file separator while ruby by default uses a "/"
  # *  Additional functionality such as restart, reload, etc. will be added on demand
  # *  Remains support to provide platform specific options for start. 
  #    <br>For more information regarding such options 
  #    see documentation for win32-sevice (Windows), daemons (Linux/Mac)
  module RunInBackground
    if RUBY_PLATFORM =~ /mingw/ or RUBY_PLATFORM =~ /ms/ or RUBY_PLATFORM =~ /win/
      require 'rbconfig'
      begin
        require 'win32/service'
        require 'win32/daemon'
      rescue
        require 'rubygems'
        require 'win32/service'
        require 'win32/daemon'
      end
      include Win32
      
      OS = :WINDOWS
      # Get ruby interpreter path. Need it to run ruby binary.
      # TODO check whether this code works with Windows Ruby Version Managment (e.g. Pik)
      RUBY_INTERPRETER_PATH = File.join(Config::CONFIG["bindir"],
                                        Config::CONFIG["RUBY_INSTALL_NAME"] +
                                            Config::CONFIG["EXEEXT"]).tr!('/','\\')

      wrapper = File.join(File.dirname(__FILE__), "..", "bin", "daemon_wrapper")
      # Wrapper script, supplied with this module, that can receive commands from Service Control
      # <br>and run user scripts, that it received as an argument
      # TODO should windows wrapper be in lib directory?
      WRAPPER_SCRIPT = File.expand_path(wrapper).tr!('/','\\')
    elsif RUBY_PLATFORM =~ /linux/ or RUBY_PLATFORM =~ /darwin/
      begin
        require 'daemons'
        require 'fileutils'
      rescue
        require 'rubygems'
        require 'daemons'
        require 'fileutils'
      end

      OS = :LINIX
      # Default directory used to store pid files
      PID_DIR = File.expand_path(File.join(Dir.home, '.bbfs', 'pids'))
      FileUtils.mkdir_p PID_DIR unless Dir.exists? PID_DIR
    else
      raise "Unsupported platform #{RUBY_PLATFORM}"
    end

    # Start a service/daemon.
    # <br>It important to delete it after usage.
    # ==== Arguments
    # * <tt>binary_path</tt> - absolute path to the script that should be run in background
    # NOTE for Linux script should be executable
    # * <tt>binary_args</tt> - Array (not nil) of script's command line arguments
    # * <tt>name</tt> - service/daemon name. NOTE should be unique
    # * <tt>opts_specific</tt> - Hash of platform specific options (only for more specific usage)
    # For more information regarding such options see documentation for 
    # win32-sevice (Windows), daemons (Linux/Mac)
    def RunInBackground.start(binary_path, binary_args, name, opts_specific = {})
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
    end

    def RunInBackground.start_linux(binary_path, binary_args, name, opts = {})
      unless File.executable_real? binary_path
        raise ArgumentError.new("#{binary_path} can't be executed") 
      end

      # TODO do we need an option to get a pid directory from environment variable?
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

    def RunInBackground.start_windows(binary_path, binary_args, name, opts = {})
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
    # to run script in background, <br>otherwise you may receive an unexpexted result
    def RunInBackground.start!(name, opts = {})
      start(File.expand_path($0), ARGV, name, opts)
      exit!
    end

    # Run in background script that was written as Windows Service, i.e. can receive signals
    # from Service Control.
    # <br>The code that is run in this script should be an extension of Win32::Daemon class.
    # <br>For more information see Win32::Daemon help and examples.
    # <br>No need  to wrap such a script.
    def RunInBackground.start_win32service(binary_path, binary_args, name, opts_specific = {})
      if OS == :WINDOWS
        start_windows binary_path, binary_args, name, opts_specific
      else  # OS == :LINUX
        raise NotImplementedError.new("Unsupported method on #{OS}")
      end
    end

    # Wrap an arbitrary ruby script withing script that can be run as Windows Service.
    # ==== Arguments
    # * <tt>binary_path</tt> - absolute path of the script that should be run in background
    # * <tt>binary_args</tt> - array (not nil) of scripts command line arguments
    #
    # NOTE binary_path and binary_args contents will be change
    def RunInBackground.wrap_windows(binary_path, binary_args)
      raise ArgumentError.new("#{binary_path} doesn't exists") unless File.exists? binary_path
      binary_args.insert(0, RUBY_INTERPRETER_PATH, binary_path.tr('/','\\'))
      binary_path.replace(WRAPPER_SCRIPT)
    end

    def RunInBackground.stop(name)
      if not exists? name
        raise ArgumentError.new("Daemon #{name} doesn't exists")
      elsif OS == :WINDOWS
        Service.stop(name)
      else  # OS == :LINIX
        opts = {:app_name => name,
                :ARGV => ['stop'],
                :dir_mode => :normal,
                :dir => PID_DIR 
               }
        Daemons.run "", opts
      end
    end

    # Delete service/daemon.
    # <br>If running then stop and delete.
    def RunInBackground.delete(name)
      if not exists? name
        raise ArgumentError.new("Daemon #{name} doesn't exists")
      elsif running? name
        stop name
      end
      if OS == :WINDOWS
        Service.delete name
      else  # OS == :LINIX
        opts = {:app_name => name,
                :ARGV => ['zap'],
                :dir_mode => :normal,
                :dir => PID_DIR 
               }
        Daemons.run "", opts
      end
    end

    def RunInBackground.exists?(name)
      if name == nil
        raise ArgumentError.new("service/daemon name argument must be defined")
      elsif OS == :WINDOWS
        Service.exists? name
      else  # OS == :LINIX
        pid_files = Daemons::PidFile.find_files(PID_DIR, name)
        pid_files != nil && pid_files.size > 0
      end
    end

    def RunInBackground.running?(name)
      if not exists? name
        raise ArgumentError.new("Daemon #{name} doesn't exists")
      elsif OS == :WINDOWS
        Service.status(name).current_state == 'running'
      else  # OS == :LINIX
        Daemons::Pid.running? name
      end
    end

    private_class_method :start_linux, :start_windows, :wrap_windows, :stop
  end
end
