require 'log'
require 'rspec'
require 'stringio'

require_relative '../../lib/content_server/file_streamer'

# Uncomment to debug spec.
BBFS::Params['log_write_to_console'] = true
BBFS::Params['log_debug_level'] = 0
BBFS::Log.init

# Have to be set to test chunking mechanism.
# Params['streaming_chunk_size'] = 5

module BBFS
  module ContentServer
    module Spec
      describe 'FileStreamer' do
        #it 'should copy one file chunk by chunks and validate content' do
        #  orig_file = StringIO.new('Some content. Some content. Some content. Some content.')
        #  dest_file = StringIO.new
        #  streamer = nil
        #  done = lambda{ |checksum, filename|
        #    Log.init('#2 streaming done, check content ok.')
        #    orig_file.string().should eq(dest_file.string())
        #
        #    Log.init('#3 exiting streamer thread.')
        #    streamer.thread.exit
        #  }
        #  receiver = FileReceiver.new(done)
        #  send_chunk = lambda { |file_checksum, content, content_checksum|
        #    receiver.receive_chunk(file_checksum, content, content_checksum)
        #  }
        #  streamer = FileStreamer.new(send_chunk)
        #  Log.init('#1 start streaming.')
        #  streamer.start_streaming_file('checksum', 'dummy')
        #  streamer.thread.join()
        #end
      end
    end
  end
end
