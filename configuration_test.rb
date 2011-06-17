require 'configuration.rb'
require 'test/unit'

class TestConfiguration < Test::Unit::TestCase
  def test_conf
    conf = Configuration.new('configuration_test.conf')
    assert_equal(4, conf.server_conf_vec.length)
    assert_equal("large_server_1", conf.server_conf_vec[0].name)
    assert_equal("kuku_crawl", conf.server_conf_vec[0].username)
    assert_equal(6, conf.server_conf_vec[0].directories.length)
    assert_equal("hd1:+:/usr/home/bin/*.(mp3|mov)", conf.server_conf_vec[0].directories[0])
    assert_equal("hd1:-:/usr/home/bin/kuku/*", conf.server_conf_vec[0].directories[1])
    assert_equal("hd1:-:/usr/home/bin/*dont_index/*", conf.server_conf_vec[0].directories[2])
    assert_equal("hd2:+:/usr/home/kuku2/file.dot", conf.server_conf_vec[0].directories[3])
    assert_equal("hd2:+:/usr/home/lala/k*", conf.server_conf_vec[0].directories[4])
    assert_equal("hd2:-:/kuku.txt", conf.server_conf_vec[0].directories[5])
    assert_equal(2, conf.server_conf_vec[0].servers.length)
    assert_equal("small_server_2", conf.server_conf_vec[0].servers[0].name)
    assert_equal("", conf.server_conf_vec[0].servers[0].username)
    assert_equal(1, conf.server_conf_vec[0].servers[0].directories.length)
    assert_equal("tape1:+:/*", conf.server_conf_vec[0].servers[0].directories[0])
    assert_equal([], conf.server_conf_vec[0].servers[0].servers)
    assert_equal("large_server_3", conf.server_conf_vec[0].servers[1].name)
    assert_equal("vasia_crawl_user", conf.server_conf_vec[0].servers[1].username)
    assert_equal(3, conf.server_conf_vec[0].servers[1].directories.length)
    assert_equal("hd1:+:/*", conf.server_conf_vec[0].servers[1].directories[0])
    assert_equal("hd12:+:/*", conf.server_conf_vec[0].servers[1].directories[1])
    assert_equal("hd13:+:/*", conf.server_conf_vec[0].servers[1].directories[2])
    assert_equal([], conf.server_conf_vec[0].servers[1].servers)
    assert_equal("large_server_4", conf.server_conf_vec[1].name)
    assert_equal("vasia_crawl_user", conf.server_conf_vec[1].username)
    assert_equal(1, conf.server_conf_vec[1].directories.length)
    assert_equal("hd1:+:/*", conf.server_conf_vec[1].directories[0])
    assert_equal([], conf.server_conf_vec[1].servers)
    assert_equal("large_server_5", conf.server_conf_vec[2].name)
    assert_equal("vasia_crawl_user", conf.server_conf_vec[2].username)
    assert_equal(1, conf.server_conf_vec[2].directories.length)
    assert_equal("hd1:+:/*", conf.server_conf_vec[2].directories[0])
    assert_equal([], conf.server_conf_vec[2].servers)
  end
  
  def test_bad_conf
    conf = Configuration.new('configuration_test.bad.conf')
    assert_equal(nil, conf.server_conf_vec)    
  end
end