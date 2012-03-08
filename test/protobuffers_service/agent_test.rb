require './index_agent'
require "./client_index"
require 'test/unit'

if (RUBY_PLATFORM =~ /mingw/ or RUBY_PLATFORM =~ /ms/ or RUBY_PLATFORM =~ /win/)
  require  'win32/process'
end

require 'sys/proctable'
include Sys

class AgentTest < Test::Unit::TestCase
  INPUT_DIR = File.expand_path(File.dirname(__FILE__) + "/../resources/index_agent_test")
  START_SERVICE = "start_agent_service"

  def test_index
    # make index locally that will be used later for comparison
    indexer = IndexAgent.new(`hostname`.chomp, "dev")
    patterns = IndexerPatterns.new
    patterns.add_pattern(INPUT_DIR + '/**/*')     # this pattern index all files
    indexer.index(patterns)

    # start service as an independent process
    service_pid = spawn("ruby #{START_SERVICE}")
    Process.detach(service_pid)
    sleep 5  # give a time for service to rise

    # use the service for index
    response = AgentClient.index('localhost', patterns, indexer.db)

    assert_equal(indexer.db, ContentData.new(response))

    # checking whether new service was created or we used an existing one
    new_process_started = false
    ProcTable.ps do |p|
      if (p.pid == service_pid)
        new_process_started = true
        break
      end
    end

    # if new service was created than we need to kill it
    # and perform a check that it was actually killed
    if (new_process_started)
      Process.kill(9, service_pid)
      ProcTable.ps do |p|
        if (p.pid == service_pid)
          raise "Service process wasn't killed'"
        end
      end
    end
  end
end