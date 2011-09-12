require './content_data.rb'
require 'time.rb'
require 'test/unit'

class TestContentData < Test::Unit::TestCase
  def test_content
    content_data = ContentData.new
    content_data.add_content(Content.new("D12A1C98A3", 765, ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data.add_content(Content.new("B12A1C98A3", 123123, ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data.add_content(Content.new("D1234C98A3", 12444, ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data.add_content(Content.new("DB12A1C233", 2, ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data.add_content(Content.new("DB12A4338A", 12412, ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data.add_content(Content.new("232A1C98A3", 124424, ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data.add_content(Content.new("AC12A1C983", 1242, ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data.add_content(Content.new("AAC12A1C983", 1242,ContentData.parse_time("2011/02/01 02:23:59.000")))

    content_data.add_instance(ContentInstance.new("DB12A1C233", 765, "large_server_1", "dev1",
      "/home/kuku/dev/lala/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data.add_instance(ContentInstance.new("DB12A4338A", 765, "large_server_1", "dev2",
      "/home/kuku/dev/lala/k1.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data.add_instance(ContentInstance.new("232A1C98A3", 765, "large_server_1", "dev3",
      "/home/kuku/dev/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data.add_instance(ContentInstance.new("DB12A4338A", 765, "large_server_2", "dev2",
      "/home/lala/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data.add_instance(ContentInstance.new("D1234C98A3", 765, "large_server_2", "dev1",
      "/home/kuku/lala/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data.add_instance(ContentInstance.new("D12A1C98A3", 765, "large_server_2", "dev1",
      "/home/kuku/dev/lala/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data.add_instance(ContentInstance.new("AC12A1C983", 765, "large_server_2", "dev2",
      "/home/kuku/dev/lala/k1.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data.add_instance(ContentInstance.new("232A1C98A3", 765, "large_server_2", "dev3",
      "/home/kuku/dev/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data.add_instance(ContentInstance.new("D12A1C98A3", 765, "large_server_2", "dev2",
      "/home/lala/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data.add_instance(ContentInstance.new("D1234C98A3", 12412, "large_server_2", "dev1",
      "/home/kuku/lala/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data.add_instance(ContentInstance.new("DB12A4338A", 12412, "large_server_2", "dev1",
      "/home/kuku/dev/lala/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data.add_instance(ContentInstance.new("AC12A1C983", 12412, "large_server_2", "dev2",
      "/home/kuku/kuku/dev/lala/k1.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data.add_instance(ContentInstance.new("232A1C98A3", 12412, "large_server_2", "dev3",
      "/home/kuku/kuku/dev/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data.add_instance(ContentInstance.new("DB12A4338A", 12412, "large_server_1", "dev2",
      "/home/kuku/lala/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data.add_instance(ContentInstance.new("D1234C98A3", 12412, "large_server_1", "dev1",
      "/home/kuku/kuku/lala/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))

    #print content_data.to_s

    assert_equal("8\nD12A1C98A3,765,2011/02/01 02:23:59.000\nB12A1C98A3,123123,2011/02/01 02:23:59.000\nD1234C98A3,12444,2011/02/01 02:23:59.000\nDB12A1C233,2,2011/02/01 02:23:59.000\nDB12A4338A,12412,2011/02/01 02:23:59.000\n232A1C98A3,124424,2011/02/01 02:23:59.000\nAC12A1C983,1242,2011/02/01 02:23:59.000\nAAC12A1C983,1242,2011/02/01 02:23:59.000\n3\nDB12A4338A,12412,large_server_2,dev1,/home/kuku/dev/lala/k.txt,2011/02/01 02:23:59.000\nD12A1C98A3,765,large_server_2,dev2,/home/lala/k.txt,2011/02/01 02:23:59.000\nDB12A4338A,12412,large_server_1,dev2,/home/kuku/lala/k.txt,2011/02/01 02:23:59.000\n",
      content_data.to_s)
    content_data.to_file("resources/content_data_test.data")
    new_content_data = ContentData.new()
    new_content_data.from_file("resources/content_data_test.data")
    assert_equal(new_content_data, content_data)

    content_data2 = ContentData.new
    content_data2.add_content(Content.new("AD12A1C98A3", 765, ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data2.add_content(Content.new("AB12A1C98A3", 123123, ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data2.add_content(Content.new("AD1234C98A3", 12444, ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data2.add_content(Content.new("ADB12A1C233", 2, ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data2.add_content(Content.new("ADB12A4338A", 12412, ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data2.add_content(Content.new("A232A1C98A3", 124424, ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data2.add_content(Content.new("AAC12A1C983", 1242, ContentData.parse_time("2011/02/01 02:23:59.000")))

    content_data2.add_instance(ContentInstance.new("ADB12A1C233", 765, "large_server_11", "dev1",
      "/home/kuku/dev/lala/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data2.add_instance(ContentInstance.new("ADB12A4338A", 765, "large_server_11", "dev2",
      "/home/kuku/dev/lala/k1.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data2.add_instance(ContentInstance.new("A232A1C98A3", 765, "large_server_11", "dev3",
      "/home/kuku/dev/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data2.add_instance(ContentInstance.new("ADB12A4338A", 765, "large_server_12", "dev2",
      "/home/lala/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data2.add_instance(ContentInstance.new("AD1234C98A3", 765, "large_server_12", "dev1",
      "/home/kuku/lala/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data2.add_instance(ContentInstance.new("AD12A1C98A3", 765, "large_server_12", "dev1",
      "/home/kuku/dev/lala/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data2.add_instance(ContentInstance.new("AAC12A1C983", 765, "large_server_12", "dev2",
      "/home/kuku/dev/lala/k1.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data2.add_instance(ContentInstance.new("A232A1C98A3", 765, "large_server_12", "dev3",
      "/home/kuku/dev/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data2.add_instance(ContentInstance.new("AD12A1C98A3", 765, "large_server_12", "dev2",
      "/home/lala/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data2.add_instance(ContentInstance.new("AD1234C98A3", 12412, "large_server_12", "dev1",
      "/home/kuku/lala/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data2.add_instance(ContentInstance.new("ADB12A4338A", 12412, "large_server_12", "dev1",
      "/home/kuku/dev/lala/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data2.add_instance(ContentInstance.new("AAC12A1C983", 12412, "large_server_12", "dev2",
      "/home/kuku/kuku/dev/lala/k1.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data2.add_instance(ContentInstance.new("A232A1C98A3", 12412, "large_server_12", "dev3",
      "/home/kuku/kuku/dev/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data2.add_instance(ContentInstance.new("ADB12A4338A", 12412, "large_server_11", "dev2",
      "/home/kuku/lala/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))
    content_data2.add_instance(ContentInstance.new("AD1234C98A3", 12412, "large_server_11", "dev1",
      "/home/kuku/kuku/lala/k.txt", ContentData.parse_time("2011/02/01 02:23:59.000")))

    old_content_data = ContentData.new
    old_content_data.merge(content_data)
    assert_equal(true, old_content_data == content_data)
    content_data.merge(content_data2)
    content_data.to_file("resources/content_data_test2.data")
    new_content_data2 = ContentData.new()
    new_content_data2.from_file("resources/content_data_test2.data")
    assert_equal(true, new_content_data2 == content_data)
    assert_equal(false, new_content_data2 == old_content_data)

    cd3 = ContentData.remove(content_data2, content_data)
    assert_equal(false, old_content_data == cd3)
    cd4 = ContentData.remove(cd3, content_data)
    #assert_equal(content_data.to_s, "")
    assert_equal(cd3.to_s, "7\nD12A1C98A3,765,2011/02/01 02:23:59.000\nB12A1C98A3,123123,2011/02/01 02:23:59.000\nD1234C98A3,12444,2011/02/01 02:23:59.000\nDB12A1C233,2,2011/02/01 02:23:59.000\nDB12A4338A,12412,2011/02/01 02:23:59.000\n232A1C98A3,124424,2011/02/01 02:23:59.000\nAC12A1C983,1242,2011/02/01 02:23:59.000\n3\nDB12A4338A,12412,large_server_2,dev1,/home/kuku/dev/lala/k.txt,2011/02/01 02:23:59.000\nD12A1C98A3,765,large_server_2,dev2,/home/lala/k.txt,2011/02/01 02:23:59.000\nDB12A4338A,12412,large_server_1,dev2,/home/kuku/lala/k.txt,2011/02/01 02:23:59.000\n")
    assert_equal(cd4.to_s, "7\nAAC12A1C983,1242,2011/02/01 02:23:59.000\nAD12A1C98A3,765,2011/02/01 02:23:59.000\nAB12A1C98A3,123123,2011/02/01 02:23:59.000\nAD1234C98A3,12444,2011/02/01 02:23:59.000\nADB12A1C233,2,2011/02/01 02:23:59.000\nADB12A4338A,12412,2011/02/01 02:23:59.000\nA232A1C98A3,124424,2011/02/01 02:23:59.000\n3\nADB12A4338A,12412,large_server_12,dev1,/home/kuku/dev/lala/k.txt,2011/02/01 02:23:59.000\nAD12A1C98A3,765,large_server_12,dev2,/home/lala/k.txt,2011/02/01 02:23:59.000\nADB12A4338A,12412,large_server_11,dev2,/home/kuku/lala/k.txt,2011/02/01 02:23:59.000\n")
    cd5 = ContentData.merge(cd3, cd4)
    assert_equal(cd5, content_data)

    intersect = ContentData.intersect(cd3, cd4)
    assert_equal(intersect, ContentData.new)
    intersect = ContentData.intersect(cd5, cd4)
    assert_equal(cd4, intersect)
  end
end
