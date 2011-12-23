



class FileStatEnum
  attr_reader :value
  NEW = "NEW"
  CHANGED = "CHANGED"
  UNCHANGED = "UNCHANGED"
  STABLE = "STABLE"

  def self.contains? (value)
    self.const_defined?(value, false)
  end

  def value= (new_value)
    if FileStatEnum.contains?new_value
      @value = new_value
    else
      raise ("Not an enum permitted value: #{new_value}")
    end
  end

  def to_s
    value
  end
end

class FileStat
  attr_accessor :scan_period, :stable_state, :state, :size, :modification_time
  attr_reader :cycles, :path

  DEFAULT_STABLE_STATE = 5

  @@log = nil

  def initialize(path, size, modification_time, stable_state = DEFAULT_STABLE_STATE)
    @path ||= path
    @size = size
    @modification_time = modification_time
    @scan_period = scan_period
    @stable_state = stable_state
    @state = FileStatEnum::NEW
    @cycles = 0
  end

  def self.set_log (log)
    @@log = log
  end

  def monitor
    file_stats = File.lstat(@path)
    if (file_stats == nil or changed?)
      self.state= FileStatEnum::CHANGED
    else
      @cycles += 1
      if @cycles >= @stable_state and (@state == FileStatEnum::UNCHANGED or @state == FileStatEnum::NEW)
        self.state= FileStatEnum::STABLE #if @state != FileStatEnum::STABLE
      elsif @state == FileStatEnum::NEW or @state == FileStatEnum::CHANGED
        self.state= FileStatEnum::UNCHANGED
        @cycles = 0
      end
    end
  end

  def changed?
    file_stat = File.lstat(@path)
    if (file_stat == nil)
      true
    elsif (file_stat.size == size and file_stat.mtime.utc == modification_time.utc)
      false
    else
      true
    end
  end

  def state= (new_state)
    if FileStatEnum.contains?new_state
      if (@state != new_state)
        @state = new_state
        if (@@log)
          @@log.puts(cur_stat)
          @@log.flush
        end
      end
    else
      raise "Not a permitted state: #{new_state}"
    end
  end

  def stable_state= (new_stable_state)
    @stable_state = new_stable_state
    if new_stable_state < @cycles_stable
      state=(FileStatEnum::STABLE)
      @cycles = 0
    end
  end

  def == (other)
    @path == other.path and @scan_period == other.scan_period and @stable_state == other.stable_state
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
  def initialize(path, size = nil, modification_time = nil, stable_state = DEFAULT_STABLE_STATE)
    super
    @dirs = Hash.new
    @files = Hash.new
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

  def get_dir(path)
    if has_dir?path
      @dirs[path]
    else
      raise "No such a dir: #{path}"
    end
  end

  def get_file(path)
    if has_dir?path
      @files[path]
    else
      raise "No such a file: #{path}"
    end
  end

  def get_child(path)
    if has_file?path
      return get_file(path)
    elsif has_dir?path
      return get_dir(path)
    else
      @dirs.each_value do |dir|
        child = dir.get_child(path)
        return child if child != nil
      end
    end
    return nil
  end

  def changed?
    # TODO
    nil
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

  def monitor ()
    files = Dir.glob(path + "/*")
    is_init_monitor= false  # is this monitor run for DirState init ?
    is_init_monitor = true if (@state == FileStatEnum::NEW and @cycles == 0 and @files.size == 0 and @dirs.size == 0)
    was_changed = false

    # monitor existing and absent files
    @files.each_value do |file|
      if files.include?(file.path) # existing file
        file.monitor
      else   # file was deleted
             #TODO what we are doing in this case?
        self.state=(FileStatEnum::CHANGED)
        rm_file(file)
        was_changed = true
      end
    end

    @dirs.each_value do |dir|
      if files.include?(dir.path)  # existing file
        dir.monitor
      else  #dir was deleted
            #TODO what we are doing in this case?
        self.state=(FileStatEnum::CHANGED)
        rm_dir(dir)
        was_changed = true
      end
    end

    # add and monitor new files and directories
    files.each do |file|
      file_stat = File.lstat(file)
      if (file_stat.directory?)
        unless (has_dir?(file)) # new directory
                                # change state only for existing directories
                                # newly added directories have to remain with NEW state
          unless is_init_monitor #if @state != FileStatEnum::NEW and @cycles != 0
            self.state= FileStatEnum::CHANGED
            was_changed = true
          end
          dir = DirStat.new(file, file_stat.size, file_stat.mtime.utc, self.stable_state)
          add_dir(dir)
          new_files = Dir.glob(dir.path + "/*")
          new_files.each do |new_file|
            new_file_stat = File.lstat(new_file)
            if (new_file_stat.directory?)
              new_dir = DirStat.new(new_file, new_file_stat.size, new_file_stat.mtime.utc, self.stable_state)
              dir.add_dir(new_dir)
              new_dir.monitor
            else
              dir.add_file(FileStat.new(new_file, new_file_stat.size, new_file_stat.mtime.utc, self.stable_state))
            end
          end
        end
      else # it is a file
        unless(has_file?(file)) # new file
                                # change state only for existing directories
                                # newly added directories have to remain with NEW state
          unless is_init_monitor #if @state != FileStatEnum::NEW and @cycles != 0
            self.state= FileStatEnum::CHANGED
            was_changed = true
          end
          add_file(FileStat.new(file, file_stat.size, file_stat.mtime, self.stable_state))
        end
      end
    end

    unless is_init_monitor or was_changed
      @cycles += 1
      if @cycles >= @stable_state and (@state == FileStatEnum::UNCHANGED or @state == FileStatEnum::NEW)
        self.state= FileStatEnum::STABLE #if @state != FileStatEnum::STABLE
      else @state == FileStatEnum::NEW or @state == FileStatEnum::CHANGED
        self.state= FileStatEnum::UNCHANGED
        @cycles = 0
      end
    end
  end

end

