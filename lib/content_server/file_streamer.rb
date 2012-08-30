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

      def self.close_delete_stream(checksum, streams_hash)
        if streams_hash.key?(checksum)
          begin
            streams_hash[checksum].file.close()
          rescue IOError => e
            Log.warning("While closing stream, could not close file #{streams_hash[checksum].path}." \
                        " #{e.to_s}")
          end
          streams_hash.delete(checksum)
        end
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
        @stream_queue = Queue.new

        # Used from internal thread only.
        @streams = {}
        @thread = run
      end

      def start_streaming(checksum, path)
        @stream_queue << [:NEW_STREAM, [checksum, path]]
      end

      def abort_streaming(checksum)
        @stream_queue << [:ABORT_STREAM, checksum]
      end

      def run
        return Thread.new begin
          loop {
            checksum = handle(@stream_queue.pop)
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
          Stream.close_delete_stream(content, @streams)
        elsif type = :COPY_CHUNK
          checksum = content
          if @streams.key?(checksum)
            chunk = @streams.file.read(Params['streaming_chunk_size'])
            if !chunk
              # No more to read, send end of file.
              @send_chunk_clb.call(checksum, nil, nil)
              Stream.close_delete_stream(checksum, @streams)
            else
              chunk_checksum = FileIndexing::IndexAgent.get_content_checksum(chunk)
              @send_chunk_clb.call(checksum, chunk, chunk_checksum)
              @stream_queue << [:COPY_CHUNK, checksum]
            end
          else
            Log.info("No checksum found to copy chunk. #{checksum}.")
          end
        end

      end
    end

    # Start implementing as dummy, no self thread for now.
    # Later when we need it to response and send aborts, timeouts, ect, it will
    # need self thread.
    class FileReceiver

      def initialize(file_done_clb)
        @file_done_clb = file_done_clb
        @streams = {}
      end

      def receive_chunk(file_checksum, content, content_checksum)
        if !content.nil? && !content_checksum.nil?
          received_content_checksum = FileIndexing::IndexAgent.get_content_checksum(content)
          comment = "Calculated received chunk with content checksum #{received_content_checksum}" \
                    " vs message content checksum #{content_checksum}, " \
                    "file checksum #{file_checksum}"
          Log.debug1(comment) if content_checksum == received_content_checksum
          Log.error(comment) if content_checksum != received_content_checksum

          if @streams.key?(file_checksum)
            FileReceiver.write_string_to_file(content, @streams[file_checksum].file)
          else
            path = FileReceiver.destination_filename(Params['backup_destination_folder'],
                                                     file_checksum)
            begin
              file = File.new(path, 'wb')
            rescue IOError => e
              Log.warning("Could not stream write to local file #{path}. #{e.to_s}")
            end
            @streams[checksum] = Stream.new(checksum, path, file)
          end
        elsif content.nil? && content_checksum.nil?
          @streams[file_checksum].file.close() rescue IOError \
              Log.warning("Could not close received file properly #{file_checksum}")

          # Check written file checksum!
          local_file_checksum = FileIndexing::IndexAgent.get_checksum(@streams[file_checksum].path)
          message = "Local checksum (#{local_file_checksum}) received checksum #{file_checksum})"
          Log.info(message) ? local_file_checksum == file_checksum : Log.error(message)

          Stream.close_delete_stream(file_checksum, @streams)
        else
          Log.warning("Unexpected receive chuck message. file_checksum:#{file_checksum}, " \
                      "content.nil?:#{content.nil?}, content_checksum:#{content_checksum}")
        end
      end

      def self.write_string_to_file(str, file)
        bytes_to_write = str.bytesize
        while bytes_to_write > 0
          bytes_to_write -= file.write(str)
        end
      end

      # Creates destination filename for backup server, input is base folder and sha1.
      # for example: folder:/mnt/hd1/bbbackup, sha1:d0be2dc421be4fcd0172e5afceea3970e2f3d940
      # dest filename: /mnt/hd1/bbbackup/d0/be/2d/d0be2dc421be4fcd0172e5afceea3970e2f3d940
      def self.destination_filename(folder, sha1)
        File.join(folder, sha1[0,2], sha1[2,2], sha1)
      end

    end

  end
end
