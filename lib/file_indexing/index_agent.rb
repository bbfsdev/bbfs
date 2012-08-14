require 'digest/sha1'
require 'pp'
require 'set'
require 'time'

require 'content_data'
require 'file_indexing/indexer_patterns'
require 'log'

module BBFS
  module FileIndexing

####################
# Index Agent
####################

    class IndexAgent
      attr_reader :indexed_content, :failed_files

      # Why are those lines needed?
      LOCALTZ = Time.now.zone
      ENV['TZ'] = 'UTC'

      def initialize
        @indexed_content = ContentData::ContentData.new
        @failed_files = Set.new
      end

      # Calculate file checksum (SHA1)
      def self.get_checksum(filename)
        digest = Digest::SHA1.new
        begin
          File.open(filename, 'rb') { |f|
            while buffer = f.read(65536) do
              digest << buffer
            end
          }
          Log.debug1("#{filename} sha1 #{digest.hexdigest.downcase}")
          digest.hexdigest.downcase
        rescue Errno::EACCES, Errno::ETXTBSY => exp
          Log.warning("#{exp.message}")
          false
        end
      end

      def IndexAgent.get_content_checksum(content)
        # Calculate checksum.
        digest = Digest::SHA1.new
        digest << content
        digest.hexdigest.downcase
      end

      # get all files
      # satisfying the pattern
      def collect(pattern)
        Dir.glob(pattern.to_s)
      end

      # TODO(kolman): Replace this with File.lstat(file).mtime when new version of Ruby comes out.
      # http://bugs.ruby-lang.org/issues/6385
      def IndexAgent.get_correct_mtime(file)
        begin
        File.open(file, 'r') { |f| f.mtime }
        rescue Errno::EACCES => e
          Log.warning("Could not open file #{file} to get mtime. #{e}")
          return 0
        end
      end

      # index device according to the pattern
      # store the result
      # does not adds automatically otherDB to stored result
      # TODO device support
      def index(patterns, otherDB = nil)
        abort "#{self.class}: DB not empty. Current implementation permits only one running of index" \
            unless @indexed_content.contents.empty?

        server_name = `hostname`.strip
        permit_patterns = Array.new
        forbid_patterns = Array.new
        otherDB_table = Hash.new   # contains instances from given DB while full path name is a key and instance is a value
        otherDB_contents = Hash.new  # given DB contents

        # if there is a given DB then populate table with files
        # that was already indexed on this server/device
        if (otherDB != nil)
          otherDB_contents.update(otherDB.contents)
          otherDB.instances.each_value do |i|
            next unless i.server_name == server_name #and i.device == @device
            otherDB_table[i.full_path] = i
          end
        end

        permit_patterns = patterns.positive_patterns
        forbid_patterns = patterns.negative_patterns

        # add files found by positive patterns
        files = Array.new
        permit_patterns.each_index do |i|
          files = files | (collect(permit_patterns[i]));
        end

        Log.info "Files: #{files}."

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
          file_mtime = IndexAgent.get_correct_mtime(file)

          # index only files
          next if file_stats.directory?

          # keep only files with names in UTF-8
          unless file.force_encoding("UTF-8").valid_encoding?
            Log.warning("Non UTF-8 file name \"#{file}\", skipping.")
            next
          end

          # add files present in the given DB to the DB and remove these files
          # from further processing (save checksum calculation)
          if otherDB_table.has_key?(file)
            instance = otherDB_table[file]
            if instance.size == file_stats.size and instance.modification_time == file_mtime
              @indexed_content.add_content(otherDB_contents[instance.checksum])
              @indexed_content.add_instance(instance)
              next
            else
              Log.warning("File (#{file}) size or modification file is different.")
            end
          end

          # calculate a checksum
          unless (checksum = self.class.get_checksum(file))
            Log.warning("Cheksum failure: " + file)
            @failed_files.add(file)
            next
          end

          if !@indexed_content.content_exists(checksum)
            @indexed_content.add_content ContentData::Content.new(checksum, file_stats.size,
                                                                  Time.now.utc)
          end

          instance = ContentData::ContentInstance.new(
              checksum, file_stats.size, server_name, file_stats.dev.to_s,
              File.expand_path(file), file_mtime)
          @indexed_content.add_instance(instance)
        end
      end

      def IndexAgent.create_shallow_instance(filename)
        return nil unless File.exists?(filename)
        file_stats = File.lstat(filename)
        file_mtime = IndexAgent.get_correct_mtime(filename)
        ContentData::ContentInstance.new(nil, file_stats.size, nil, file_stats.dev.to_s,
                                         File.expand_path(filename), file_mtime)
      end

      def IndexAgent.global_path(filename)
        return nil unless File.exists?(filename)
        server_name = `hostname`.strip
        file_stats = File.lstat(filename)
        device = file_stats.dev.to_s
        return ContentData::ContentInstance.instance_global_path(server_name, device, filename)
      end
    end

  end
end
