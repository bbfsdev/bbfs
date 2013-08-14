require 'content_server/server'
require 'log'
require 'params'

module FileMonitoring
  #  Path monitoring.

  #  Enum-like structure that includes possible filesystem entities (files/directories) states:
  # * <tt>NON_EXISTING</tt> - Entity that was treated during previous run, but absent currently
  # * <tt>NEW</tt> - Entity that was found and added to control during this run
  # * <tt>CHANGED</tt> - State was changed between two checks
  # * <tt>UNCHANGED</tt> - Opposite to CHANGED
  # * <tt>STABLE</tt> - Entity is in the UNCHANGED state for a defined (by user) number of iterations


  class FileStatEnum
    NON_EXISTING = "NON_EXISTING"
    NEW = "NEW"
    CHANGED = "CHANGED"
    UNCHANGED = "UNCHANGED"
    STABLE = "STABLE"
  end

  #  This class holds current state of file and methods to control and report changes
  class FileStat
    attr_reader :cycles, :path, :stable_state
    attr_accessor :state, :size, :modification_time

    DEFAULT_STABLE_STATE = 10

    @@log = nil

    #  Initializes new file monitoring object
    # ==== Arguments:
    #
    # * <tt>path</tt> - File location
    # * <tt>stable_state</tt> - Number of iterations to move unchanged file to stable state
    def initialize(path, stable_state = DEFAULT_STABLE_STATE)
      @path ||= path
      @size = nil
      #@creation_time = nil
      @modification_time = nil
      @cycles = 0  # number of iterations from the last file modification
      @stable_state = stable_state  # number of iteration to move unchanged file to stable state
    end

    def set_output_queue(event_queue)
      @event_queue = event_queue
    end

    #  Sets a log file to report changes
    # ==== Arguments:
    #
    # * <tt>log</tt> - already opened ruby File object
    def self.set_log (log)
      @@log = log
    end

    # Checks whether file was changed from the last iteration.
    # For files, size and modification time are checked.
    def monitor
      #Log.info("Start file monitor")
      file_stats = File.lstat(@path) rescue nil
      new_state = nil
      if file_stats == nil
        new_state = FileStatEnum::NON_EXISTING
        @size = nil
        #@creation_time = nil
        @modification_time = nil
        @cycles = 0
      elsif @size == nil
        new_state = FileStatEnum::NEW
        @size = file_stats.size
        #@creation_time = file_stats.ctime.utc
        @modification_time = file_stats.mtime.utc
        @cycles = 0
      elsif changed?(file_stats)
        new_state = FileStatEnum::CHANGED
        @size = file_stats.size
        #@creation_time = file_stats.ctime.utc
        @modification_time = file_stats.mtime.utc
        @cycles = 0
      else
        new_state = FileStatEnum::UNCHANGED
        @cycles += 1
        if @cycles >= @stable_state
          new_state = FileStatEnum::STABLE
        end
      end

      # The assignment
      set_state(new_state)
    end

    #  Checks that stored file attributes are the same as file attributes taken from file system.
    def changed?(file_stats)
      Log.info("size:#{file_stats.size}  size:#{@size}")
      Log.info("time:#{file_stats.mtime.utc}  time:#{@modification_time.utc}")
      Log.info("true?=time:#{file_stats.mtime.utc == @modification_time.utc}")
      value = !((file_stats.size == @size) && (file_stats.mtime.utc == @modification_time.utc))
      Log.info("changed?=#{value}")
      value
    end

    def set_event_queue(queue)
      @event_queue = queue
    end

    #  Sets and writes to the log a new state.
    def set_state(new_state)
      if (@state != new_state or @state == FileStatEnum::CHANGED)
        @state = new_state
        if (@@log)
          @@log.info(state + ": " + path)
          @@log.outputters[0].flush if Params['log_flush_each_message']
        end
        if @event_queue and FileStatEnum::NEW != @state  # NEW state is ignored in indexer
          Log.debug1 "Writing to event queue [#{self.state}, #{self.path}]"
          @event_queue.push([self.state, self.instance_of?(DirStat), self.path,
                             self.modification_time, self.size])
          $process_vars.set('monitor to index queue size', @event_queue.size)
        end
      end
    end

    #  Checks whether path and state are the same as of the argument
    def == (other)
      @path == other.path and @stable_state == other.stable_state
    end

    #  Returns path and state of the file with indentation
    def to_s (indent = 0)
      (" " * indent) + path.to_s + " : " + state.to_s
    end
  end

  #  This class holds current state of directory and methods to control changes
  class DirStat < FileStat
    #  Initializes new directory monitoring object
    # ==== Arguments:
    #
    # * <tt>path</tt> - File location
    # * <tt>stable_state</tt> - Number of iterations to move unchanged directory to stable state
    def initialize(path, stable_state = DEFAULT_STABLE_STATE)
      super
      @dirs = nil
      @files = nil
      @non_utf8_paths = {}
    end

    # add instance while initializing tree using content data from file
    def load_instance(arr_of_paths, next_index, size, modification_time)
      @files = {} unless @files
      @dirs = {} unless @dirs
      if arr_of_paths.size-1 == next_index  # last index
        # index points to last entry - file name - leaf case. Add new file.
        file_stat = FileStat.new(arr_of_paths[next_index], @stable_state)
        file_stat.set_event_queue(@event_queue)
        file_stat.size = size
        file_stat.modification_time = Time.at(modification_time)
        file_stat.state = FileStatEnum::STABLE
        #Log.info("Add file:#{arr_of_paths[next_index]}")
        add_file(file_stat)
      else
        # index points to next dir entry. Add new Dir to tree if not present
        dir_stat = @dirs[arr_of_paths[next_index]]
        #Log.info("Add Dir:#{arr_of_paths[next_index]}") unless dir_stat
        #create new dir if not exist
        dir_stat = add_dir(DirStat.new(arr_of_paths[next_index], @stable_state)) unless dir_stat
        dir_stat.state = FileStatEnum::STABLE
        # continue recursive call on tree dir nodes
        dir_stat.set_event_queue(@event_queue)
        dir_stat.load_instance(arr_of_paths, next_index+1, size, modification_time)
      end
    end

    #  Adds directory for monitoring.
    def add_dir (dir)
      @dirs[dir.path] = dir
    end

    #  Adds file for monitoring.
    def add_file (file)
      @files[file.path] = file
    end

    #  Removes directory from monitoring.
    def rm_dir(dir)
      @dirs.delete(dir.path)
    end

    #  Removes file from monitoring.
    def rm_file(file)
      @files.delete(file.path)
    end

    #  Checks that there is a sub-folder with a given path.
    def has_dir?(path)
      @dirs.has_key?(path)
    end

    #  Checks that there is a file with a given path.
    def has_file?(path)
      @files.has_key?(path)
    end

    #  Returns string which contains path and state of this directory as well as it's structure.
    def to_s(indent = 0)
      indent_increment = 2
      child_indent = indent + indent_increment
      res = super
      @files.each_value do |file|
        res += "\n" + file.to_s(child_indent)
      end if @files
      @dirs.each_value do |dir|
        res += "\n" + dir.to_s(child_indent)
      end if @dirs
      res
    end

    # Checks that directory structure (i.e. files and directories located directly under this directory)
    # wasn't changed since the last iteration.
    def monitor
      #Log.info("Start dir monitor")
      was_changed = false
      new_state = nil
      self_stat = File.lstat(@path) rescue nil
      if self_stat == nil
        new_state = FileStatEnum::NON_EXISTING
        @files = nil
        @dirs = nil
        @cycles = 0
      elsif @files == nil
        new_state = FileStatEnum::NEW
        @files = Hash.new
        @dirs = Hash.new
        @cycles = 0
        update_dir
      elsif update_dir
        new_state = FileStatEnum::CHANGED
        @cycles = 0
      else
        new_state = FileStatEnum::UNCHANGED
        @cycles += 1
        if @cycles >= @stable_state
          new_state = FileStatEnum::STABLE
        end
      end

      # The assignment
      set_state(new_state)
    end

    # Updates the files and directories hashes and globs the directory for changes.
    def update_dir
      was_changed = false

      # monitor existing and absent files
      @files.each_value do |file|
        file.monitor

        if file.state == FileStatEnum::NON_EXISTING
          was_changed = true
          rm_file(file)
        end
      end

      @dirs.each_value do |dir|
        dir.monitor

        if dir.state == FileStatEnum::NON_EXISTING
          was_changed = true
          rm_dir(dir)
        end
      end

      was_changed = was_changed || glob_me

      return was_changed
    end

    #  Globs the directory for new files and directories
    def glob_me
      was_changed = false
      files = Dir.glob(path + "/*")

      # add and monitor new files and directories
      files.each do |file|
        # keep only files with names in UTF-8
        next if @non_utf8_paths[file]
        check_utf_8_encoding_file = file.clone
        unless check_utf_8_encoding_file.force_encoding("UTF-8").valid_encoding?
          Log.warning("Non UTF-8 file name '#{check_utf_8_encoding_file}', skipping.")
          @non_utf8_paths[file]=true
          next
        end
        file_stat = File.lstat(file) rescue nil
        if (file_stat.directory?)
          unless (has_dir?(file)) # new directory
                                  # change state only for existing directories
                                  # newly added directories have to remain with NEW state
            was_changed = true
            ds = DirStat.new(file, self.stable_state)
            ds.set_event_queue(@event_queue) unless @event_queue.nil?
            ds.monitor
            add_dir(ds)
          end
        else # it is a file
          unless(has_file?(file)) # new file
                                  # change state only for existing directories
                                  # newly added directories have to remain with NEW state
            was_changed = true
            # check if file exist in content data cache - set state to STABLE
            file_state = FileStatEnum::NON_EXISTING
            fs = FileStat.new(file, self.stable_state)
            fs.set_event_queue(@event_queue) unless @event_queue.nil?
            fs.monitor
            add_file(fs)
          end
        end
      end

      return was_changed
    end

    protected :add_dir, :add_file, :rm_dir, :rm_file, :update_dir, :glob_me
  end

end

