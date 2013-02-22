require 'time.rb'
require 'test/unit'

require_relative '../../lib/content_data/content_data.rb'

  class TestContentData < Test::Unit::TestCase
      def test_cloning_db_1
        content_data = ContentData::ContentData.new
        content_data.add_content( "A1", 1242,11111111111)
        content_data.add_instance("A1", 1242, "server_1", "dev_1",
                                  "/home/file_1", 2222222222)

        content_data_cloned = ContentData::ContentData.new(content_data)
        #check that DBs are equal
        assert_equal(content_data, content_data_cloned)

        #change orig DB - size
        content_db = content_data.private_db.values[0]
        content_db[0] = 0
        assert_not_equal(content_data, content_data_cloned)
      end

      def test_cloning_db_2
        content_data = ContentData::ContentData.new
        content_data.add_content( "A1", 1242,11111111111)
        content_data.add_instance("A1", 1242, "server_1", "dev_1",
                                  "/home/file_1", 2222222222)

        content_data_cloned = ContentData::ContentData.new(content_data)
        #check that DBs are equal
        assert_equal(content_data, content_data_cloned)

        #change orig DB - instances
        content_db = content_data.private_db.values[0]
        content_db[1] = {}
        assert_not_equal(content_data, content_data_cloned)
      end

      def test_cloning_db_3
        content_data = ContentData::ContentData.new
        content_data.add_content( "A1", 1242,11111111111)
        content_data.add_instance("A1", 1242, "server_1", "dev_1",
                                  "/home/file_1", 2222222222)

        content_data_cloned = ContentData::ContentData.new(content_data)
        #check that DBs are equal
        assert_equal(content_data, content_data_cloned)

        #change orig DB - instances
        content_data_cloned.private_db['A1'] = 'stam'
        assert_not_equal(content_data, content_data_cloned)
      end

      def test_add_content
        content_data = ContentData::ContentData.new
        content_data.add_content( "A1", 13, 11111111111)
        #Add new content
        content_data.add_content( "B1", 14, 11111111111)
        assert_equal(content_data.to_s, "2\nA1,13,11111111111\nB1,14,11111111111\n0\n")
        #Add existing content. Should not change the data base
        content_data.add_content( "B1", 7, 11111111112)
        assert_equal(content_data.to_s, "2\nA1,13,11111111111\nB1,14,11111111111\n0\n")
      end

      def test_add_instance
        #create first content with instance
        content_data = ContentData::ContentData.new
        content_data.add_content( "A1", 50, 11111111111)
        content_data.add_instance("A1", 50, "server_1", "dev_1",
                                  "/home/file_1", 2222222222)

        #Add new instance - wrong size
        # instance should not be added
        content_data.add_instance("A1", 60, "server_1", "dev_1",
                                  "/home/file_2", 2222222222)
        assert_equal(content_data.to_s, "1\nA1,50,11111111111\n1\nA1,50,server_1,dev_1,/home/file_1,2222222222\n")

        #Add new instance - new content
        #both new content and new instances are created in DB
        content_data.add_instance("A2", 60, "server_1", "dev_1",
                                  "/home/file_2", 2222222222)
        assert_equal(content_data.to_s, "2\nA1,50,11111111111\nA2,60,2222222222\n2\nA1,50,server_1,dev_1,/home/file_1,2222222222\nA2,60,server_1,dev_1,/home/file_2,2222222222\n")

        #Add new instance - same content
        content_data.add_instance("A2", 60, "server_1", "dev_1",
                                  "/home/file_3", 2222222223)
        assert_equal(content_data.to_s, "2\nA1,50,11111111111\nA2,60,2222222222\n3\nA1,50,server_1,dev_1,/home/file_1,2222222222\nA2,60,server_1,dev_1,/home/file_2,2222222222\nA2,60,server_1,dev_1,/home/file_3,2222222223\n")

        #Add same instance - different checksum
        # old instance is deleted.
        content_data.add_instance("E1", 50, "server_1", "dev_1",
                                  "/home/file_1", 2222222222)
        content_data.add_instance("E1", 50, "server_1", "dev_1",
                                  "/home/file_2", 2222222222)
        content_data.add_instance("P1", 50, "server_1", "dev_1",
                                  "/home/file_2", 2222222222)
        assert_equal(content_data.to_s, "4\nA1,50,11111111111\nA2,60,2222222222\nE1,50,2222222222\nP1,50,2222222222\n3\nA2,60,server_1,dev_1,/home/file_3,2222222223\nE1,50,server_1,dev_1,/home/file_1,2222222222\nP1,50,server_1,dev_1,/home/file_2,2222222222\n")
      end

      def test_instance_exists
        content_data = ContentData::ContentData.new
        content_data.add_content( "A1", 50, 11111111111)
        content_data.add_instance("A1", 50, "server_1", "dev_1",
                                  "/home/file_1", 2222222222)
        assert_equal(true, content_data.instance_exists('server_1,dev_1,/home/file_1'))
        assert_equal(false, content_data.instance_exists('server_1,dev_1,/home/file_2'))

      end

      def test_remove_instance
        #remove instance also removes content
        content_data = ContentData::ContentData.new
        content_data.add_content( "A1", 50, 11111111111)
        content_data.add_instance("A1", 50, "server_1", "dev_1",
                                  "/home/file_1", 2222222222)
        assert_equal(true, content_data.content_exists('A1'))
        assert_equal(true, content_data.instance_exists('server_1,dev_1,/home/file_1'))
        content_data.remove_instance('server_1,dev_1,/home/file_1')
        assert_equal(false, content_data.instance_exists('server_1,dev_1,/home/file_1'))
        assert_equal(false, content_data.content_exists('A1'))


        #remove instance does not remove content
        content_data.add_content( "A1", 50, 11111111111)
        content_data.add_instance("A1", 50, "server_1", "dev_1",
                                  "/home/file_1", 2222222222)
        content_data.add_instance("A1", 50, "server_1", "dev_1",
                                  "/home/file_2", 3333333333)
        assert_equal(true, content_data.content_exists('A1'))
        assert_equal(true, content_data.instance_exists('server_1,dev_1,/home/file_1'))
        content_data.remove_instance('server_1,dev_1,/home/file_1')
        assert_equal(false, content_data.instance_exists('server_1,dev_1,/home/file_1'))
        assert_equal(true, content_data.content_exists('A1'))

        #remove also removes content
        content_data.remove_instance('server_1,dev_1,/home/file_2')
        assert_equal(false, content_data.instance_exists('server_1,dev_1,/home/file_2'))
        assert_equal(false, content_data.content_exists('A1'))
      end

      def test_to_a_from_a
        content_data = ContentData::ContentData.new
        content_data.add_content( "A1", 50, 11111111111)
        content_data.add_instance("A1", 50, "server_1", "dev_1",
                                  "/home/file_1", 22222222222)
        content_data.add_content( "B1", 60, 33333333333)
        content_data.add_instance("B1", 60, "server_1", "dev_1",
                                  "/home/file_2", 44444444444)
        content_data.add_instance("B1", 60, "server_1", "dev_1",
                                  "/home/file_3", 55555555555)
        arr = content_data.to_a

        assert_equal(true,arr.instance_of?(Array))
        assert_equal(12,arr.size)
        content_data_2 = ContentData::ContentData.new
        content_data_2.from_a(arr)
        assert_equal(content_data.private_db, content_data_2.private_db)
      end

      def test_to_file_from_file
        content_data = ContentData::ContentData.new
        content_data.add_content( "A1", 50, 11111111111)
        content_data.add_instance("A1", 50, "server_1", "dev_1",
                                  "/home/file_1", 22222222222)
        content_data.add_content( "B1", 60, 33333333333)
        content_data.add_instance("B1", 60, "server_1", "dev_1",
                                  "/home/file_2", 44444444444)
        content_data.add_instance("B1", 60, "server_1", "dev_1",
                                  "/home/file_3", 55555555555)
        file_moc_object = StringIO.new
        file_moc_object.write(content_data.to_s)
        test_file = __FILE__ + 'test'
        content_data.to_file(test_file)
        content_data_2 = ContentData::ContentData.new
        content_data_2.from_file(test_file)
        assert_equal(content_data.private_db, content_data_2.private_db)
      end

      def test_merge
        content_data_a = ContentData::ContentData.new
        content_data_a.add_content( "A1", 50, 11111111111)
        content_data_a.add_instance("A1", 50, "server_1", "dev_1",
                                  "/home/file_1", 22222222222)

        content_data_b = ContentData::ContentData.new
        content_data_b.add_content( "B1", 60, 33333333333)
        content_data_b.add_instance("B1", 60, "server_1", "dev_1",
                                  "/home/file_2", 44444444444)
        content_data_b.add_instance("B1", 60, "server_1", "dev_1",
                                  "/home/file_3", 55555555555)
        content_data_merged = ContentData.merge(content_data_a, content_data_b)
        assert_equal(content_data_merged.to_s, "2\nB1,60,33333333333\nA1,50,11111111111\n3\nB1,60,server_1,dev_1,/home/file_2,44444444444\nB1,60,server_1,dev_1,/home/file_3,55555555555\nA1,50,server_1,dev_1,/home/file_1,22222222222\n")
        content_data_a.remove_instance('server_1,dev_1,/home/file_1')
        assert_equal(content_data_merged.to_s, "2\nB1,60,33333333333\nA1,50,11111111111\n3\nB1,60,server_1,dev_1,/home/file_2,44444444444\nB1,60,server_1,dev_1,/home/file_3,55555555555\nA1,50,server_1,dev_1,/home/file_1,22222222222\n")
        content_data_b.remove_instance('server_1,dev_1,/home/file_2')
        assert_equal(content_data_merged.to_s, "2\nB1,60,33333333333\nA1,50,11111111111\n3\nB1,60,server_1,dev_1,/home/file_2,44444444444\nB1,60,server_1,dev_1,/home/file_3,55555555555\nA1,50,server_1,dev_1,/home/file_1,22222222222\n")

      end

      def test_merge_override_b
        content_data_a = ContentData::ContentData.new
        content_data_a.add_content( "A1", 50, 11111111111)
        content_data_a.add_instance("A1", 50, "server_1", "dev_1",
                                    "/home/file_1", 22222222222)

        content_data_b = ContentData::ContentData.new
        content_data_b.add_content( "A1", 50, 11111111111)
        content_data_b.add_instance("A1", 50, "server_1", "dev_1",
                                    "/home/file_1", 22222222222)
        content_data_b.add_content( "B1", 60, 33333333333)
        content_data_b.add_instance("B1", 60, "server_1", "dev_1",
                                    "/home/file_2", 44444444444)
        content_data_b.add_instance("B1", 60, "server_1", "dev_1",
                                    "/home/file_3", 55555555555)
        content_data_merged = ContentData.merge_override_b(content_data_a, content_data_b)
        assert_equal(content_data_merged.to_s, "2\nA1,50,11111111111\nB1,60,33333333333\n3\nA1,50,server_1,dev_1,/home/file_1,22222222222\nB1,60,server_1,dev_1,/home/file_2,44444444444\nB1,60,server_1,dev_1,/home/file_3,55555555555\n")
        content_data_a.remove_instance('server_1,dev_1,/home/file_1')
        assert_equal(content_data_merged.to_s, "2\nA1,50,11111111111\nB1,60,33333333333\n3\nA1,50,server_1,dev_1,/home/file_1,22222222222\nB1,60,server_1,dev_1,/home/file_2,44444444444\nB1,60,server_1,dev_1,/home/file_3,55555555555\n")
        content_data_b.remove_instance('server_1,dev_1,/home/file_2')
        assert_equal(content_data_b.to_s, "2\nA1,50,11111111111\nB1,60,33333333333\n2\nA1,50,server_1,dev_1,/home/file_1,22222222222\nB1,60,server_1,dev_1,/home/file_3,55555555555\n")
        assert_equal(content_data_merged.private_db, content_data_b.private_db)
      end

      def test_remove
        content_data_a = ContentData::ContentData.new
        content_data_a.add_content( "A1", 50, 11111111111)
        content_data_a.add_instance("A1", 50, "server_1", "dev_1",
                                    "/home/file_1", 22222222222)

        content_data_b = ContentData::ContentData.new
        content_data_b.add_content( "A1", 50, 11111111111)
        content_data_b.add_instance("A1", 50, "server_1", "dev_1",
                                    "/home/file_1", 22222222222)
        content_data_b.add_instance("A1", 50, "server_1", "dev_1",
                                    "extra_inst", 66666666666)
        content_data_b.add_content( "B1", 60, 33333333333)
        content_data_b.add_instance("B1", 60, "server_1", "dev_1",
                                    "/home/file_2", 44444444444)
        content_data_b.add_instance("B1", 60, "server_1", "dev_1",
                                    "/home/file_3", 55555555555)
        content_data_removed = ContentData.remove(content_data_a, content_data_b)
        assert_equal(content_data_removed.to_s, "1\nB1,60,33333333333\n2\nB1,60,server_1,dev_1,/home/file_2,44444444444\nB1,60,server_1,dev_1,/home/file_3,55555555555\n")
        content_data_a.remove_instance('server_1,dev_1,/home/file_1')
        assert_equal(content_data_removed.to_s, "1\nB1,60,33333333333\n2\nB1,60,server_1,dev_1,/home/file_2,44444444444\nB1,60,server_1,dev_1,/home/file_3,55555555555\n")
        content_data_b.remove_instance('server_1,dev_1,/home/file_2')
        assert_equal(content_data_removed.to_s, "1\nB1,60,33333333333\n2\nB1,60,server_1,dev_1,/home/file_2,44444444444\nB1,60,server_1,dev_1,/home/file_3,55555555555\n")

        #check nil
        content_data_removed = ContentData.remove(nil, content_data_b)
        assert_equal(content_data_removed.to_s, content_data_b.to_s)
        content_data_removed = ContentData.remove(content_data_b, nil)
        assert_equal(content_data_removed, nil)
      end

      def test_remove_instances
        content_data_a = ContentData::ContentData.new
        content_data_a.add_content( "A1", 50, 11111111111)
        content_data_a.add_instance("A1", 50, "server_1", "dev_1",
                                    "/home/file_1", 22222222222)


        content_data_b = ContentData::ContentData.new
        content_data_b.add_content( "A1", 50, 11111111111)
        content_data_b.add_instance("A1", 50, "server_1", "dev_1",
                                    "/home/file_1", 22222222222)
        content_data_b.add_instance("A1", 50, "server_1", "dev_1",
                                    "extra_inst", 66666666666)
        content_data_b.add_content( "B1", 60, 33333333333)
        content_data_b.add_instance("B1", 60, "server_1", "dev_1",
                                    "/home/file_2", 44444444444)
        content_data_b.add_instance("B1", 60, "server_1", "dev_1",
                                    "/home/file_3", 55555555555)
        content_data_removed = ContentData.remove_instances(content_data_a, content_data_b)
        assert_equal(content_data_removed.to_s,"2\nA1,50,11111111111\nB1,60,33333333333\n3\nA1,50,server_1,dev_1,extra_inst,66666666666\nB1,60,server_1,dev_1,/home/file_2,44444444444\nB1,60,server_1,dev_1,/home/file_3,55555555555\n")
        content_data_a.remove_instance('server_1,dev_1,/home/file_1')
        assert_equal(content_data_removed.to_s,"2\nA1,50,11111111111\nB1,60,33333333333\n3\nA1,50,server_1,dev_1,extra_inst,66666666666\nB1,60,server_1,dev_1,/home/file_2,44444444444\nB1,60,server_1,dev_1,/home/file_3,55555555555\n")
        content_data_b.remove_instance('server_1,dev_1,/home/file_2')
        assert_equal(content_data_removed.to_s,"2\nA1,50,11111111111\nB1,60,33333333333\n3\nA1,50,server_1,dev_1,extra_inst,66666666666\nB1,60,server_1,dev_1,/home/file_2,44444444444\nB1,60,server_1,dev_1,/home/file_3,55555555555\n")

        #assert_equal(content_data_b, nil)

        #check nil
        content_data_removed = ContentData.remove_instances(nil, content_data_b)
        assert_equal(content_data_removed.to_s, content_data_b.to_s)
        content_data_removed = ContentData.remove_instances(content_data_b, nil)
        assert_equal(content_data_removed, nil)
      end

      def test_remove_directory

        content_data_b = ContentData::ContentData.new
        content_data_b.add_content( "A1", 50, 11111111111)
        content_data_b.add_instance("A1", 50, "server_1", "dev_1",
                                    "/home/file_1", 22222222222)
        content_data_b.add_instance("A1", 50, "server_1", "dev_1",
                                    "extra_inst", 66666666666)
        content_data_b.add_content( "B1", 60, 33333333333)
        content_data_b.add_instance("B1", 60, "server_1", "dev_1",
                                    "/home/file_2", 44444444444)
        content_data_b.add_instance("B1", 60, "server_1", "dev_1",
                                    "/home/file_3", 55555555555)
        content_data_removed = ContentData.remove_directory(content_data_b, 'home')
        assert_equal(content_data_removed.to_s, "1\nA1,50,11111111111\n1\nA1,50,server_1,dev_1,extra_inst,66666666666\n")

        content_data_b.remove_instance('server_1,dev_1,/home/file_2')
        assert_equal(content_data_removed.to_s, "1\nA1,50,11111111111\n1\nA1,50,server_1,dev_1,extra_inst,66666666666\n")

        assert_equal(content_data_b.to_s, "2\nA1,50,11111111111\nB1,60,33333333333\n3\nA1,50,server_1,dev_1,/home/file_1,22222222222\nA1,50,server_1,dev_1,extra_inst,66666666666\nB1,60,server_1,dev_1,/home/file_3,55555555555\n")
        content_data_b = ContentData::ContentData.new
        content_data_removed = ContentData.remove_directory(content_data_b, 'home')
        assert_equal(content_data_removed.private_db, {})
        content_data_removed = ContentData.remove_directory(nil, 'home')
        assert_equal(content_data_removed,nil)
      end

      def test_intersect
        content_data_a = ContentData::ContentData.new
        content_data_a.add_content( "A1", 50, 11111111111)
        content_data_a.add_instance("A1", 50, "server_1", "dev_1",
                                    "/home/file_1", 22222222222)
        content_data_a.add_content( "C1", 70, 66666666666)
        content_data_a.add_instance("C1", 70, "server_1", "dev_1",
                                    "/home/file_4", 77777777777)
        content_data_b = ContentData::ContentData.new
        content_data_b.add_content( "A1", 50, 11111111111)
        content_data_b.add_instance("A1", 50, "server_1", "dev_1",
                                    "/home/file_1", 22222222222)
        content_data_b.add_instance("A1", 50, "server_1", "dev_1",
                                    "/home/file_5", 55555555555)
        content_data_b.add_content( "B1", 60, 33333333333)
        content_data_b.add_instance("B1", 60, "server_1", "dev_1",
                                    "/home/file_2", 44444444444)

        content_data_intersect = ContentData.intersect(content_data_a, content_data_b)
        assert_equal(content_data_intersect.to_s, "1\nA1,50,11111111111\n2\nA1,50,server_1,dev_1,/home/file_1,22222222222\nA1,50,server_1,dev_1,/home/file_5,55555555555\n")
      end

      def test_unify_time
        content_data_a = ContentData::ContentData.new
        content_data_a.add_content( "A1", 50, 11111111111)
        content_data_a.add_instance("A1", 50, "server_1", "dev_1",
                                    "/home/file_1", 22222222222)
        content_data_a.add_content( "C1", 70, 66666666666)
        content_data_a.add_instance("C1", 70, "server_1", "dev_1",
                                    "/home/file_4", 77777777777)
        content_data_a.add_instance("C1", 70, "server_1", "dev_1",
                                    "/home/file_5", 33333333333)
        content_data_unify = ContentData.unify_time(content_data_a)
        assert_equal(content_data_unify.to_s, "2\nA1,50,11111111111\nC1,70,33333333333\n3\nA1,50,server_1,dev_1,/home/file_1,11111111111\nC1,70,server_1,dev_1,/home/file_4,33333333333\nC1,70,server_1,dev_1,/home/file_5,33333333333\n")
        content_data_a.remove_instance('server_1,dev_1,/home/file_4')
        assert_equal(content_data_unify.to_s, "2\nA1,50,11111111111\nC1,70,33333333333\n3\nA1,50,server_1,dev_1,/home/file_1,11111111111\nC1,70,server_1,dev_1,/home/file_4,33333333333\nC1,70,server_1,dev_1,/home/file_5,33333333333\n")
    end
  end


