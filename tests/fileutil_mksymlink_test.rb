require './content_data.rb'
require './fileutil.rb'
require 'test/unit'

class TestFileUtilMkDirSymLink < Test::Unit::TestCase
  def test_create_symlink_structure
    cd1 = ContentData.new
    cd1.add_content(Content.new('A', 5, "2000/1/1 01:01:01.001"))
    cd1.add_content(Content.new('B', 5, "2000/1/1 01:01:01.001"))
    cd1.add_content(Content.new('C', 5, "2000/1/1 01:01:01.001"))
    cd1.add_content(Content.new('E', 5, "2000/1/1 01:01:01.001"))
    cd1.add_content(Content.new('D', 5, "2000/1/1 01:01:01.001"))
    cd1.add_instance(ContentInstance.new('A', 5, "s1", "hd1", "/dir1/file1", "1999/1/1 01:01:01.001"))
    cd1.add_instance(ContentInstance.new('B', 5, "s1", "hd1", "/dir1/file2", "1999/1/1 01:01:01.001"))
    cd1.add_instance(ContentInstance.new('C', 5, "s1", "hd1", "/dir2/file3", "1999/1/1 01:01:01.001"))
    cd1.add_instance(ContentInstance.new('D', 5, "s1", "hd1", "/dir2/dir3/file4", "1999/1/1 01:01:01.001"))
    cd1.add_instance(ContentInstance.new('E', 5, "s1", "hd1", "/dir2/dir3/file5", "1999/1/1 01:01:01.001"))
    cd2 = ContentData.new
    cd2.add_content(Content.new('A', 5, "2000/1/1 01:01:01.001"))
    cd2.add_content(Content.new('B', 5, "2000/1/1 01:01:01.001"))
    cd2.add_content(Content.new('C', 5, "2000/1/1 01:01:01.001"))
    cd2.add_content(Content.new('D', 5, "2000/1/1 01:01:01.001"))
    cd2.add_instance(ContentInstance.new('A', 5, "s2", "hd1", "/dir15/file2221", "1999/1/1 01:01:01.001"))
    cd2.add_instance(ContentInstance.new('B', 5, "s2", "hd2", "/file2", "1999/1/1 01:01:01.001"))
    cd2.add_instance(ContentInstance.new('C', 5, "s3", "hd2", "/dir22/dir4/dir7/file3", "1999/1/1 01:01:01.001"))
    cd2.add_instance(ContentInstance.new('D', 5, "s4", "hd3", "/dir2/dir3/file4", "1999/1/1 01:01:01.001"))

    output = FileUtil.mksymlink(cd1, cd2, "/myroot/kuku")

    assert_equal(output[0],
      ["s1:hd1:/dir1/file1 => /myroot/kukus2:hd1:/dir15/file2221",
       "s1:hd1:/dir1/file2 => /myroot/kukus2:hd2:/file2",
       "s1:hd1:/dir2/file3 => /myroot/kukus3:hd2:/dir22/dir4/dir7/file3",
       "s1:hd1:/dir2/dir3/file4 => /myroot/kukus4:hd3:/dir2/dir3/file4"])

    assert_equal(output[1],
      ["Warning: base content does not contains:'E'"])

  end
end