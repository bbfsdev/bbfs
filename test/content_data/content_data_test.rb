require 'time.rb'
require 'test/unit'
require 'content_server/server'
require_relative '../../lib/content_data/content_data.rb'

class TestContentData < Test::Unit::TestCase

  def setup
        Params.init Array.new
        # must preced Log.init, otherwise log containing default values will be created
        Params['log_write_to_file'] = false
        Log.init
  end

  def test_cloning_db_1
    content_data = ContentData::ContentData.new
    content_data.add_instance("A1", 1242, "server_1",
                              "/home/file_1", 2222222222)

    content_data_cloned = ContentData::ContentData.new(content_data)
    #check that DBs are equal
    assert_equal(content_data, content_data_cloned)

    content_data_cloned.add_instance("A1", 1242, "server_1",
                                     "/home/file_2", 3333333333)
    #change orig DB - size
    assert_not_equal(content_data, content_data_cloned)
  end

  def test_cloning_db_2
    content_data = ContentData::ContentData.new
    content_data.add_instance("A1", 1242, "server_1",
                              "/home/file_1", 2222222222)

    content_data_cloned = ContentData::ContentData.new(content_data)
    #check that DBs are equal
    assert_equal(content_data, content_data_cloned)

    content_data_cloned.add_instance("A2", 1243, "server_1",
                                     "/home/file_2", 3333333333)
    #change orig DB - size
    assert_not_equal(content_data, content_data_cloned)
  end


  def test_add_instance
    #create first content with instance
    content_data = ContentData::ContentData.new
    content_data.add_instance("A1", 50, "server_1",
                              "/home/file_1", 2222222222)

    #Add new instance - different size
    # size would be overriden should not be added
    content_data.add_instance("A1", 60, "server_1",
                              "/home/file_2", 2222222222)
    assert_equal("1\nA1,60,2222222222\n2\nA1,60,server_1,/home/file_1,2222222222\nA1,60,server_1,/home/file_2,2222222222\n", content_data.to_s)

    #Add new instance - new content
    #both new content and new instances are created in DB
    content_data.add_instance("A2", 60, "server_1",
                              "/home/file_2", 3333333333)
    assert_equal("2\nA1,60,2222222222\nA2,60,3333333333\n2\n" +
                     "A1,60,server_1,/home/file_1,2222222222\n" +
                     "A2,60,server_1,/home/file_2,3333333333\n", content_data.to_s)

        #Add new instance - same content
    content_data.add_instance("A2", 60, "server_1",
                              "/home/file_3", 4444444444)
    assert_equal("2\nA1,60,2222222222\nA2,60,3333333333\n3\n" +
        "A1,60,server_1,/home/file_1,2222222222\n" +
        "A2,60,server_1,/home/file_2,3333333333\n" +
        "A2,60,server_1,/home/file_3,4444444444\n", content_data.to_s)
        end

  def test_instance_exists
    content_data = ContentData::ContentData.new
    content_data.add_instance("A129", 50, "server_1",
                              "/home/file_1", 2222222222)
    assert_equal(true, content_data.instance_exists('/home/file_1', 'server_1'))
    assert_equal(false, content_data.instance_exists('/home/file_1', 'stum'))
  end

  def test_remove_instance
    #remove instance also removes content
    content_data = ContentData::ContentData.new
    content_data.add_instance("A1", 50, "server_1",
                              "/home/file_1", 2222222222)
    assert_equal(true, content_data.content_exists('A1'))
    assert_equal(true, content_data.instance_exists('/home/file_1', 'server_1'))
    content_data.remove_instance('server_1', '/home/file_1')
    assert_equal(false, content_data.instance_exists('/home/file_1', 'server_1'))
    assert_equal(false, content_data.content_exists('A1'))

    #remove instance does not remove content
    content_data.add_instance("A1", 50, "server_1",
                              "/home/file_1", 2222222222)
    content_data.add_instance("A1", 50, "server_1",
                              "/home/file_2", 3333333333)
    assert_equal(true, content_data.content_exists('A1'))
    assert_equal(true, content_data.instance_exists('/home/file_1', 'server_1'))
    content_data.remove_instance('server_1', '/home/file_1')
    assert_equal(false, content_data.instance_exists('/home/file_1', 'server_1'))
    assert_equal(true, content_data.content_exists('A1'))

    #remove also removes content
    content_data.remove_instance('server_1', '/home/file_2')
    assert_equal(false, content_data.instance_exists('/home/file_1', 'server_1'))
    assert_equal(false, content_data.content_exists('A1'))
  end

  def test_to_file_from_file
    content_data = ContentData::ContentData.new
    content_data.add_instance("A1", 50, "server_1",
                              "/home/file_1", 22222222222)
    content_data.add_instance("B1", 60, "server_1",
                              "/home/file_2", 44444444444)
    content_data.add_instance("B1", 60, "server_1",
                              "/home/file_3", 55555555555)
    file_moc_object = StringIO.new
    file_moc_object.write(content_data.to_s)
    test_file = __FILE__ + 'test'
    content_data.to_file(test_file)
    content_data_2 = ContentData::ContentData.new
    content_data_2.from_file(test_file)
    assert_equal(true, content_data == content_data_2)
  end

  def test_merge
    content_data_a = ContentData::ContentData.new
    content_data_a.add_instance("A1", 50, "server_1",
                                "/home/file_1", 22222222222)

    content_data_b = ContentData::ContentData.new
    content_data_b.add_instance("B1", 60, "server_1",
                                "/home/file_2", 44444444444)
    content_data_b.add_instance("B1", 60, "server_1",
                                "/home/file_3", 55555555555)
    content_data_merged = ContentData.merge(content_data_a, content_data_b)
    assert_equal(content_data_merged.to_s, "2\nB1,60,44444444444\nA1,50,22222222222\n3\nB1,60,server_1,/home/file_2,44444444444\nB1,60,server_1,/home/file_3,55555555555\nA1,50,server_1,/home/file_1,22222222222\n")
    content_data_a.remove_instance('server_1', '/home/file_1')
    assert_equal(content_data_merged.to_s, "2\nB1,60,44444444444\nA1,50,22222222222\n3\nB1,60,server_1,/home/file_2,44444444444\nB1,60,server_1,/home/file_3,55555555555\nA1,50,server_1,/home/file_1,22222222222\n")
    content_data_b.remove_instance('server_1', '/home/file_2')
    assert_equal(content_data_merged.to_s, "2\nB1,60,44444444444\nA1,50,22222222222\n3\nB1,60,server_1,/home/file_2,44444444444\nB1,60,server_1,/home/file_3,55555555555\nA1,50,server_1,/home/file_1,22222222222\n")

  end

  def test_merge_override_b
    content_data_a = ContentData::ContentData.new
    content_data_a.add_instance("A1", 50, "server_1",
                                "/home/file_1", 22222222222)

    content_data_b = ContentData::ContentData.new
    content_data_b.add_instance("A1", 50, "server_1",
                                "/home/file_1", 22222222222)
    content_data_b.add_instance("B1", 60, "server_1",
                                "/home/file_2", 44444444444)
    content_data_b.add_instance("B1", 60, "server_1",
                                "/home/file_3", 55555555555)
    content_data_merged = ContentData.merge_override_b(content_data_a, content_data_b)
    assert_equal("2\nA1,50,22222222222\nB1,60,44444444444\n3\nA1,50,server_1,/home/file_1,22222222222\nB1,60,server_1,/home/file_2,44444444444\nB1,60,server_1,/home/file_3,55555555555\n",
                 content_data_merged.to_s)

    content_data_a.remove_instance('server_1', '/home/file_1')
    assert_equal("2\nA1,50,22222222222\nB1,60,44444444444\n3\nA1,50,server_1,/home/file_1,22222222222\nB1,60,server_1,/home/file_2,44444444444\nB1,60,server_1,/home/file_3,55555555555\n",
                 content_data_merged.to_s)
    content_data_b.remove_instance('server_1', '/home/file_2')
    assert_equal("2\nA1,50,22222222222\nB1,60,44444444444\n2\nA1,50,server_1,/home/file_1,22222222222\nB1,60,server_1,/home/file_3,55555555555\n",
                 content_data_b.to_s)

    assert_equal(true, content_data_merged == content_data_b)
  end

  def test_remove
    content_data_a = ContentData::ContentData.new
    content_data_a.add_instance("A1", 50, "server_1",
                                "/home/file_1", 22222222222)

    content_data_b = ContentData::ContentData.new
    content_data_b.add_instance("A1", 50, "server_1",
                                "/home/file_1", 22222222222)
    content_data_b.add_instance("A1", 50, "server_1",
                                "extra_inst", 66666666666)
    content_data_b.add_instance("B1", 60, "server_1",
                                "/home/file_2", 44444444444)
    content_data_b.add_instance("B1", 60, "server_1",
                                "/home/file_3", 55555555555)
    content_data_removed = ContentData.remove(content_data_a, content_data_b)
    assert_equal(content_data_removed.to_s, "1\nB1,60,44444444444\n2\nB1,60,server_1,/home/file_2,44444444444\nB1,60,server_1,/home/file_3,55555555555\n")
    content_data_a.remove_instance('server_1', '/home/file_1')
    assert_equal(content_data_removed.to_s, "1\nB1,60,44444444444\n2\nB1,60,server_1,/home/file_2,44444444444\nB1,60,server_1,/home/file_3,55555555555\n")
    content_data_b.remove_instance('server_1', '/home/file_2')
    assert_equal(content_data_removed.to_s, "1\nB1,60,44444444444\n2\nB1,60,server_1,/home/file_2,44444444444\nB1,60,server_1,/home/file_3,55555555555\n")

    #check nil
    content_data_removed = ContentData.remove(nil, content_data_b)
    assert_equal(content_data_removed.to_s, content_data_b.to_s)
    content_data_removed = ContentData.remove(content_data_b, nil)
    assert_equal(content_data_removed, nil)
  end

  def test_remove_instances
    content_data_a = ContentData::ContentData.new
    content_data_a.add_instance("A1", 50, "server_1",
                                "/home/file_1", 22222222222)

    content_data_b = ContentData::ContentData.new
    content_data_b.add_instance("A1", 50, "server_1",
                                "/home/file_1", 22222222222)
    content_data_b.add_instance("A1", 50, "server_1",
                                "extra_inst", 66666666666)
    content_data_b.add_instance("B1", 60, "server_1",
                                "/home/file_2", 44444444444)
    content_data_b.add_instance("B1", 60, "server_1",
                                "/home/file_3", 55555555555)
    content_data_removed = ContentData.remove_instances(content_data_a, content_data_b)
    assert_equal(content_data_removed.to_s,"2\nA1,50,22222222222\nB1,60,44444444444\n3\nA1,50,server_1,extra_inst,66666666666\nB1,60,server_1,/home/file_2,44444444444\nB1,60,server_1,/home/file_3,55555555555\n")
    content_data_a.remove_instance('server_1', '/home/file_1')
    assert_equal(content_data_removed.to_s,"2\nA1,50,22222222222\nB1,60,44444444444\n3\nA1,50,server_1,extra_inst,66666666666\nB1,60,server_1,/home/file_2,44444444444\nB1,60,server_1,/home/file_3,55555555555\n")
    content_data_b.remove_instance('server_1', '/home/file_2')
    assert_equal(content_data_removed.to_s,"2\nA1,50,22222222222\nB1,60,44444444444\n3\nA1,50,server_1,extra_inst,66666666666\nB1,60,server_1,/home/file_2,44444444444\nB1,60,server_1,/home/file_3,55555555555\n")

    #assert_equal(content_data_b, nil)

    #check nil
    content_data_removed = ContentData.remove_instances(nil, content_data_b)
    assert_equal(content_data_removed.to_s, content_data_b.to_s)
    content_data_removed = ContentData.remove_instances(content_data_b, nil)
    assert_equal(content_data_removed, nil)
  end

  def test_remove_directory

    content_data_b = ContentData::ContentData.new
    content_data_b.add_instance("A1", 50, "server_1",
                                "/home/file_1", 22222222222)
    content_data_b.add_instance("A1", 50, "server_1",
                                "extra_inst", 66666666666)
    content_data_b.add_instance("B1", 60, "server_1",
                                "/home/file_2", 44444444444)
    content_data_b.add_instance("B1", 60, "server_1",
                                "/home/file_3", 55555555555)
    content_data_removed = ContentData.remove_directory(content_data_b, 'home', "server_1")
    assert_equal("1\nA1,50,22222222222\n1\nA1,50,server_1,extra_inst,66666666666\n",
                 content_data_removed.to_s)

    content_data_b.remove_instance('server_1', '/home/file_2')
    assert_equal("1\nA1,50,22222222222\n1\nA1,50,server_1,extra_inst,66666666666\n",
                 content_data_removed.to_s)

    assert_equal("2\nA1,50,22222222222\nB1,60,44444444444\n3\nA1,50,server_1,/home/file_1,22222222222\nA1,50,server_1,extra_inst,66666666666\nB1,60,server_1,/home/file_3,55555555555\n",
                 content_data_b.to_s)

    content_data_b = ContentData::ContentData.new
    content_data_removed = ContentData.remove_directory(content_data_b, 'home', "server_1")
    assert_equal(0, content_data_removed.contents_size)
    content_data_removed = ContentData.remove_directory(nil, 'home', "server_1")
    assert_equal(content_data_removed, nil)
  end

  def test_intersect
    content_data_a = ContentData::ContentData.new
    content_data_a.add_instance("A1", 50, "server_1",
                                "/home/file_1", 22222222222)
    content_data_a.add_instance("C1", 70, "server_1",
                                "/home/file_4", 77777777777)
    content_data_b = ContentData::ContentData.new
    content_data_b.add_instance("A1", 50, "server_1",
                                "/home/file_1", 22222222222)
    content_data_b.add_instance("A1", 50, "server_1",
                                "/home/file_5", 55555555555)
    content_data_b.add_instance("B1", 60, "server_1",
                                "/home/file_2", 44444444444)

    content_data_intersect = ContentData.intersect(content_data_a, content_data_b)
    assert_equal(content_data_intersect.to_s, "1\nA1,50,22222222222\n2\nA1,50,server_1,/home/file_1,22222222222\nA1,50,server_1,/home/file_5,55555555555\n")
  end

  def test_unify_time
    content_data_a = ContentData::ContentData.new
    content_data_a.add_instance("A1", 50, "server_1",
                                "/home/file_1", 22222222222)
    content_data_a.add_instance("C1", 70, "server_1",
                                "/home/file_4", 77777777777)
    content_data_a.add_instance("C1", 70, "server_1",
                                "/home/file_5", 33333333333)
    content_data_a.unify_time
    assert_equal(content_data_a.to_s, "2\nA1,50,22222222222\nC1,70,33333333333\n3\nA1,50,server_1,/home/file_1,22222222222\nC1,70,server_1,/home/file_4,33333333333\nC1,70,server_1,/home/file_5,33333333333\n")
  end
end


