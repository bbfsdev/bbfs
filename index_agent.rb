require 'rubygems'
require 'digest/sha1'
require 'logger'
require 'pp'
require 'content_data'

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
	def get_checksum(filename)
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
      end
  end
  
  # get all files
  # satisfying the pattern
  def collect(pattern)
    Dir.glob(pattern.to_s)
  end
    
  # index device according to the pattern
  # store the result
  def index(patterns)
    permit_patterns = Array.new
    forbid_patterns = Array.new
    
    # pattern processing
    # pattern format: device:[+-]:path_pattern
    patterns.each_index do |i|
      unless (m = /([^:]*):([+-]):(.*)/.match(patterns[i]))
        @log.warn { "pattern in incorrect format: #{patterns[i]}" }
      end
      if (m[2].eql?('+'))
        permit_patterns.push(m[3])
      elsif (m[2].eql?('-')) 
        forbid_patterns.push(m[3])
      end
    end
    
    # transfer path inside the pattern to the standart view
    permit_patterns.each do |p|
      p.gsub!(/\\/,'/')
    end
    forbid_patterns.each do |p|
      p = p.gsub(/\\/,'/')
    end 
    
    # add files found by positive patterns
    files = Array.new  
    permit_patterns.each_index do |i| 
      files = files | (collect(permit_patterns[i]));
    end

    # remove files found by negative patterns
    forbid_patterns.each_index do |i|
      forbid_files = Array.new(collect(forbid_patterns[i]));
      forbid_files.each do |f|
        files.delete(f)
      end
    end
       
    files.each do |file|
      file_stats = File.lstat(file)
      
      # index only files
      next if (file_stats.directory?)
      # calculate a checksum
      unless (checksum = get_checksum(file))
        @log.warn { "Cheksum failure: " + file }
        next
      end
      
      @db.add_content(Content.new(checksum, file_stats.size, Time.now().utc().to_s)) unless (@db.content_exists(checksum))
      
      instance = ContentInstance.new(checksum, file_stats.size, server_name, device, File.expand_path(file), file_stats.mtime.utc)
      @db.add_instance(instance)
    end
  end  
end