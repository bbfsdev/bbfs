class FileStatEnum
  NON_EXISTING = "NON_EXISTING"
  NEW = "NEW"
  CHANGED = "CHANGED"
  UNCHANGED = "UNCHANGED"
  STABLE = "STABLE"
end

class FileStat
  attr_accessor :stable_state, :state, :size, :modification_time
  attr_reader :cycles, :path

  DEFAULT_STABLE_STATE = 5

  @@log = nil

  def initialize(path, stable_state)
    @path ||= path
    @size = nil
    @modification_time = nil
    @cycles = 0
    @state = FileStatEnum::NON_EXISTING

    @stable_state = stable_state
  end

  def self.set_log (log)
    @@log = log
  end

  def monitor
    file_stats = File.lstat(@path) rescue nil
    new_state = nil
    if file_stats == nil
      new_state = FileStatEnum::NON_EXISTING
      @size = nil
      @modification_time = nil
      @cycles = 0
    elsif @size == nil
      new_state = FileStatEnum::NEW
      @size = file_stats.size
      @modification_time = file_stats.mtime.utc
      @cycles = 0
    elsif changed?(file_stats)
      new_state = FileStatEnum::CHANGED
      @size = file_stats.size
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
    self.state= new_state
  end

  def changed?(file_stats)
    not (file_stats.size == size and file_stats.mtime.utc == modification_time.utc)
  end

  def state= (new_state)
    if (@state != new_state or @state == FileStatEnum::CHANGED)
      @state = new_state
      if (@@log)
        @@log.puts(cur_stat)
        @@log.flush
      end
    end
  end

  def == (other)
    @path == other.path and @stable_state == other.stable_state
  end

  def to_s (ident = 0)
    (" " * ident) + path.to_s + " : " + state.to_s
  end

  def cur_stat
    # TODO what output format have to be ?
    Time.now.utc.to_s + " : " + self.state + " : " + self.path
  end
end

class DirStat < FileStat
  def initialize(path, stable_state = DEFAULT_STABLE_STATE)
    super
    @dirs = nil
    @files = nil
  end
  def add_dir (dir)
    @dirs[dir.path] = dir
  end

  def add_file (file)
    @files[file.path] = file
  end

  def rm_dir(dir)
    @dirs.delete(dir.path)
  end

  def rm_file(file)
    @files.delete(file.path)
  end

  def has_dir?(path)
    @dirs.has_key?(path)
  end

  def has_file?(path)
    @files.has_key?(path)
  end

  def to_s(ident = 0)
    ident_increment = 2
    child_ident = ident + ident_increment
    res = super
    @files.each_value do |file|
      res += "\n" + file.to_s(child_ident)
    end
    @dirs.each_value do |dir|
      res += "\n" + dir.to_s(child_ident)
    end
    res
  end

  def monitor
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
    self.state= new_state
  end

  # Updates the files and dirs hashes and globs the directory for changes.

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

  def glob_me
    was_changed = false
    files = Dir.glob(path + "/*")

    # add and monitor new files and directories
    files.each do |file|
      file_stat = File.lstat(file) rescue nil
      if (file_stat.directory?)
        unless (has_dir?(file)) # new directory
                                # change state only for existing directories
                                # newly added directories have to remain with NEW state
          was_changed = true
          ds = DirStat.new(file, self.stable_state)
          ds.monitor
          add_dir(ds)
        end
      else # it is a file
        unless(has_file?(file)) # new file
                                # change state only for existing directories
                                # newly added directories have to remain with NEW state
          was_changed = true
          fs = FileStat.new(file, self.stable_state)
          fs.monitor
          add_file(fs)
        end
      end
    end

    return was_changed
  end

  protected :add_dir, :add_file, :rm_dir, :rm_file
end

