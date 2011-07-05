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
    assert(indexer.db.content_exists('9e409338c0d8e0bbdbf5316cb569a0afcdb321db'))
    # ./resources/index_agent_test/include/libexslt/exsltexports.h
    assert_equal(false, indexer.db.content_exists('5c87a31b0106b3c4bb1768e43f5b8c41139882c2'))
    # ./resources/index_agent_test/bin/xsltproc.exe
    assert(indexer.db.content_exists('56002e32e1a3e890be2dab91fb37eff6f1a72b0c'))
    
    patterns.push('hd1:-:./resources/index_agent_test/lib/**/*')
    indexer = IndexAgent.new('large_server_1', 'hd1')
    indexer.index(patterns)
    # ./resources/index_agent_test/lib/libexslt.lib
    assert_equal(false, indexer.db.content_exists('9e409338c0d8e0bbdbf5316cb569a0afcdb321db'))
  end  
end
