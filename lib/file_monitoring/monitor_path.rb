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

  # Number of iterations to move state from UNCHANGED to STABLE (for index)
  @@stable_state = 10

  def self.stable_state=(stable_state)
    @@stable_state = stable_state
  end

  def self.stable_state
    @@stable_state
  end

  public_class_method :stable_state, :stable_state=

  #  This class holds current state of file and methods to control and report changes
  class FileStat
    attr_accessor :path, :state, :size, :modification_time, :marked, :cycles

    @@digest = Digest::SHA1.new

    #  Initializes new file monitoring object
    # ==== Arguments:
    #
    # * <tt>path</tt> - File\Dir path
    # * <tt>state</tt> - state. see class FileStatEnum. Default is NEW
    # * <tt>size</tt> - File size [Byte]. Default is -1 (will be set later during monitor) todo:used?
    # * <tt>mod_time</tt> - file mod time [seconds]. Default is -1 (will be set later during monitor)
    def initialize(path, state=FileStatEnum::NEW, size=-1, mod_time=-1, indexed=false)
      # File\Dir path
      @path = path

      # File size
      @size = size

      # File modification time
      @modification_time = mod_time

      # File sate. see class FileStatEnum for states.
      @state = state

      # indicates if path EXISTS in file system.
      #   If true, file will not be removed during removed_unmarked_paths phase.
      @marked = false

      # Number of times that file was monitored and not changed.
      #  When @cycles exceeds ::FileMonitoring::stable_state, @state is set to Stable and can be indexed.
      @cycles = 0

      # flag to indicate if file was indexed
      @indexed = indexed
    end

    def index
      if !@indexed and FileStatEnum::STABLE == @state
        put "Indexing file: #{@path}"
        #index file
        @@digest.reset
        begin
          File.open(@path, 'rb') { |f|
            while buffer = f.read(16384) do
              @@digest << buffer
            end
          }
          $local_content_data_lock.synchronize{
            $local_content_data.add_instance(@@digest.hexdigest.downcase, @size, Params['local_server_name'],
                                             @path, @modification_time)
          }
          #$process_vars.inc('indexed_files')
          $indexed_file_count += 1
          @indexed = true
        rescue
          Log.warning("Indexed path'#{@path}' does not exist. Probably file changed")
        end
      end
    end

    #  Checks that stored file attributes are the same as file attributes taken from file system.
    def changed?(file_stats)
      !((file_stats.size == @size) &&
        (file_stats.mtime.to_i == @modification_time))
    end

    #  Checks whether path and state are the same as of the argument
    def == (other)
      @path == other.path
    end

    #  Returns path and state of the file with indentation
    def to_s (indent = 0)
      (" " * indent) + path.to_s + " : " + state.to_s
    end
  end

  #  This class holds current state of directory and methods to control changes
  class DirStat
    attr_accessor :path, :marked

    @@log = nil

    def self.set_log (log)
      @@log = log
    end

    public_class_method :set_log

    #  Initializes new directory monitoring object
    # ==== Arguments:
    #
    # * <tt>path</tt> - Dir location
    def initialize(path)
      @path = path
      @dirs = {}
      @files = {}
      @non_utf8_paths = {}  # Hash: ["path" -> true|false]

      # indicates if path EXISTS in file system.
      #   If true, file will not be removed during removed_unmarked_paths phase.
      @marked = false

    end

    # add instance while initializing tree using content data from file
    # Parameters:
    #   sub_paths - Array of sub paths of the instance which is added to tree
    #               Example:
    #                 instance path = /dir1/dir2/file_name
    #                   Sub path 1: /dir1
    #                   Sub path 2: /dir1/dir2
    #                   Sub path 3: /dir1/dir2/file_name
    #               sub paths would create DirStat objs or FileStat(FileStat create using last sub path).
    #   sub_paths_index - the index indicates the next sub path to insert to the tree
    #                     the index will be raised at each recursive call down the tree
    #   size - the instance size to insert to the tree
    #   modification_time - the instance modification_time to insert to the tree
    def load_instance(sub_paths, sub_paths_index, size, modification_time)
      # initialize dirs and files. This will indicate that the current DirStat is not new.
      @dirs = {} unless @dirs
      @files = {} unless @files
      if sub_paths.size-1 == sub_paths_index
        # Add File case - index points to last entry - leaf case.
        file_stat = FileStat.new(sub_paths[sub_paths_index], FileStatEnum::STABLE, size, modification_time, true)
        add_file(file_stat)
      else
        # Add Dir to tree if not present. index points to new dir path.
        dir_stat = @dirs[sub_paths[sub_paths_index]]
        #create new dir if not exist
        unless dir_stat
          dir_stat = DirStat.new(sub_paths[sub_paths_index])
          add_dir(dir_stat)
        end
        # continue recursive call on tree with next sub path index
        dir_stat.load_instance(sub_paths, sub_paths_index+1, size, modification_time)
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

    # Recursively, remove non existing files and dirs in Tree
    def removed_unmarked_paths
      #remove dirs
      dirs_enum = @dirs.each_value
      loop do
        dir_stat = dirs_enum.next rescue break
        if dir_stat.marked
          dir_stat.marked = false  # unset flag for next monitoring\index\remove phase
          #recursive call
          dir_stat.removed_unmarked_paths
        else
          # directory is not marked. Remove it, since it does not exist.
          #Log.debug1("Non Existing dir: %s", file_stat.path)
          @@log.info("NON_EXISTING dir: " + dir_stat.path)
          @@log.outputters[0].flush if Params['log_flush_each_message']
          # remove file with changed checksum
          $local_content_data_lock.synchronize{
            $local_content_data.remove_directory(dir_stat.path, Params['local_server_name'])
          }
          rm_dir(dir_stat)
        end
      end

      #remove files
      files_enum = @files.each_value
      loop do
        file_stat = files_enum.next rescue break
        if file_stat.marked
          file_stat.marked = false  # unset flag for next monitoring\index\remove phase
        else
          # file not marked meaning it is no longer exist. Remove.
          #Log.debug1("Non Existing file: %s", file_stat.path)
          @@log.info("NON_EXISTING file: " + file_stat.path)
          @@log.outputters[0].flush if Params['log_flush_each_message']
          # remove file with changed checksum
          $local_content_data_lock.synchronize{
            $local_content_data.remove_instance(Params['local_server_name'], file_stat.path)
          }
          rm_file(file_stat)
        end
      end
    end

    # Recursively, read files and dirs from file system (using Glob)
    # Handle new files\dirs.
    # Change state for existing files\dirs
    # Index stable files
    # Remove non existing files\dirs is handled in method: remove_unmarked_paths
    def monitor

      # Algorithm:
      # assume that current dir is present
      # ls (glob) the dir path for child dirs and files
      # if child file is not already present, add it as new, mark it and handle its state
      # if file already present, mark it and handle its state.
      # if child dir is not already present, add it as new, mark it and propagates
      #    the recursive call
      # if child dir already present, mark it and handle its state
      # marked files will not be remove in next remove phase

      # ls (glob) the dir path for child dirs and files
      globed_paths_enum = Dir.glob(@path + "/*").to_enum
      loop do
        globed_path = globed_paths_enum.next rescue break

        # UTF-8 - keep only files with names in
        next if @non_utf8_paths[globed_path]
        check_utf_8_encoding_file = globed_path.clone
        unless check_utf_8_encoding_file.force_encoding("UTF-8").valid_encoding?
          Log.warning("Non UTF-8 file name '#{check_utf_8_encoding_file}', skipping.")
          @non_utf8_paths[globed_path]=true
          check_utf_8_encoding_file=nil
          next
        end

        # Get File \ Dir status
        globed_path_stat = File.lstat(globed_path) rescue next  # File or dir removed from OS file system
        if globed_path_stat.file?
          # File case
          child_stat = @files[globed_path]
          if child_stat
            # file child exists in Tree
            child_stat.marked = true
            if child_stat.changed?(globed_path_stat)
              # Update changed status
              child_stat.state = FileStatEnum::CHANGED
              child_stat.cycles = 0
              child_stat.size = globed_path_stat.size
              child_stat.modification_time = globed_path_stat.mtime.to_i
              @@log.info("CHANGED file: " + globed_path)
              @@log.outputters[0].flush if Params['log_flush_each_message']
              #Log.debug1("CHANGED file: #{globed_path}")
              # remove file with changed checksum. File will be added once indexed
              $local_content_data_lock.synchronize{
                $local_content_data.remove_instance(Params['local_server_name'], globed_path)
              }
            else
              # File status is the same
              if child_stat.state != FileStatEnum::STABLE
                child_stat.state = FileStatEnum::UNCHANGED
                child_stat.cycles += 1
                if child_stat.cycles >= ::FileMonitoring.stable_state
                  child_stat.state = FileStatEnum::STABLE
                  @@log.info("STABLE file: " + globed_path)
                  @@log.outputters[0].flush if Params['log_flush_each_message']
                else
                  @@log.info("UNCHANGED file: " + globed_path)
                  @@log.outputters[0].flush if Params['log_flush_each_message']
                end
              end
            end
          else
            # new File child:
            child_stat = FileStat.new(globed_path, FileStatEnum::NEW,
                                      globed_path_stat.size, globed_path_stat.mtime.to_i)
            @@log.info("NEW file: " + globed_path)
            @@log.outputters[0].flush if Params['log_flush_each_message']
            child_stat.marked = true
            add_file(child_stat)
          end
        else
          # Dir
          child_stat = @dirs[globed_path]
          # Add Dir if not exists in Tree
          unless child_stat
            child_stat = DirStat.new(globed_path)
            add_dir(child_stat)
            @@log.info("NEW dir: " + globed_path)
            @@log.outputters[0].flush if Params['log_flush_each_message']
          end
          child_stat.marked = true
          #recursive call for dirs
          child_stat.monitor
        end
      end
      GC.start
    end

    def index
      files_enum = @files.each_value
      index_counter = $indexed_file_count  # to check if files where actually indexed
      loop do
        file_stat = files_enum.next rescue break
        file_stat.index  # file index
      end
      GC.start if index_counter != $indexed_file_count  # GC only if files where indexed

      dirs_enum = @dirs.each_value
      loop do
        dir_stat = dirs_enum.next rescue break
        dir_stat.index  # dir recursive call
      end
    end

    protected :add_dir, :add_file, :rm_dir, :rm_file
  end

end

