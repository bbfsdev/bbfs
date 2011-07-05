require 'configuration.rb'
require 'test/unit'

class TestConfiguration < Test::Unit::TestCase
  def test_conf_1
    conf = Configuration.new('configuration_test.1.conf')
    assert_equal(1, conf.server_conf_vec.length)
  end

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

    assert_equal("server\n  name:large_server_1\n  username:kuku_crawl\n  password:kaka\n  port:2222\n  directories:\n    hd1:+:/usr/home/bin/*.(mp3|mov)\n    hd1:-:/usr/home/bin/kuku/*\n    hd1:-:/usr/home/bin/*dont_index/*\n    hd2:+:/usr/home/kuku2/file.dot\n    hd2:+:/usr/home/lala/k*\n    hd2:-:/kuku.txt\n  server\n    name:small_server_2\n    username:kaka\n    password:\n    port:\n    directories:\n      tape1:+:/*\n  server\n    name:large_server_3\n    username:vasia_crawl_user\n    password:\n    port:\n    directories:\n      hd1:+:/*\n      hd12:+:/*\n      hd13:+:/*\nserver\n  name:large_server_4\n  username:vasia_crawl_user\n  password:\n  port:\n  directories:\n    hd1:+:/*\nserver\n  name:large_server_5\n  username:vasia_crawl_user\n  password:\n  port:\n  directories:\n    hd1:+:/*\nserver\n  name:large_server_6\n  username:vasia_crawl_user\n  password:\n  port:\n  directories:\n    hd1:+:/*\n", conf.to_s)
  end
  
  def test_bad_conf
    conf = Configuration.new('configuration_test.bad.conf')
    assert_equal(nil, conf.server_conf_vec)    
  end
end