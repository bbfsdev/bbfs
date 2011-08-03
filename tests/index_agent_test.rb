#!/usr/bin/ruby

require './index_agent'
require 'test/unit'

class IndexAgentTest < Test::Unit::TestCase


  def test_index
    indexer = IndexAgent.new('large_server_1', 'hd1')
    patterns = Array.new
    patterns.push('hd1:+:.\resources\index_agent_test\**\*')
    patterns.push('hd1:-:.\resources\index_agent_test\**\*.h')

    indexer.index(patterns)
    # ./resources/index_agent_test/lib/libexslt.lib
    puts indexer.db.to_s
    assert(indexer.db.content_exists('c6d9d837659e38d906a4bbdcc6703bc37e9ac7e8'))
    # ./resources/index_agent_test/include/libexslt/exsltexports.h
    assert_equal(false, indexer.db.content_exists('5c87a31b0106b3c4bb1768e43f5b8c41139882c2'))
    # ./resources/index_agent_test/bin/xsltproc.exe
    assert(indexer.db.content_exists('d0d57ff4834a517a52004f59ee5cdb63f2f0427b'))

    patterns.push('hd1:-:./resources/index_agent_test/lib/**/*')
    indexer = IndexAgent.new('large_server_1', 'hd1')
    indexer.index(patterns)
    # ./resources/index_agent_test/lib/libexslt.lib
    assert_equal(false, indexer.db.content_exists('9e409338c0d8e0bbdbf5316cb569a0afcdb321db'))
  end
end
