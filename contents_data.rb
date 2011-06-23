class Content
  attr_reader :checksum, :size, :first_appearance_time, :instances

  @checksum
	@size
	@first_appearance_time
  @instances
end

class ContentInstance
  attr_reader :checksum, :device, :full_path, :modification_time, :content

  @server_name
  @device
	@full_path
  @modification_time
  @content
end

class ContentsData

  def initialize()
  end

  # store new checksum if needed
  def add_content(checksum, size, first_appearance_time)
  end

  def add_instance(server_name, device, full_path, modification_time)
  end

  # checking that checksum is calculated already
  def content_exists(checksum)
  end

  # get all file records for given path
  def get_content_instances_by_pass(full_path)
  end
end
