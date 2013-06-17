require 'file_indexing/index_agent'
require 'file_indexing/indexer_patterns'
require 'log'

module ContentServer

  # Simple indexer, gets inputs events (files to index) and outputs
  # content data updates into output queue.
  class QueueIndexer

    def initialize(input_queue, output_queue, local_dynamic_content_data)
      @input_queue = input_queue
      @output_queue = output_queue
      @local_dynamic_content_data = local_dynamic_content_data
    end

    # index files and add to copy queue
    # delete directory with it's sub files
    # delete file
    def run
      server_content_data = ContentData::ContentData.new
      # Start indexing on demand and write changes to queue
      thread = Thread.new do
        while true do
          Log.debug1 'Waiting on index input queue.'
          (state, is_dir, path) = @input_queue.pop
          Log.debug1 "index event: state:#{state}, dir?#{is_dir}, path:#{path}."

          if state == FileMonitoring::FileStatEnum::STABLE && !is_dir
            # Calculating checksum
            instance = local_dynamic_content_data.instance_by_path(path)
            if !instance.nil? && shallow_check()
            Log.info "Indexing file:'#{path}'."
            checksum = calc_SHA1(path)
            file_stats = File.lstat(path)
            Log.debug1("Index info:checksum:#{checksum} size:#{file_stats.size} time:#{file_stats.mtime.to_i}")
            Log.debug1('Adding index to content data. put in queue for dynamic update.')
            server_content_data.add_instance(checksum, file_stats.size, Params['local_server_name'], file_stats.dev.to_s, path, file_stats.mtime.to_i)
            @output_queue.push(server_content_data)
          elsif ((state == FileMonitoring::FileStatEnum::NON_EXISTING ||
              state == FileMonitoring::FileStatEnum::CHANGED) && !is_dir)
            Log.debug2("NonExisting/Changed: #{path}")
            # Remove directory but only when non-existing.
            Log.debug1("File to remove: #{path}")
            server_content_data = ContentData.remove_directory(
                server_content_data, path)
            #TODO: [yaron dror] Currently we remove ALL paths from all instances. If same
            #TODO: path is shared across many servers this is an issue
            Log.debug1('Adding server content data to output queue.')
            @output_queue.push(server_content_data)
          elsif state == FileMonitoring::FileStatEnum::NON_EXISTING && is_dir
            Log.debug2("NonExisting/Changed: #{path}")
            # Remove directory but only when non-existing.
            Log.debug1("Directory to remove: #{path}")
            server_content_data = ContentData.remove_directory(
                server_content_data, path)
            #TODO: [yaron dror] Currently we remove ALL paths from all instances. If same
            #TODO: path is shared across many servers this is an issue
            Log.debug1('Adding server content data to output queue.')
            @output_queue.push(server_content_data)
          else
            Log.debug1("This case should not be handled: #{state}, #{is_dir}, #{path}.")
          end
        end  # while true do
      end  # Thread.new do
      thread
    end  # def run

    # Opens file and calculates SHA1 of it's content, returns SHA1
    def calc_SHA1(path)
      digest = Digest::SHA1.new
      File.open(path, 'rb') { |f|
        while buffer = f.read(65536) do
          digest << buffer
        end
      }
      return digest.hexdigest.downcase
    end

    # Check file existence, check it's size and modification date.
    # If something wrong reindex the file and update content data.
    def shallow_check(file_name, file_size, file_mod_time)
      shallow_instance = FileIndexing::IndexAgent.create_shallow_instance(file_name)
      return false unless shallow_instance
      return (shallow_instance[0] == file_size &&
          shallow_instance[2] == file_mod_time)
    end

  end  # class QueueIndexer
end

