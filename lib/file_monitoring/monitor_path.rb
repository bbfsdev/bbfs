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

  # Used for dir rename. Holds following info:
  #   checksum = checksum of the file
  #   index_time = index time of the file
  #   unique - if same key (file attributes) found more then once, we mark the file as not unique.
  #            This means that the file needs to be indexed.
  #            In the manual changes phase, the file will be skipped.
  class IdentFileInfo
    attr_accessor :checksum, :index_time, :unique
    def initialize(checksum, index_time)
      @checksum = checksum
      @index_time = index_time
      @unique = true
    end
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
    attr_accessor :path, :state, :size, :modification_time, :marked, :cycles, :indexed

    @@digest = Digest::SHA1.new

    #  Initializes new file monitoring object
    # ==== Arguments:
    #
    # * <tt>path</tt> - File\Dir path
    # * <tt>state</tt> - state. see class FileStatEnum. Default is NEW
    # * <tt>size</tt> - File size [Byte]. Default is -1 (will be set later during monitor) todo:used?
    # * <tt>mod_time</tt> - file mod time [seconds]. Default is -1 (will be set later during monitor)
    # * <tt>indexed</tt> - Initialize file which is already indexed (used for dir rename case)
    # * <tt>cycles</tt> - Initialize file which already passed monitor cycles (used for dir rename case)
    def initialize(path, state=FileStatEnum::NEW, size=-1, mod_time=-1, indexed=false, cycles=0)
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
      @cycles = cycles

      # flag to indicate if file was indexed
      @indexed = indexed
    end

    def index
      if !@indexed and FileStatEnum::STABLE == @state
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
          Log.warning("Indexed path'#{@path}' does not exist. Probably file changed") if @@log
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

    def write_to_log(msg)
      if @@log
        @@log.info(msg)
        @@log.outputters[0].flush if Params['log_flush_each_message']
      end
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
      @symlinks = {}  # Hash: [[server, link file name]] -> " target file name"]
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
      # initialize dirs and files.
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

    # add symlink while initializing tree using content data from file.
    #   Assumption is that Tree already built
    # Parameters:
    #   sub_paths - Array of sub paths of the symlink which is added to tree
    #               Example:
    #                 instance path = /dir1/dir2/file_name
    #                   Sub path 1: /dir1
    #                   Sub path 2: /dir1/dir2
    #                   Sub path 3: /dir1/dir2/file_name
    #               sub paths would create DirStat objs or FileStat(FileStat create using last sub path).
    #   sub_paths_index - the index indicates the next sub path to insert to the tree
    #                     the index will be raised at each recursive call down the tree
    #   symlink_path - symlink file path
    #   symlink_target - the target path pointed by the symlink
    def load_symlink(sub_paths, sub_paths_index, symlink_path, symlink_target)
      # initialize dirs and files.
      @dirs = {} unless @dirs
      @files = {} unless @files
      if sub_paths.size-1 == sub_paths_index
        # index points to last entry - leaf case. Add the symlink.
        @symlinks[symlink_path] = symlink_target
      else
        # Add Dir to tree if not present. index points to new dir path.
        dir_stat = @dirs[sub_paths[sub_paths_index]]
        #create new dir if not exist
        unless dir_stat
          dir_stat = DirStat.new(sub_paths[sub_paths_index])
          add_dir(dir_stat)
        end
        # continue recursive call on tree with next sub path index
        dir_stat.load_instance(sub_paths, sub_paths_index+1, symlink_path, symlink_target)
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
      res = super()
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
          write_to_log("NON_EXISTING dir: " + dir_stat.path)
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
          write_to_log("NON_EXISTING file: " + file_stat.path)
          # remove file with changed checksum
          $local_content_data_lock.synchronize{
            $local_content_data.remove_instance(Params['local_server_name'], file_stat.path)
          }
          # remove from tree
          @files.delete(file_stat.path)
        end
      end
    end

    ################ All monitoring helper methods #################
    
    # Checks that the globed path is valid.
    def is_globed_path_valid(globed_path)
      # UTF-8 - keep only files with names in
      return true if @non_utf8_paths[globed_path]
      check_utf_8_encoding_file = globed_path.clone
      unless check_utf_8_encoding_file.force_encoding("UTF-8").valid_encoding?
        Log.warning("Non UTF-8 file name '#{check_utf_8_encoding_file}', skipping.")
        @non_utf8_paths[globed_path] = true
        # TODO(bbfsdev): Remove line below and redundant clones of string after
        # those lines are not a GC problem.
        check_utf_8_encoding_file = nil
        return false
      end

      true
    end

    def handle_existing_file(child_stat, globed_path, globed_path_stat)
      if child_stat.changed?(globed_path_stat)
        # ---------- STATUS CHANGED
        # Update changed status
        child_stat.state = FileStatEnum::CHANGED
        child_stat.cycles = 0
        child_stat.size = globed_path_stat.size
        child_stat.modification_time = globed_path_stat.mtime.to_i
        write_to_log("CHANGED file: " + globed_path)
        # remove file with changed checksum. File will be added once indexed
        $local_content_data_lock.synchronize{
          $local_content_data.remove_instance(Params['local_server_name'], globed_path)
        }
      else  # case child_stat did not change
        # ---------- SAME STATUS
        # File status is the same
        if child_stat.state != FileStatEnum::STABLE
          child_stat.cycles += 1
          if child_stat.cycles >= ::FileMonitoring.stable_state
            child_stat.state = FileStatEnum::STABLE
            write_to_log("STABLE file: " + globed_path)
          else
            child_stat.state = FileStatEnum::UNCHANGED
            write_to_log("UNCHANGED file: " + globed_path)
          end
        end
      end
    end

    # This method handles the case where we set the 'manual_file_changes' param meaning
    # some files were moved/copied and no need to reindex them. In that case search "new files"
    # in old files to get the checksum (skipp the index phase).
    # The lookup is done via specially prepared file_attr_to_checksum map.
    def handle_moved_file(globed_path, globed_path_stat, file_attr_to_checksum)
      # --------------------- MANUAL MODE
      # check if file name and attributes exist in global file attr map
      file_attr_key = [File.basename(globed_path), globed_path_stat.size, globed_path_stat.mtime.to_i]
      file_ident_info = file_attr_to_checksum[file_attr_key]
      # If not found (real new file) or found but not unique then file needs indexing. skip in manual mode.
      if file_ident_info && file_ident_info.unique
        Log.debug1("update content data with file:%s  checksum:%s  index_time:%s",
                   File.basename(globed_path), file_ident_info.checksum, file_ident_info.index_time.to_s)
        # update content data (no need to update Dir tree)
        $local_content_data_lock.synchronize{
          $local_content_data.add_instance(file_ident_info.checksum,
                                           globed_path_stat.size,
                                           Params['local_server_name'],
                                           globed_path,
                                           globed_path_stat.mtime.to_i,
                                           file_ident_info.index_time)
        }
      end
    end

    def handle_new_file(child_stat, globed_path, globed_path_stat)
      child_stat = FileStat.new(globed_path,
                                FileStatEnum::NEW,
                                globed_path_stat.size,
                                globed_path_stat.mtime.to_i)
      write_to_log("NEW file: " + globed_path)
      child_stat.marked = true
      add_file(child_stat)
    end

    def handle_dir(globed_path, file_attr_to_checksum)
      # ------------------------------ DIR -----------------------
      child_stat = @dirs[globed_path]
      unless child_stat
        # ----------- ADD NEW DIR
        child_stat = DirStat.new(globed_path)
        add_dir(child_stat)
        write_to_log("NEW dir: " + globed_path)
      end
      child_stat.marked = true
      # recursive call for dirs
      child_stat.monitor(file_attr_to_checksum)
    end

    def add_found_symlinks(globed_path, found_symlinks)
      # if symlink - add to symlink temporary map and content data (even override).
      # later all non existing symlinks will be removed from content data
      pointed_file_name = File.readlink(globed_path)
      found_symlinks[globed_path] = pointed_file_name
      # add to content data
      $local_content_data_lock.synchronize{
        $local_content_data.add_symlink(Params['local_server_name'], globed_path, pointed_file_name)
      }
    end

    def remove_not_found_symlinks(found_symlinks)
      # check if any symlink was removed and update current symlinks map
      symlinks_enum = @symlinks.each_key
      loop {
        symlink_key = symlinks_enum.next rescue break
        unless found_symlinks.has_key?(symlink_key)
          # symlink was removed. remove from content data
          $local_content_data_lock.synchronize{
            $local_content_data.remove_symlink(Params['local_server_name'], symlink_key)
          }
        end
      }
      @symlinks = found_symlinks
    end

    # Recursively, read files and dirs lists from file system (using Glob)
    # - Adds new files\dirs.
    # - Change state for existing files\dirs
    # - Index stable files
    # - Remove non existing files\dirs is handled in method: remove_unmarked_paths
    # - Handles special case for param 'manual_file_changes' where files are moved and
    #   there is no need to index them
    def monitor(file_attr_to_checksum=nil)

      # Marking/Removing Algorithm:
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
      
      found_symlinks = {}  # Store found symlinks under dir
      loop do
        globed_path = globed_paths_enum.next rescue break

        next unless is_globed_path_valid(globed_path)
        if File.symlink?(globed_path)
          add_found_symlinks(globed_path, found_symlinks)
          next
        end

        # Get File \ Dir status
        globed_path_stat = File.lstat(globed_path) rescue next  # File or dir removed from OS file system
        if globed_path_stat.file?
          # ----------------------------- FILE -----------------------
          child_stat = @files[globed_path]
          if child_stat
            # Mark that file exists (will not be deleted at end of monitoring)
            child_stat.marked = true
            # Handle existing file If we are not in manual mode.
            # In manual mode do nothing
            handle_existing_file(child_stat, globed_path, globed_path_stat) unless Params['manual_file_changes']
          else
            unless Params['manual_file_changes']
              # Handle regular case of new file.
              handle_new_file(child_stat, globed_path, globed_path_stat)
            else
              # Only create new content data instance based on copied/moved filed.
              handle_moved_file(globed_path, globed_path_stat, file_attr_to_checksum)
            end
          end
        else
          handle_dir(globed_path, file_attr_to_checksum)
        end
      end

      remove_not_found_symlinks(found_symlinks)

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

