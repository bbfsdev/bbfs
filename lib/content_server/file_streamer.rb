require 'thread'

require 'file_indexing/index_agent'
require 'log'

module BBFS
  module ContentServer

    Params.integer('streaming_chunk_size', 64*1024,
                   'Max number of content bytes to send in one chunk.')
    Params.integer('file_streaming_timeout', 5*60,
                   'If no action is taken on a file streamer, abort copy.')

    class Stream
      attr_reader :checksum, :path, :file

      def initialize(checksum, path, file)
        @checksum = checksum
        @path = path
        @file = file
      end

    end

    class FileStreamer
      attr_reader :thread

      :NEW_STREAM
      :ABORT_STREAM
      :COPY_CHUNK

      def initialize(send_chunk_clb, abort_streaming_clb=nil)
        @send_chunk_clb = send_chunk_clb
        @abort_streaming_clb = abort_streaming_clb
        @thread = run
        @stream_queue = Queue.new

        # Used from internal thread only.
        @streams = {}
      end

      def start_streaming(checksum, path)
        @stream_queue << [:NEW_STREAM, [checksum, path]]
      end

      def abort_streaming(checksum)
        @stream_queue << [:ABORT_STREAM, checksum]
      end

      def run
        Thread.new begin
          loop {
            checksum = handle(@stream_queue.pop)
            checksum?!?!?!?!?!?!
            HOW TO POPULATE THIS QUEUE?! WITH COPY
          }
        end
      end

      def handle(message)
        type, content = message
        if type == :NEW_STREAM
          checksum, path = content
          begin
            file = File.new(path, 'rb')
          rescue IOError => e
            Log.warning("Could not stream local file #{path}. #{e.to_s}")
          end
          @streams[checksum] = Stream.new(checksum, path, file)
        elsif type = :ABORT_STREAM
          close_delete_stream(content)
        elsif type = :COPY_CHUNK
          checksum = content
          if @streams.key?(checksum)
            chunk = @streams.file.read(Params['streaming_chunk_size'])
            if !chunk
              # No more to read, send end of file.
              @send_chunk_clb.call(checksum, nil, nil)
              close_delete_stream(checksum)
            else
              chunk_checksum = FileIndexing::IndexAgent.get_content_checksum(chunk)
              @send_chunk_clb.call(checksum, chunk, chunk_checksum)
            end
          else
            Log.info("No checksum found to copy chunk. #{checksum}.")
          end
        end

      end

      def close_delete_stream(checksum)
        if @streams.key?(checksum)
          begin
            @streams[checksum].file.close()
          rescue IOError => e
            Log.warning("While closing stream, could not close file #{@streams[checksum].path}." \
                        " #{e.to_s}")
          end
          @streams.delete(checksum)
        end
      end

    end

    # Start implementing as dummy, no self thread for now.
    # Later when we need it to response and send aborts, timeouts, ect, it will
    # need self thread.
    class FileReceiver

      def initialize(file_done_clb)
        @file_done_clb = file_done_clb
      end

      def receive_chunk(file_checksum, content, content_checksum)
      end

    end

  end
end
