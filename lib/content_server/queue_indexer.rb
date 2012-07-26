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
        server_content_data.from_file(@content_data_path) rescue Errno::ENOENT
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

              if index_agent.failed_files
                Log.info("Failed files: #{index_agent.failed_files.to_a.join(',')}.")
              end

              server_content_data.merge index_agent.indexed_content
              # TODO(kolman): Don't write to file each change?
              Log.info "Writing server content data to #{@content_data_path}."
              server_content_data.to_file(@content_data_path)

              Log.info 'Adding server content data to queue.'
              @output_queue.push(server_content_data)
            end
            #Log.info 'End of if.'
          end  # while true do
        end  # Thread.new do
        thread
      end  # def run

    end  # class QueueIndexer
  end
end
