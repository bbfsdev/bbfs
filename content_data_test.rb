require 'content_data.rb'
require 'date.rb'
require 'test/unit'

class TestContentData < Test::Unit::TestCase
  def test_content
    content_data = ContentData.new
    content_data.add_content(Content.new("D12A1C98A3", 765, DateTime.parse("2009-02-01T12:13:59+01:00")))
    content_data.add_content(Content.new("B12A1C98A3", 123123, DateTime.parse("2011-02-01T02:23:59+01:00")))
    content_data.add_content(Content.new("D1234C98A3", 12444, DateTime.parse("2023-02-01T22:23:59+01:00")))
    content_data.add_content(Content.new("DB12A1C233", 2, DateTime.parse("2011-02-01T12:23:59+01:00")))
    content_data.add_content(Content.new("DB12A4338A", 12412, DateTime.parse("2011-12-01T12:23:59+03:00")))
    content_data.add_content(Content.new("232A1C98A3", 124424, DateTime.parse("2011-02-01T12:23:59+01:00")))
    content_data.add_content(Content.new("AC12A1C983", 1242, DateTime.parse("2011-02-01T12:12:59-01:00")))
    
    content_data.add_instance(ContentInstance.new("DB12A1C233", 765, "large_server_1", "dev1",
      "/home/kuku/dev/lala/k.txt", DateTime.parse("2011-02-01T12:23:59+01:00")))
    content_data.add_instance(ContentInstance.new("DB12A4338A", 765, "large_server_1", "dev2",
      "/home/kuku/dev/lala/k1.txt", DateTime.parse("2011-02-01T12:23:59+01:00")))
    content_data.add_instance(ContentInstance.new("232A1C98A3", 765, "large_server_1", "dev3",
      "/home/kuku/dev/k.txt", DateTime.parse("2011-02-01T12:23:59+01:00")))
    content_data.add_instance(ContentInstance.new("DB12A4338A", 765, "large_server_2", "dev2",
      "/home/lala/k.txt", DateTime.parse("2011-02-01T12:23:59+01:00")))
    content_data.add_instance(ContentInstance.new("D1234C98A3", 765, "large_server_2", "dev1",
      "/home/kuku/lala/k.txt", DateTime.parse("2011-02-01T12:23:59+01:00")))
    content_data.add_instance(ContentInstance.new("D12A1C98A3", 765, "large_server_2", "dev1",
      "/home/kuku/dev/lala/k.txt", DateTime.parse("2011-02-01T12:23:59+01:00")))
    content_data.add_instance(ContentInstance.new("AC12A1C983", 765, "large_server_2", "dev2",
      "/home/kuku/dev/lala/k1.txt", DateTime.parse("2011-02-01T12:23:59+01:00")))
    content_data.add_instance(ContentInstance.new("232A1C98A3", 765, "large_server_2", "dev3",
      "/home/kuku/dev/k.txt", DateTime.parse("2011-02-01T12:23:59+01:00")))
    content_data.add_instance(ContentInstance.new("D12A1C98A3", 765, "large_server_2", "dev2",
      "/home/lala/k.txt", DateTime.parse("2011-02-01T12:23:59+01:00")))
    content_data.add_instance(ContentInstance.new("D1234C98A3", 12412, "large_server_2", "dev1",
      "/home/kuku/lala/k.txt", DateTime.parse("2011-02-01T12:23:59+01:00")))    
    content_data.add_instance(ContentInstance.new("DB12A4338A", 12412, "large_server_2", "dev1",
      "/home/kuku/dev/lala/k.txt", DateTime.parse("2011-02-01T12:23:59+01:00")))
    content_data.add_instance(ContentInstance.new("AC12A1C983", 12412, "large_server_2", "dev2",
      "/home/kuku/kuku/dev/lala/k1.txt", DateTime.parse("2011-02-01T12:23:59+01:00")))
    content_data.add_instance(ContentInstance.new("232A1C98A3", 12412, "large_server_2", "dev3",
      "/home/kuku/kuku/dev/k.txt", DateTime.parse("2011-02-01T12:23:59+01:00")))
    content_data.add_instance(ContentInstance.new("DB12A4338A", 12412, "large_server_1", "dev2",
      "/home/kuku/lala/k.txt", DateTime.parse("2011-02-01T12:23:59+01:00")))
    content_data.add_instance(ContentInstance.new("D1234C98A3", 12412, "large_server_1", "dev1",
      "/home/kuku/kuku/lala/k.txt", DateTime.parse("2011-02-01T12:23:59+01:00")))

    print content_data.to_s

    assert_equal("7\nAC12A1C983,1242,2011-02-01T12:12:59-01:00\nB12A1C98A3,123123,2011-02-01T02:23:59+01:00\nDB12A4338A,12412,2011-12-01T12:23:59+03:00\nD1234C98A3,12444,2023-02-01T22:23:59+01:00\nD12A1C98A3,765,2009-02-01T12:13:59+01:00\n232A1C98A3,124424,2011-02-01T12:23:59+01:00\nDB12A1C233,2,2011-02-01T12:23:59+01:00\n3\nDB12A4338A,12412,large_server_1,dev2,/home/kuku/lala/k.txt,2011-02-01T12:23:59+01:00\nDB12A4338A,12412,large_server_2,dev1,/home/kuku/dev/lala/k.txt,2011-02-01T12:23:59+01:00\nD12A1C98A3,765,large_server_2,dev2,/home/lala/k.txt,2011-02-01T12:23:59+01:00\n",
      content_data.to_s)
    content_data.to_file("content_data_test.data")
    new_content_data = ContentData.new()
    new_content_data.from_file("content_data_test.data")
    assert_equal(true, new_content_data == content_data)
    #assert_equal(content_data.to_s, new_content_data.to_s)
  end
end