require_relative '../../lib/parameters/parameters'
require 'test/unit'

module BBFS
  module Parameters

    class TestClassName < Test::Unit::TestCase
      def test_conf_1()
        # create tested object
        ap = Parameters.new

        assert_equal(true,ap.add_flag("copy", "src" ,"String", nil, "Path to source file or directory"))
        assert_equal(true,ap.add_flag("copy","dst", "String", nil, "Path to source file or directory"))
        assert_equal(true,ap.add_flag("move", "src","String", nil, "Path to source file or directory"))
        assert_equal(true,ap.add_flag("move","dst", "String", nil, "Path to source file or directory"))
        assert_equal(true,ap.add_flag("archive", "src", "String", nil, "Path to source file or directory"))

        assert_equal(nil,ap.get_flag_value("move", "src"))   # will pass
        assert_equal(nil,ap.get_flag_value("archive", "dst"))   # will fail

        # command line parsing
        # assert_equal(false, ap.parse("move  src=55  dst=c:/temp/kuku.txt")) # command line
        #assert_equal(true, ap.parse("copy src=c:/temp/kuku.txt"))    #default value  exist should   pass
        # value extraction
        # assert_equal("c:/tmp", ap.get_flag_value("src"))   # will fail
        #assert_equal("c:/temp/kuku.txt", ap.get_flag_value("src"))   # will pass

        # assert_equal(true, ap.parse("copy src=c:/temp/kuku.txt dst=d:/temp/kukuriku.txt"))


        # assert_equal("d:/temp", ap.get_flag_value("dst"))   # will fail
        # assert_equal("d:/temp/kukuriku.txt", ap.get_flag_value("dst"))   # will pass

      end
    end
  end
end