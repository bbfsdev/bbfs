require 'log'
require 'test/unit'

require_relative '../../lib/file_indexing/index_agent'

module BBFS
  module FileIndexing
    module Test
      class IndexAgentTest < ::Test::Unit::TestCase
        def test_index
          indexer = IndexAgent.new
          patterns = IndexerPatterns.new
          patterns.add_pattern File.join(File.dirname(__FILE__), 'index_agent_test\**\*')
          patterns.add_pattern File.join(File.dirname(__FILE__), 'index_agent_test\**\*.h'), false

          indexer.index(patterns)
          # ./index_agent_test/lib/libexslt.lib
          Log.info "Contents: #{indexer.indexed_content.contents}."
          assert(indexer.indexed_content.content_exists('c6d9d837659e38d906a4bbdcc6703bc37e9ac7e8'))
          # .index_agent_test/include/libexslt/exsltexports.h
          assert_equal(false, indexer.indexed_content.content_exists('5c87a31b0106b3c4bb1768e43f5b8c41139882c2'))
          # ./index_agent_test/bin/xsltproc.exe
          assert(indexer.indexed_content.content_exists('d0d57ff4834a517a52004f59ee5cdb63f2f0427b'))

          patterns.add_pattern('./resources/index_agent_test/lib/**/*', false)
          indexer = IndexAgent.new

          indexer.index(patterns)
          # ./index_agent_test/lib/libexslt.lib
          assert_equal(false, indexer.indexed_content.content_exists('9e409338c0d8e0bbdbf5316cb569a0afcdb321db'))

          # checking that existing db as a prameter for indexer is really working
          # i.e. no checksum calculation performs for files that were indexed but weren't changed
          new_indexer = IndexAgent.new
          event_regex = /^(call)/
          id_regex = /get_checksum/
          get_checksum_num = 0
          set_trace_func Proc.new { |event, file, line, id, binding, classname|
            if event =~ event_regex and id.to_s =~ id_regex
              Log.info sprintf "[%8s] %30s %30s (%s:%-2d)\n", event, id, classname, file, line
              get_checksum_num +=1
            end
          }
          new_indexer.index(patterns, indexer.indexed_content)
          set_trace_func nil
          assert_equal(new_indexer.indexed_content, indexer.indexed_content)
          assert_equal(0, get_checksum_num)
        end
      end
    end
  end
end
