class Content
  attr_reader :checksum, :size, :first_appearance_time, :instances

  @checksum
	@size
	@first_appearance_time
end

class ContentInstance
  attr_reader :checksum, :device, :full_path, :modification_time, :content

  @server_name
  @device
	@full_path
  @modification_time
end

class ContentsData

  def initialize()
  end

  # store new checksum if needed
  def add_content(content)
  end

  def add_instance(instance)
  end

  # checking that checksum is calculated already
  def content_exists(checksum)
  end
end
