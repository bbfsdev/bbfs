require 'file_indexing/index_agent'
require 'file_indexing/indexer_patterns'
require 'log'

module ContentServer

  # Simple indexer, gets inputs events (files to index) and outputs
  # content data updates into output queue.
  class QueueIndexer

    def initialize(input_queue, output_queue, content_data_path)
      @input_queue = input_queue
      @output_queue = output_queue
      @content_data_path = content_data_path
    end

    def run
      server_content_data = ContentData::ContentData.new
      # Shallow check content data files.
      tmp_content_data = ContentData::ContentData.new
      tmp_content_data.from_file(@content_data_path) if File.exists?(@content_data_path)
      tmp_content_data.instances.each_value do |instance|
        # Skipp instances (files) which did not pass the shallow check.
        Log.info('Shallow checking content data:')
        if shallow_check(instance)
          Log.info("exists: #{instance.full_path}")
          server_content_data.add_content(tmp_content_data.contents[instance.checksum])
          server_content_data.add_instance(instance)
        else
          Log.info("changed: #{instance.full_path}")
          # Add non existing and changed files to index queue.
          @input_queue.push([FileMonitoring::FileStatEnum::STABLE, instance.full_path])
        end
      end

      # Start indexing on demand and write changes to queue
      thread = Thread.new do
        while true do
          Log.info 'Waiting on index input queue.'
          state, is_dir, path = @input_queue.pop
          Log.info "event: #{state}, #{is_dir}, #{path}."

          # index files and add to copy queue
          # delete directory with it's sub files
          # delete file
          if state == FileMonitoring::FileStatEnum::STABLE && !is_dir
            Log.info "Indexing content #{path}."
            index_agent = FileIndexing::IndexAgent.new
            indexer_patterns = FileIndexing::IndexerPatterns.new
            indexer_patterns.add_pattern(path)
            index_agent.index(indexer_patterns, server_content_data)
            Log.info("Failed files: #{index_agent.failed_files.to_a.join(',')}.") \
                  if !index_agent.failed_files.empty?
            Log.info("indexed content #{index_agent.indexed_content}.")
            server_content_data.merge index_agent.indexed_content
          elsif ((state == FileMonitoring::FileStatEnum::NON_EXISTING ||
              state == FileMonitoring::FileStatEnum::CHANGED) && !is_dir)
            # If file content changed, we should remove old instance.
            key = FileIndexing::IndexAgent.global_path(path)
            # Check if deleted file exists at content data.
            Log.info("Instance to remove: #{key}")
            if server_content_data.instances.key?(key)
              instance_to_remove = server_content_data.instances[key]
              # Remove file from content data only if it does not pass the shallow check, i.e.,
              # content has changed/removed.
              if !shallow_check(instance_to_remove)
                content_to_remove = server_content_data.contents[instance_to_remove.checksum]
                # Remove the deleted instance.
                content_data_to_remove = ContentData::ContentData.new
                content_data_to_remove.add_content(content_to_remove)
                content_data_to_remove.add_instance(instance_to_remove)
                # Remove the file.
                server_content_data = ContentData::ContentData.remove_instances(
                    content_data_to_remove, server_content_data)
              end
            end
          elsif state == FileMonitoring::FileStatEnum::NON_EXISTING && is_dir
            Log.info("NonExisting/Changed: #{path}")
            # Remove directory but only when non-existing.
            Log.info("Directory to remove: #{path}")
            global_dir = FileIndexing::IndexAgent.global_path(path)
            server_content_data = ContentData::ContentData.remove_directory(
                server_content_data, global_dir)
          else
            Log.info("This case should not be handled: #{state}, #{is_dir}, #{path}.")
          end
          # TODO(kolman): Don't write to file each change?
          Log.info "Writing server content data to #{@content_data_path}."
          server_content_data.to_file(@content_data_path)

          Log.info 'Adding server content data to queue.'
          @output_queue.push(ContentData::ContentData.new(server_content_data))
        end  # while true do
      end  # Thread.new do
      thread
    end  # def run

    # Check file existence, check it's size and modification date.
    # If something wrong reindex the file and update content data.
    def shallow_check(instance)
      shallow_instance = FileIndexing::IndexAgent.create_shallow_instance(instance.full_path)
      return false unless shallow_instance
      return (shallow_instance.size == instance.size &&
          shallow_instance.modification_time == instance.modification_time)
    end

  end  # class QueueIndexer
end

