require 'tempfile'
require 'thread'

require 'file_indexing/index_agent'
require 'log'

module BBFS
  module ContentServer

    Params.integer('streaming_chunk_size', 64*1024,
                   'Max number of content bytes to send in one chunk.')
    Params.integer('file_streaming_timeout', 5*60,
                   'If no action is taken on a file streamer, abort copy.')
    Params.string('backup_destination_folder', '',
                  'Backup server destination folder, default is the relative local folder.')

    class Stream
      attr_reader :checksum, :path, :file, :size
      def initialize(checksum, path, file, size)
        @checksum = checksum
        @path = path  # TODO do we actually need this parameter?
        @file = file
        @size = size
      end

      def self.close_delete_stream(checksum, streams_hash)
        if streams_hash.key?(checksum)
          Log.info("close_delete_stream #{streams_hash[checksum].file}")
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
        return Thread.new do
          loop {
            checksum = handle(@stream_queue.pop)
          }
        end
      end

      def handle(message)
        type, content = message
        if type == :NEW_STREAM
          checksum, path = content
          if !@streams.key? checksum
            begin
              file = File.new(path, 'rb')
              Log.info("File streamer: #{file.to_s}.")
            rescue IOError => e
              Log.warning("Could not stream local file #{path}. #{e.to_s}")
            end
            @streams[checksum] = Stream.new(checksum, path, file, file.size)
            @stream_queue << [:COPY_CHUNK, checksum]
          end
        elsif type == :ABORT_STREAM
          Stream.close_delete_stream(content, @streams) # content is the checksum
        elsif type == :COPY_CHUNK
          checksum = content
          if @streams.key?(checksum)
            chunk = @streams[checksum].file.read(Params['streaming_chunk_size'])
            if chunk.nil?
              # No more to read, send end of file.
              @send_chunk_clb.call(checksum, @streams[checksum].size, nil, nil)
              Stream.close_delete_stream(checksum, @streams)
            else
              chunk_checksum = FileIndexing::IndexAgent.get_content_checksum(chunk)
              @send_chunk_clb.call(checksum, @streams[checksum].size, chunk, chunk_checksum)
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

      def initialize(file_done_clb=nil, file_abort_clb=nil)
        @file_done_clb = file_done_clb
        @file_abort_clb = file_abort_clb
        @streams = {}
      end

      def receive_chunk(file_checksum, file_size, content, content_checksum)
        if !content.nil? && !content_checksum.nil?
          received_content_checksum = FileIndexing::IndexAgent.get_content_checksum(content)
          comment = "Calculated received chunk with content checksum #{received_content_checksum}" \
                    " vs message content checksum #{content_checksum}, " \
                    "file checksum #{file_checksum}"
          Log.debug1(comment) if content_checksum == received_content_checksum
          # TODO should there be a somekind of abort?
          Log.error(comment) if content_checksum != received_content_checksum

          if !@streams.key?(file_checksum)
            handle_new_stream(file_checksum, file_size)
          end
          # We still check @streams has the key, because file can fail to open.
          if @streams.key?(file_checksum)
            handle_new_chunk(file_checksum, content)
          end
        elsif content.nil? && content_checksum.nil?
          handle_last_chunk(file_checksum)
        else
          Log.warning("Unexpected receive chuck message. file_checksum:#{file_checksum}, " \
                      "content.nil?:#{content.nil?}, content_checksum:#{content_checksum}")
        end
      end

      def handle_new_stream(file_checksum, file_size)
        #open new stream
        # final destination path
        path = FileReceiver.destination_filename(Params['backup_destination_folder'],
                                                 file_checksum)
        if File.exists?(path)
          Log.warning("File already exists (#{path}) not writing.")
          @file_abort_clb.call(file_checksum) unless @file_abort_clb.nil?
        else
          begin
            # the file will be copied from tmp location once the transfer will be done
            # system will use the checksum and some more unique key for tmp file name
            tmp_file = Tempfile.new(file_checksum)
            @streams[file_checksum] = Stream.new(file_checksum, path, tmp_file, file_size)
          rescue IOError => e
            Log.warning("Could not stream write to local file #{path}. #{e.to_s}")
          end
        end
      end

      def handle_new_chunk(file_checksum, content)
        # write chunk to temp file
        FileReceiver.write_string_to_file(content, @streams[file_checksum].file)
        Log.info("Written already #{@streams[file_checksum].file.size} bytes, " \
                 "out of #{@streams[file_checksum].size} " \
                 "(#{100.0*@streams[file_checksum].file.size/@streams[file_checksum].size}%)")
      end

      def handle_last_chunk(file_checksum)
        if @streams.key?(file_checksum)
          begin
            # Make the directory if does not exists.
            Log.debug1("Writing to: #{@streams[file_checksum].path}")
            Log.debug1("Creating directory: #{File.dirname(@streams[file_checksum].path)}")
            FileUtils.makedirs(File.dirname(@streams[file_checksum].path))
            #copy tmp file to permanent location
            Log.info("Start copy tmp file:'#{@streams[file_checksum].file.path}' to permanent " \
                     "location:'#{@streams[file_checksum].path}'")
            ::FileUtils::copy_file(@streams[file_checksum].file.path, @streams[file_checksum].path)
            Log.info("end copy tmp file to permanent location")
          rescue IOError => e
            Log.warning("Could not stream write to local file #{path}. #{e.to_s}")
          end
          # Check written file checksum!
          local_path = @streams[file_checksum].path
          tmp_file = @streams[file_checksum].file
          Stream.close_delete_stream(file_checksum, @streams)  # temp file will be closed here
          tmp_file.unlink  # deletes the temp file

          local_file_checksum = FileIndexing::IndexAgent.get_checksum(local_path)
          message = "Local checksum (#{local_file_checksum}) received checksum (#{file_checksum})."
          local_file_checksum == file_checksum ? Log.info(message) : Log.error(message)
          Log.info("File fully received #{local_path}")
          @file_done_clb.call(local_file_checksum, local_path) unless @file_done_clb.nil?
        end
      end

      def self.write_string_to_file(str, file)
        Log.info("writing to file: #{file.to_s}.")
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

      private :handle_new_stream, :handle_new_chunk, :handle_last_chunk
    end

  end
end
