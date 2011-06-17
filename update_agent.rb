require 'rubygems'
require 'sequel'
require 'digest/sha1'
require 'logger'
require 'pp'

def print_r(hash, level=0)
	result = "  "*level + "{\n"
	hash.keys.each do |key|
		result += "  "*(level+1) + "#{key} => "
		if hash[key].instance_of? Hash
			result += "\n" + print_r(hash[key], level+2)
		else 
	        	result += "#{hash[key]}\n"
		end
	end
	result += "  "*level + "}\n"
end

####################
# File Info 
####################

# FileInfo object contains statistical information (name, path and modification time)
# gathered while entry point traversal
class FileInfo
	attr_accessor :name, :path, :modification_time, :size

	def initialize(name, path, modification_time, size)
		@name			= name
  		@path			= path
		@modification_time	= modification_time
		@size			= size
	end
	
	def is_changed?
	begin
		file_stats = File.lstat(@path + '/' + @name)
		return false if file_stats.size == @size && file_stats.mtime.tv_sec == @modification_time.tv_sec
	rescue 
	        @log.warn { $!.to_s }
	end
		true
	end
end

####################
# Update Agent 
####################

class UpdateAgent
	attr_accessor :db, :schema, :log, :files, :contents, :entry_points, :filters

	def initialize(schema, sql_path, passwd, host)
		init_schema(schema)
		init_db(sql_path, passwd, host)
		init_log()
		
		# Create datasets
		@files		= @db[:files]
		@contents	= @db[:contents]
		@entry_points	= @db[:entry_points]
		@filters	= @db[:filters]
	end

	def init_schema(schema)
		@schema = schema
	end

	def init_db(sql_path, passwd, host)
		@db = Sequel.postgres(
    		    sql_path,
    		    :user => @schema,
    		    :password => passwd,
    		    :host => host
		)
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

	# Collects statistical information about all regular files
	# inside entry point
	def collect(directory, pattern)
		result = []
		current = []
	begin
		Dir.foreach(directory) do |file|
			file.force_encoding('UTF-8')
                        unless file.valid_encoding?
				@log.warn { "Non-UTF8 file name \"#{file}\"" }
				next
			end
			next if ('.' == file) || ('..' == file)
			
			fullpath = "#{directory}/#{file}"
			file_stats = File.lstat(fullpath)
			if file_stats.directory?
				@log.debug { "DIR #{fullpath}" }
				result.concat(collect(fullpath, pattern))
			elsif file_stats.file? and file =~ pattern
				current << FileInfo.new(file, directory, file_stats.mtime.utc, file_stats.size)
			end
		end
	rescue Errno::EACCES => exp
		@log.warn { "#{exp.message}" }
	end
		@log.debug { "SUM (#{current.length}:#{result.length}) IN #{directory}" }
		result.concat(current)
	end

	# Calculate file checksum (SHA1)
	def get_checksum(filename)
		digest = Digest::SHA1.new
	begin
		file = File.new(filename)
		while buffer = file.read(65536)
			digest << buffer
		end
		@log.info { digest.hexdigest.downcase + ' ' + filename }
		digest.hexdigest.downcase
        rescue Errno::EACCES, Errno::ETXTBSY => exp
		@log.warn { "#{exp.message}" }
		false
	end
	end

	# Create DB tables
	def create_tables()
		@db.create_table? :files do
			primary_key	:id
			String		:name
			String		:full_path
			Fixnum		:checksum_id
			Bignum		:size
			Fixnum		:entry_point_id
			Time		:modification_time
		end

		@db.create_table? :contents do
			primary_key	:id
			String		:checksum
			Bignum		:size
			Time		:first_appearance_time
		end

		@db.create_table? :entry_points do
			primary_key	:id
			String		:name
			String		:server
			String		:full_path
			String		:table_for_update
		end

		@db.create_table? :filters do
			primary_key	:id
			Fixnum		:entry_point_id
			Boolean		:filter_in
			String		:regexp
		end
	end

	def table_exists?(name)
		#@db["SELECT * FROM information_schema.tables WHERE table_schema = '#{@schema}' AND table_name = '#{name}'"].all.any?
		@db.table_exists?(name)
	end

	def create_temp_files_table(temp_files_name)
		@log.debug "Create temporary table #{temp_files_name}"

		if table_exists?(temp_files_name)
			@db.drop_table(temp_files_name)
		end

		@db.create_table? temp_files_name do
			primary_key	:id
			String		:name
			String		:full_path
			Fixnum		:checksum_id
			Bignum		:size
			Fixnum		:entry_point_id
			Time		:modification_time
		end

		@db[:"#{temp_files_name}"]
	end

	def file_record_found(file_records, file_info)
		record = file_records[file_info.name]
		if record.is_a?(Array)
			if (record[0] == file_info.size) and (record[1].tv_sec == file_info.modification_time.tv_sec)
				return record[2]
			end
			@log.debug { 'File updated: ' + file_info.name }
			@log.debug { "size: #{record[0]}, time: #{record[1].tv_sec} to size: #{file_info.size}, time: #{file_info.modification_time.tv_sec}" }
		end
		@log.debug { 'No cache record: ' + file_info.name }
		return nil
	end

	def show_updates(entry_point, pattern=//)
		entry_point_dataset = @entry_points.where(:full_path => entry_point)
		if (not entry_point_dataset.any?)
			@log.warn { "Entry point " + entry_point + " was not found in DB" }
			return
		end

		current_path = ''
		file_records = Hash.new

		collect(entry_point, pattern).each do |file_info|
			full_path = file_info.path + '/' + file_info.name
			@log.debug { full_path }

			# get all file records for given path
			if current_path != file_info.path
				current_path = file_info.path
				file_records = Hash.new
				@files.where(:full_path => current_path).each {|f|
					f[:name].force_encoding('UTF-8')
					file_records[f[:name]] = [f[:size], f[:modification_time], f[:checksum_id]]}
				@log.debug { "Current path = " + current_path + " (" + file_records.length().to_s + ")" }
			end

			# checking that checksum is calculated already
			@log.info { full_path } unless file_record_found(file_records, file_info)
		end
	end

	def update_entry_point(entry_point, pattern=//)
		entry_point_dataset = @entry_points.where(:full_path => entry_point)
		if (not entry_point_dataset.any?)
			@log.warn { "Entry point " + entry_point + " was not found in DB" }
			return
		end
		entry_point_record = entry_point_dataset.first
		entry_point_id = entry_point_record[:id] 
		temp_files_name = entry_point_record[:table_for_update]

		# Create temporary files table
		temp_files = create_temp_files_table(temp_files_name)

		current_path = ''
		file_records = Hash.new
		records = []

		collect(entry_point, pattern).each do |file_info|
			full_path = file_info.path + '/' + file_info.name
			@log.debug { full_path }

			# get all file records for given path
			if current_path != file_info.path
				current_path = file_info.path
				file_records = Hash.new
				@files.where(:full_path => current_path).each {|f|
					f[:name].force_encoding('UTF-8')
					file_records[f[:name]] = [f[:size], f[:modification_time].utc, f[:checksum_id]]}
				@log.debug { "Current path = " + current_path + " (" + file_records.length().to_s + ")" }
			end

			# checking that checksum is calculated already
			checksum_id = file_record_found(file_records, file_info)
			
			unless checksum_id
				# new/modified file found
				next unless checksum = get_checksum(full_path)
				if file_info.is_changed?
					@log.warn { "File was changed: " + full_path }
					next
				end
				
				# store new checksum if needed
				fchecksum = @contents.filter(:checksum => checksum)
				if not fchecksum.any?
					@contents.insert(:checksum => checksum, :size => file_info.size, :first_appearance_time => 'now()')
					fchecksum = @contents.filter(:checksum => checksum)
				end
				checksum_id = fchecksum.first[:id]
			end

			records.push([file_info.name, file_info.path, file_info.size, file_info.modification_time, checksum_id, entry_point_id])

			if records.length > 99
				@log.info { "Inserting " + records.length.to_s + " records to the temporary table" }
				temp_files.import([:name, :full_path, :size, :modification_time, :checksum_id, :entry_point_id], records, :slice => 100)
				records = []
			end
		end

		if records.length > 0
			@log.info { "Inserting " + records.length.to_s + " records to the temporary table" }
			temp_files.import([:name, :full_path, :size, :modification_time, :checksum_id, :entry_point_id], records, :slice => 100)
			records = []
		end

		# Delete all records and add updated ones by one transaction
		@db << "START TRANSACTION"
		@log.debug "Transaction started"
		@files.filter(:entry_point_id => entry_point_id).delete
		@log.debug "Records were deleted"
		@db << "insert into files (name,full_path,checksum_id,size,entry_point_id,modification_time) select name,full_path,checksum_id,size,entry_point_id,modification_time from \"#{temp_files_name}\""
		@log.debug "Records were inserted"
		@db.drop_table(:"#{temp_files_name}")
		@log.debug "Temporal table was dropped"
		@db << "COMMIT"
		@log.debug "Transaction finished"
	end
end

####################
# Query Layer 
####################

class QueryLayer
	attr_accessor :db, :schema, :log, :files, :contents, :entry_points, :filters

	def initialize(schema, sql_path, passwd, host)
		init_schema(schema)
		init_db(sql_path, passwd, host)
		init_log()
		# Create datasets
		@files			= @db[:files]
		@contents		= @db[:contents]
		@entry_points	= @db[:entry_points]
		@filters		= @db[:filters]
	end

	def init_schema(schema)
		@schema = schema
	end

	def init_db(sql_path, passwd, host)
		@db = Sequel.postgres(
    		    sql_path,
    		    :user => @schema,
    		    :password => passwd,
    		    :host => host
		)
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

	def get_all_occurences(checksum)
		occs = @db["SELECT * FROM files, contents WHERE contents.checksum = '#{checksum}' and contents.id = files.checksum_id"].all
		occs.map {|occ| 
			FileInfo.new(occ[:name], occ[:full_path], occ[:modification_time], occ[:size])
		}
	end

	def get_all_occurences_inside_entry_points(checksum, entry_points_arr)
		occs = @db["SELECT * FROM files, contents WHERE contents.checksum = '#{checksum}' and contents.id = files.checksum_id"].all
		res = []
		occs.each do |occ|
			if entry_points_arr.include?(occ[:entry_point_id])
			  res << FileInfo.new(occ[:name], occ[:full_path], occ[:modification_time], occ[:size])
			end 	  
		end
		res
	end

	def file_exists?(checksum, entry_points_arr)
		!(get_all_occurences_inside_entry_points(checksum, entry_points_arr).empty?)
	end

	def get_status(entry_point_id)
		status = []
		res = @db["SELECT checksum FROM contents, files WHERE entry_point_id = #{entry_point_id} AND contents.id = files.checksum_id"].all
		res.each do |r|
			status << r[:checksum]
		end
		status
	end

	def get_status_diff(status1, status2, first2second)
		first2second ? (status1 - status2) : (status2 - status1)
	end
end
