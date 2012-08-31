require 'log'
require 'rspec'
require 'stringio'

require_relative '../../lib/content_server/file_streamer'

# Uncomment to debug spec.
#BBFS::Params['log_write_to_console'] = true
BBFS::Params['log_write_to_file'] = false
BBFS::Params['log_debug_level'] = 0
BBFS::Params['streaming_chunk_size'] = 5
BBFS::Params.init ARGV
BBFS::Log.init
# Have to be set to test chunking mechanism.

module BBFS
  module ContentServer
    module Spec
      describe 'FileStreamer' do
        it 'should copy one file chunk by chunks and validate content' do
          Log.info('#0 start')
          orig_file = StringIO.new('Some content. Some content. Some content. Some content.')
          Log.info("orig_file #{orig_file.to_s}.")
          dest_file = StringIO.new
          Log.info("dest_file #{dest_file.to_s}.")
          streamer = nil
          done = lambda{ |checksum, filename|
            Log.info('#4 streaming done, check content ok.')
            dest_file.string().should eq(orig_file.string())

            Log.info('#5 exiting streamer thread.')
            streamer.thread.exit
          }
          receiver = BBFS::ContentServer::FileReceiver.new(done)
          send_chunk = lambda { |*args|
            receiver.receive_chunk(*args)
          }
          Log.info('#2 start streaming.')
          # This is for 1) FileStreamer :NEW_STREAM and 2) FileReceiver receive_chunk.
          ::File.stub(:new).and_return(orig_file, dest_file)
          # This is for Index agent 'get_checksum' which opens file, read content and validates
          # checksum.
          ::File.stub(:open).and_return(dest_file)

          streamer = BBFS::ContentServer::FileStreamer.new(send_chunk)
          Log.info('#3 start streaming.')
          streamer.start_streaming('da39a3ee5e6b4b0d3255bfef95601890afd80709', 'dummy')
          streamer.thread.join()
        end
      end
    end
  end
end
