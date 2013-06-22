require 'file_indexing/index_agent'
require 'file_indexing/indexer_patterns'
require 'content_server/globals'
require 'log'
require 'params'

module ContentServer

  # Simple indexer, gets inputs events (files to index) and outputs
  # content data updates into output queue.
  class QueueIndexer

    def initialize(input_queue, local_dynamic_content_data)
      @input_queue = input_queue
      @local_dynamic_content_data = local_dynamic_content_data
    end

    # index files and add to copy queue
    # delete directory with it's sub files
    # delete file
    def run
      # Start indexing on demand and write changes to queue
      thread = Thread.new do
        while true do
          Log.debug1 'Waiting on index input queue.'
          (state, is_dir, path, mtime, size) = @input_queue.pop
          Log.debug1 "index event: state:#{state}, dir?#{is_dir}, path:#{path}, mtime:#{mtime}, size:#{size}."
          if state == FileMonitoring::FileStatEnum::STABLE && !is_dir
            # Calculating checksum
            instance_stats = @local_dynamic_content_data.stats_by_location([Params['local_server_name'], path])
            Log.debug1("instance !#{instance_stats}! mtime: #{mtime.to_i}, size: #{size}")
            if instance_stats.nil? || mtime.to_i != instance_stats[1] || size != instance_stats[0]
              Log.info "Indexing file:'#{path}'."
              checksum = calc_SHA1(path)
              if Params['enable_monitoring']
                ::ContentServer::Globals.process_vars.inc('indexed_files')
              end
              Log.debug1("Index info:checksum:#{checksum} size:#{size} time:#{mtime.to_i}")
              Log.debug1('Adding index to content data. put in queue for dynamic update.')
              @local_dynamic_content_data.add_instance(checksum, size, Params['local_server_name'], path, mtime.to_i)
            else
              Log.info("Skip file #{path} indexing (shallow check passed)")
            end
          elsif ((state == FileMonitoring::FileStatEnum::NON_EXISTING ||
              state == FileMonitoring::FileStatEnum::CHANGED) && !is_dir)
            Log.debug2("NonExisting/Changed (file): #{path}")
            # Remove directory but only when non-existing.
            Log.debug1("File to remove: #{path}")
            @local_dynamic_content_data.remove_instance([Params['local_server_name'],path])
          elsif state == FileMonitoring::FileStatEnum::NON_EXISTING && is_dir
            Log.debug2("NonExisting/Changed (dir): #{path}")
            # Remove directory but only when non-existing.
            Log.debug1("Directory to remove: #{path}")
            @local_dynamic_content_data.remove_directory(path, Params['local_server_name'])
          else
            Log.debug1("This case should not be handled: #{state}, #{is_dir}, #{path}.")
          end
        end  # while true do
      end  # Thread.new do
      thread
    end  # def run

    # Opens file and calculates SHA1 of it's content, returns SHA1
    def calc_SHA1(path)
      begin
        digest = Digest::SHA1.new
        File.open(path, 'rb') { |f|
          while buffer = f.read(65536) do
            digest << buffer
          end
        }
      rescue
       Log.warning("Monitored path'#{path}' does not exist. Probably file changed")
      end
      return digest.hexdigest.downcase
    end

    # Remove when not needed.
    # Check file existence, check it's size and modification date.
    # If something wrong reindex the file and update content data.
    #def shallow_check(file_name, file_size, file_mod_time)
    #  shallow_instance = FileIndexing::IndexAgent.create_shallow_instance(file_name)
    #  return false unless shallow_instance
    #  return (shallow_instance[0] == file_size &&
    #      shallow_instance[2] == file_mod_time)
    #end

  end  # class QueueIndexer
end

