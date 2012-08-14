require 'file_indexing/index_agent'
require 'file_indexing/indexer_patterns'
require 'log'

module BBFS
  module ContentServer

    # Simple indexer, gets inputs events (files to index) and outputs
    # content data updates into output queue.
    class QueueIndexer

      def initialize input_queue, output_queue, content_data_path
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
            event = @input_queue.pop
            Log.info "event: #{event}"
            # index files and add to copy queue
            if event[0] == FileMonitoring::FileStatEnum::STABLE
              Log.info "Indexing content #{event[1]}."
              index_agent = FileIndexing::IndexAgent.new
              indexer_patterns = FileIndexing::IndexerPatterns.new
              indexer_patterns.add_pattern(event[1])
              index_agent.index(indexer_patterns, server_content_data)
              Log.info("Failed files: #{index_agent.failed_files.to_a.join(',')}.") \
                       if !index_agent.failed_files.empty?
              server_content_data.merge index_agent.indexed_content
            elsif (event[0] == FileMonitoring::FileStatEnum::NON_EXISTING ||
                   # If file content changed, we should remove old instance.
                   event[0] == FileMonitoring::FileStatEnum::CHANGED)
              key = FileIndexing::IndexAgent.global_path(event[1])
              # Check if deleted file exists at content data.
              if server_content_data.instances.exists?(key)
                instance_to_remove = server_content_data.instances[key]
                # Remove file from content data only if it does not pass the shallow check, i.e.,
                # content has changed/removed.
                if !shallow_check(instance)
                  content_to_remove = server_content_data.contents[instance.checksum]
                  # Remove the deleted instance.
                  content_data_to_remove = ContentData::ContentData.new
                  content_data_to_remove.add_content(content_to_remove)
                  content_data_to_remove.add_instance(instance_to_remove)
                  # Remove the file.
                  server_content_data = ContentData::remove(content_data_to_remove, server_content_data)
                end
              end
            end
            # TODO(kolman): Don't write to file each change?
            Log.info "Writing server content data to #{@content_data_path}."
            server_content_data.to_file(@content_data_path)

            Log.info 'Adding server content data to queue.'
            @output_queue.push(server_content_data)
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
end
