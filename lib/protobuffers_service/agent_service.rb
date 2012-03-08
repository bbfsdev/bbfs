require 'protobuf/rpc/server'
require 'protobuf/rpc/handler'
require './agent.pb'
require './index_agent'
require './agent.pb'

class ::IndexHandler < Protobuf::Rpc::Handler
  request ::IndexerArgumentsMessage
  response ::ContentDataMessage

  # @param request [IndexerArgumentsMessage]
  # @param response [ContentDataMessage]
  def self.process_request(request, response)
    # TODO add a tests including empty objects
    patterns = IndexerPatterns.new(request.patterns)
    otherDB = ContentData.new(request.otherDB)

    indexer = IndexAgent.new(`hostname`.chomp, "dev")
    indexer.index(patterns, otherDB)
    indexer.db.serialize(response)
    response
  end
end

class ::AgentService < Protobuf::Rpc::Server
  def setup_handlers
    @handlers = {
        :index => ::IndexHandler,
    }
  end
end

