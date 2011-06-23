class Content
  attr_reader :checksum, :size, :first_appearance_time

  def initialize(checksum, size, first_appearance_time)
  end

  @checksum
	@size
	@first_appearance_time
end

class ContentInstance
  attr_reader :checksum, :device, :full_path, :modification_time

  def initialize(checksum, device, full_path, modification_time)
  end

  @checksum
  @server_name
  @device
	@full_path
  @modification_time
end

class ContentData

  def initialize()
    contents = Hash.new
    instances = Hash.new
  end

  def add_content(content)
    contents[content.checksum] = content
  end

  def add_instance(instance)
  end

  def content_exists(checksum)
    contents.key? checksum
  end
end
