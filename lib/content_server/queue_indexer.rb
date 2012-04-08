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
        server_content_data.from_file(@content_data_path)
        # Start indexing on demand and write changes to queue
        thread = Thread.new do
          while true do
            event = input_queue.pop
            # index files and add to copy queue
            if (event[0] == FileStatEnum.CHANGED || event[0] == FileStatEnum.NEW)
              index_agent = IndexAgent.new
              indexer_patterns = IndexerPatterns.new
              indexer_patterns.add_pattern(event[1])
              index_agent.index(indexer_patterns)
              server_content_data.merge(index_agent.indexed_content)
              # TODO(kolman) Don't write to file each change?
              server_content_data.to_file(@content_data_path)
              output_queue.push(server_content_data)
            end
          end  # while true do
        end  # Thread.new do
        thread
      end  # def run

    end  # class QueueIndexer
  end
end
