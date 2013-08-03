require 'tempfile'
require 'thread'

require 'file_indexing/index_agent'
require 'content_server/server'
require 'log'
require 'params'


module ContentServer

  Params.integer('streaming_chunk_size', 2*1024*1024,
                 'Max number of content bytes to send in one chunk.')
  Params.integer('file_streaming_timeout', 5*60,
                 'If no action is taken on a file streamer, abort copy.')
  class Stream
    attr_reader :checksum, :path, :tmp_path, :file, :size
    def initialize(checksum, path, file, size)
      @checksum = checksum
      @path = path
      @file = file
      @size = size
    end

    def self.close_delete_stream(checksum, streams_hash)
      if streams_hash.key?(checksum)
        Log.debug1("close_delete_stream #{streams_hash[checksum].file}")
        begin
          streams_hash[checksum].file.close()
        rescue IOError => e
          Log.warning("While closing stream, could not close file #{streams_hash[checksum].path}." \
                        " #{e.to_s}")
        end
        streams_hash.delete(checksum)
        $process_vars.set('Streams size', streams_hash.size)
      end
    end

  end

  class FileStreamer
    attr_reader :thread

    :NEW_STREAM
    :ABORT_STREAM
    :RESET_STREAM
    :COPY_CHUNK

    def initialize(send_chunk_clb, abort_streaming_clb=nil)
      @send_chunk_clb = send_chunk_clb
      @abort_streaming_clb = abort_streaming_clb
      @stream_queue = Queue.new

      # Used from internal thread only.
      @streams = {}
      @thread = run
    end

    def copy_another_chuck(checksum)
      @stream_queue << [:COPY_CHUNK, checksum]
      $process_vars.set('File Streamer queue', @stream_queue.size)
    end

    def start_streaming(checksum, path)
      @stream_queue << [:NEW_STREAM, [checksum, path]]
      $process_vars.set('File Streamer queue', @stream_queue.size)
    end

    def abort_streaming(checksum)
      @stream_queue << [:ABORT_STREAM, checksum]
      $process_vars.set('File Streamer queue', @stream_queue.size)
    end

    def reset_streaming(checksum, new_offset)
      @stream_queue << [:RESET_STREAM, [checksum, new_offset]]
      $process_vars.set('File Streamer queue', @stream_queue.size)
    end

    def run
      return Thread.new do
        loop {
          stream_pop = @stream_queue.pop
          $process_vars.set('File Streamer queue', @stream_queue.size)
          checksum = handle(stream_pop)
        }
      end
    end

    def handle(message)
      type, content = message
      if type == :NEW_STREAM
        checksum, path = content
        reset_stream(checksum, path, 0)
        @stream_queue << [:COPY_CHUNK, checksum] if @streams.key?(checksum)
        $process_vars.set('File Streamer queue', @stream_queue.size)
      elsif type == :ABORT_STREAM
        checksum = content
        Stream.close_delete_stream(checksum, @streams)
      elsif type == :RESET_STREAM
        checksum, new_offset = content
        reset_stream(checksum, nil, new_offset)
        @stream_queue << [:COPY_CHUNK, checksum] if @streams.key?(checksum)
        $process_vars.set('File Streamer queue', @stream_queue.size)
      elsif type == :COPY_CHUNK
        checksum = content
        if @streams.key?(checksum)
          offset = @streams[checksum].file.pos
          Log.debug1("Sending chunk for #{checksum}, offset #{offset}.")
          chunk = @streams[checksum].file.read(Params['streaming_chunk_size'])
          if chunk.nil?
            # No more to read, send end of file.
            @send_chunk_clb.call(checksum, offset, @streams[checksum].size, nil, nil)
            Stream.close_delete_stream(checksum, @streams)
          else
            chunk_checksum = FileIndexing::IndexAgent.get_content_checksum(chunk)
            @send_chunk_clb.call(checksum, offset, @streams[checksum].size, chunk, chunk_checksum)
          end
        else
          Log.debug1("No checksum found to copy chunk. #{checksum}.")
        end
      end

    end

    def reset_stream(checksum, path, offset)
      if !@streams.key? checksum
        begin
          file = File.new(path, 'rb')
          if offset > 0
            file.seek(offset)
          end
          Log.debug1("File streamer: #{file.to_s}.")
          @streams[checksum] = Stream.new(checksum, path, file, file.size)
          $process_vars.set('Streams size', @streams.size)
        rescue IOError, Errno::ENOENT => e
          Log.warning("Could not stream local file #{path}. #{e.to_s}")
        end
      else
        @streams[checksum].file.seek(offset)
      end
    end
  end

  # Start implementing as dummy, no self thread for now.
  # Later when we need it to response and send aborts, timeouts, ect, it will
  # need self thread.
  class FileReceiver

    def initialize(file_done_clb=nil, file_abort_clb=nil, reset_copy=nil)
      @file_done_clb = file_done_clb
      @file_abort_clb = file_abort_clb
      @reset_copy = reset_copy
      @streams = {}
    end

    def receive_chunk(file_checksum, offset, file_size, content, content_checksum)
      # If standard chunk copy.
      if !content.nil? && !content_checksum.nil?
        received_content_checksum = FileIndexing::IndexAgent.get_content_checksum(content)
        comment = "Calculated received chunk with content checksum #{received_content_checksum}" \
                    " vs message content checksum #{content_checksum}, " \
                    "file checksum #{file_checksum}"
        Log.debug1(comment) if content_checksum == received_content_checksum
        # TODO should be here a kind of abort?
        if content_checksum != received_content_checksum
          Log.warning(comment)
          new_offset = 0
          if @streams.key?(file_checksum)
            new_offset = @streams[file_checksum].file.pos
          end
          @reset_copy.call(file_checksum, new_offset) unless @reset_copy.nil?
          return false
        end

        if !@streams.key?(file_checksum)
          handle_new_stream(file_checksum, file_size)
        end
        # We still check @streams has the key, because file can fail to open.
        if @streams.key?(file_checksum)
          return handle_new_chunk(file_checksum, offset, content)
        else
          Log.warning('Cannot handle chunk, stream does not exists, sending abort.')
          @file_abort_clb.call(file_checksum) unless @file_abort_clb.nil?
          return false
        end
        # If last chunk copy.
      elsif content.nil? && content_checksum.nil?
        Log.debug1('Handle the case of backup empty file or last chunk')
        # Handle the case of backup empty file or last chunk.
        handle_new_stream(file_checksum, 0) if !@streams.key?(file_checksum)
        # Finalize the file copy.
        handle_last_chunk(file_checksum)
      else
        Log.warning("Unexpected receive chuck message. file_checksum:#{file_checksum}, " \
                      "content.nil?:#{content.nil?}, content_checksum:#{content_checksum}")
        return false
      end
    end

    # open new stream
    def handle_new_stream(file_checksum, file_size)
      Log.debug1("enter handle_new_stream")
      # final destination path
      tmp_path = FileReceiver.destination_filename(
          File.join(Params['backup_destination_folder'][0]['path'], 'tmp'),
          file_checksum)
      path = FileReceiver.destination_filename(Params['backup_destination_folder'][0]['path'],
                                               file_checksum)
      if File.exists?(path)
        Log.warning("File already exists (#{path}) not writing.")
        @file_abort_clb.call(file_checksum) unless @file_abort_clb.nil?
      else
        # The file will be moved from tmp location once the transfer will be done
        # system will use the checksum and some more unique key for tmp file name
        FileUtils.makedirs(File.dirname(tmp_path)) unless File.directory?(File.dirname(tmp_path))
        tmp_file = File.new(tmp_path, 'wb')
        @streams[file_checksum] = Stream.new(file_checksum, tmp_path, tmp_file, file_size)
        $process_vars.set('Streams size', @streams.size)
      end
    end

    # write chunk to temp file
    def handle_new_chunk(file_checksum, offset, content)
      if offset == @streams[file_checksum].file.pos
        FileReceiver.write_string_to_file(content, @streams[file_checksum].file)
        Log.debug1("Written already #{@streams[file_checksum].file.pos} bytes, " \
                 "out of #{@streams[file_checksum].size} " \
                 "(#{100.0*@streams[file_checksum].file.size/@streams[file_checksum].size}%)")
        return true
      else
        # Offset is wrong, send reset/resume copy from correct offset.
        Log.warning("Received chunk with incorrect offset #{offset}, should " \
                      "be #{@streams[file_checksum].file.pos}, file_checksum:#{file_checksum}")
        @reset_copy.call(file_checksum, @streams[file_checksum].file.pos) unless @reset_copy.nil?
        return false
      end
    end

    # copy file to permanent location
    # close stream
    # remove temp file
    # check written file
    def handle_last_chunk(file_checksum)
      # Should always be true, unless file creation failed.
      if @streams.key?(file_checksum)
        # Make the directory if does not exists.
        path = FileReceiver.destination_filename(Params['backup_destination_folder'][0]['path'],
                                                 file_checksum)
        Log.debug1("Moving tmp file #{@streams[file_checksum].path} to #{path}")
        file_dir = File.dirname(path)
        FileUtils.makedirs(file_dir) unless File.directory?(file_dir)
        # Move tmp file to permanent location.
        tmp_file_path = @streams[file_checksum].path
        Stream.close_delete_stream(file_checksum, @streams)  # temp file will be closed here

        local_file_checksum = FileIndexing::IndexAgent.get_checksum(tmp_file_path)
        message = "Local checksum (#{local_file_checksum}) received checksum (#{file_checksum})."
        if local_file_checksum == file_checksum
          Log.debug1(message)
          begin
            File.rename(tmp_file_path, path)
            Log.debug1("End move tmp file to permanent location #{path}.")
            @file_done_clb.call(local_file_checksum, path) unless @file_done_clb.nil?
          rescue Exception => e
            Log.warning("Could not move tmp file to permanent path #{path}." +
                        " Error msg:#{e.message}\nError type:#{e.type}")
          end
        else
          begin
            Log.error(message)
            Log.debug1("Deleting tmp file: #{tmp_file_path}")
            File.delete(tmp_file_path)
          rescue Exception => e
            Log.warning("Could not delete tmp file from tmp path #{tmp_file_path}." +
                            " Error msg:#{e.message}\nError type:#{e.type}")
          end
        end
      else
        Log.error("Handling last chunk and tmp stream does not exists.")
      end
    end

    def self.write_string_to_file(str, file)
      bytes_to_write = str.bytesize
      Log.debug1("writing to file: #{file.to_s}, #{bytes_to_write} bytes.")
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

