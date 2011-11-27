#!/usr/bin/ruby

require './index_agent'
require 'test/unit'

class IndexAgentTest < Test::Unit::TestCase


  def test_index
    indexer = IndexAgent.new('large_server_1', 'hd1')
    patterns = IndexerPatterns.new
    patterns.add_pattern('.\resources\index_agent_test\**\*')
    patterns.add_pattern('.\resources\index_agent_test\**\*.h', false)

    indexer.index(patterns)
    # ./resources/index_agent_test/lib/libexslt.lib
    assert(indexer.db.content_exists('c6d9d837659e38d906a4bbdcc6703bc37e9ac7e8'))
    # ./resources/index_agent_test/include/libexslt/exsltexports.h
    assert_equal(false, indexer.db.content_exists('5c87a31b0106b3c4bb1768e43f5b8c41139882c2'))
    # ./resources/index_agent_test/bin/xsltproc.exe
    assert(indexer.db.content_exists('d0d57ff4834a517a52004f59ee5cdb63f2f0427b'))

    patterns.add_pattern('./resources/index_agent_test/lib/**/*', false)
    indexer = IndexAgent.new('large_server_1', 'hd1')
    
    indexer.index(patterns)
    # ./resources/index_agent_test/lib/libexslt.lib
    assert_equal(false, indexer.db.content_exists('9e409338c0d8e0bbdbf5316cb569a0afcdb321db'))
    
    new_indexer = IndexAgent.new('large_server_1', 'hd1')
    event_regex = /^(call)/
    id_regex = /get_checksum/
    get_checksum_num = 0
    set_trace_func Proc.new { |event, file, line, id, binding, classname|
      if event =~ event_regex and id.to_s =~ id_regex 
        printf "[%8s] %30s %30s (%s:%-2d)\n", event, id, classname, file, line
        get_checksum_num +=1
      end
    }    
    new_indexer.index(patterns, indexer.db)
    set_trace_func nil
    assert_equal(new_indexer.db, indexer.db)
    assert_equal(0, get_checksum_num)
    
  end
end
