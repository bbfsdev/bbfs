require 'content_data.rb'
require 'test/unit'

class TestContentData < Test::Unit::TestCase
  def content_test
    content_data = ContentData.new
    content_data.add_content(Content.new("DB12A1C98A3", 765, Date.now))
  end
end