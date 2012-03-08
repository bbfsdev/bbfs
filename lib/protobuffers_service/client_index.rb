#!/usr/bin/env ruby
require 'protobuf/rpc/client'
require './agent.pb'

class AgentClient

  def self.index (server, patterns, otherDB = nil)
# build request
    request = ::IndexerArgumentsMessage.new
    request.patterns = patterns.serialize
    request.otherDB = otherDB.serialize

# create blank response
    response = ::ContentDataMessage.new

# execute rpc
    Protobuf::Rpc::Client.new(server, 9999).call :index, request, response

# show response
    #puts response
  end

end