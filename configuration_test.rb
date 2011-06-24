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
    assert_equal("kaka", conf.server_conf_vec[0].servers[0].username)
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

    assert_equal("name:large_server_1\nusername:kuku_crawl\npassword:kaka\ndirectories:\n  hd1:+:/usr/home/bin/*.(mp3|mov)\n  hd1:-:/usr/home/bin/kuku/*\n  hd1:-:/usr/home/bin/*dont_index/*\n  hd2:+:/usr/home/kuku2/file.dot\n  hd2:+:/usr/home/lala/k*\n  hd2:-:/kuku.txt\n  name:small_server_2\n  username:kaka\n  password:\n  directories:\n    tape1:+:/*\n  name:large_server_3\n  username:vasia_crawl_user\n  password:\n  directories:\n    hd1:+:/*\n    hd12:+:/*\n    hd13:+:/*\nname:large_server_4\nusername:vasia_crawl_user\npassword:\ndirectories:\n  hd1:+:/*\nname:large_server_5\nusername:vasia_crawl_user\npassword:\ndirectories:\n  hd1:+:/*\nname:large_server_6\nusername:vasia_crawl_user\npassword:\ndirectories:\n  hd1:+:/*\n", conf.to_s)
  end
  
  def test_bad_conf
    conf = Configuration.new('configuration_test.bad.conf')
    assert_equal(nil, conf.server_conf_vec)    
  end
end