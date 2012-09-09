require 'log'
require 'rspec'
require 'stringio'

require_relative '../../lib/content_server/file_streamer'

# Uncomment to debug spec.
BBFS::Params['log_write_to_console'] = false
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

          # should simulate Tempfile object, thus need to add to this object Tempfile methsods
          # that are absent in StringIO, but used in tested ruby code
          dest_file = StringIO.new
          def dest_file.path
            '/tmp/path/tmp_basename'
          end
          def dest_file.unlink
            true
          end
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
          # This is for FileStreamer :NEW_STREAM
          ::File.stub(:new).and_return(orig_file)
          # This is for FileReceiver :receive_chunk
          ::Tempfile.stub(:new).and_return(dest_file)
          ::FileUtils.stub(:makedirs).and_return(true)
          ::FileUtils.stub(:copy_file).and_return(true)
          # This is for Index agent 'get_checksum' which opens file, read content and validates
          # checksum.
          ::File.stub(:open).and_return(dest_file)

          streamer = BBFS::ContentServer::FileStreamer.new(send_chunk)
          Log.info('#3 start streaming.')
          streamer.start_streaming('da39a3ee5e6b4b0d3255bfef95601890afd80709', 'dummy')
          streamer.thread.join()
          sleep Params['log_param_max_elapsed_time_in_seconds_from_last_flush'] + 1
        end
      end
    end
  end
end
