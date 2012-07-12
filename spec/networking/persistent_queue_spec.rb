require 'log'
require 'rspec'
require 'socket'
require 'stringio'

require_relative '../../lib/networking/tcp'

# Uncomment to debug spec.
#BBFS::Params.log_write_to_console = 'true'
#BBFS::Params.log_debug_level = 3
#BBFS::Log.init

module BBFS
  module Networking
    module Spec

      describe 'PQueueSender' do
      end

      describe 'PQueueReceiver' do
      end
    end
  end
end
