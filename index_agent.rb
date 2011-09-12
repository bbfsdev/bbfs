require 'rubygems'
require 'digest/sha1'
require 'logger'
require 'pp'
require 'time'
require './content_data'

####################
# Index Agent
####################

class IndexAgent
attr_reader :db, :server_name, :device

LOCALTZ = Time.now.zone
ENV['TZ'] = 'UTC'

	def initialize(server_name, device)
    @server_name = server_name
    @device = device
    init_log()
    init_db()
	end

  def init_db()
    @db = ContentData.new
  end

	def init_log()
		@log = Logger.new(STDERR)
		@log.level = Logger::WARN
		@log.datetime_format = "%Y-%m-%d %H:%M:%S"
	end

	def set_log(log_path, log_level)
		@log = Logger.new(log_path) if log_path
		@log.level = log_level
	end

  # Calculate file checksum (SHA1)
	def self.get_checksum(filename)
		digest = Digest::SHA1.new
    	begin
        file = File.new(filename)
        while buffer = file.read(65536)
    			digest << buffer
        end
    		#@log.info { digest.hexdigest.downcase + ' ' + filename }
    		digest.hexdigest.downcase
      rescue Errno::EACCES, Errno::ETXTBSY => exp
        @log.warn { "#{exp.message}" }
    		false
      ensure
        file.close if file != nil
      end
  end

  # get all files
  # satisfying the pattern
  def collect(pattern)
    Dir.glob(pattern.to_s)
  end

  # index device according to the pattern
  # store the result
  def index(patterns, otherDB = nil)
    abort "#{self.class}: DB not empty. Current implementation permits only one running of index" unless db.contents.empty?
    permit_patterns = Array.new
    forbid_patterns = Array.new
    otherDB_table = Hash.new   # contains instances from given DB while full path name is a key and instance is a value
    otherDB_contents = Hash.new  # given DB contents
    
    # if there is a given DB then populate table with files 
    # that was already indexed on this server/device 
    if (otherDB != nil)
      otherDB_contents.update(otherDB.contents)
      otherDB.instances.each_value do |i|
        next unless i.server_name == @server_name and i.device == @device
        otherDB_table[i.full_path] = i
      end
    end
    
    # pattern processing
    # pattern format: device:[+-]:path_pattern
    patterns.each_index do |i|
      unless (m = /([^:]*):([+-]):(.*)/.match(patterns[i]))
        #@log.warn { "pattern in incorrect format: #{patterns[i]}" }
        abort ("pattern in incorrect format: #{patterns[i]}")
      end
      if (m[2].eql?('+'))
        permit_patterns.push(m[3])
      elsif (m[2].eql?('-'))
        forbid_patterns.push(m[3])
      end
    end

    # transfer path inside the pattern to the standart view
    # need for Dir.glob function
    permit_patterns.each do |p|
      p.gsub!(/\\/,'/')
    end
    forbid_patterns.each do |p|
      p.gsub!(/\\/,'/')
    end

    # add files found by positive patterns
    files = Array.new
    permit_patterns.each_index do |i|
      files = files | (collect(permit_patterns[i]));
    end

    # expand to absolute pathes
    files.map! {|f| File.expand_path(f)}

    # remove files found by negative patterns
    forbid_patterns.each_index do |i|
      forbid_files = Array.new(collect(forbid_patterns[i]));
      forbid_files.each do |f|
        files.delete(File.expand_path(f))
      end
    end
    
    # create and add contents and instances
    files.each do |file|
      file_stats = File.lstat(file)
      
      # index only files
      next if (file_stats.directory?)   
      
      # keep only files with names in UTF-8      
      unless file.force_encoding("UTF-8").valid_encoding?
        @log.warn { "Non-UTF8 file name \"#{file}\"" }
        next
      end
      
      # add files present in the given DB to the DB and remove these files
      # from further processing (save checksum calculation)
      if otherDB_table.has_key?(file)
        instance = otherDB_table[file]
        @db.add_content(otherDB_contents[instance.checksum])
        @db.add_instance(instance)
        next
      end
    
      # calculate a checksum
      unless (checksum = self.class.get_checksum(file))
        @log.warn { "Cheksum failure: " + file }
        next
      end

      @db.add_content(Content.new(checksum, file_stats.size, Time.now.utc)) unless (@db.content_exists(checksum))

      instance = ContentInstance.new(checksum, file_stats.size, server_name, device, File.expand_path(file), file_stats.mtime.utc)
      @db.add_instance(instance)
    end
  end
end
