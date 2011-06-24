class Content
  attr_reader :checksum, :size, :first_appearance_time

  def initialize(checksum, size, first_appearance_time)
    @checksum = checksum
    @size = size
    @first_appearance_time = first_appearance_time
  end

  @checksum
	@size
	@first_appearance_time
  
  def to_s
    "%s,%d,%s" % [@checksum, @size, @first_appearance_time.to_s]
  end
end

class ContentInstance
  attr_reader :checksum, :size, :server_name, :device, :full_path, :modification_time

  def initialize(checksum, size, server_name, device, full_path, modification_time)
    @checksum = checksum
    @size = size
    @server_name = server_name
    @device = device
  	@full_path = full_path
    @modification_time = modification_time
  end

  def to_s
    "%s,%d,%s,%s,%s,%s" % [@checksum, @size, @server_name, 
                           @device, @full_path, @modification_time.to_s]
  end

  @checksum
  @size
  @server_name
  @device
	@full_path
  @modification_time
end

class ContentData
  attr_reader :contents, :instances

  def initialize()
    @contents = Hash.new
    @instances = Hash.new
  end

  def add_content(content)
    @contents[content.checksum] = content
  end

  def add_instance(instance)
    if (not @contents.key?(instance.checksum))
      printf("Warning: Adding instance while it's" +
             " checksum %s does not exists.\n", instance.checksum)
      return false
    elsif (@contents[instance.checksum].size != instance.size)
      print("Warning: File size different from content size while same checksum.\n")
      return false
    end

    key = "%s:%s:%s" % [instance.server_name, 
                        instance.device, 
                        instance.full_path]

    #override file if needed
    @instances[key] = instance
  end

  def content_exists(checksum)
    @contents.key? checksum
  end
  
  def merge(content_data)
    content_data.contents.values.each { |content|
      add_content(content)
    }
    content_data.instances.values.each { |instance|
      add_instance(instance)
    }
  end
  
  def ==(other)
    @contents.keys { |key|
      if (@contents[key] != other.contents[key])
        print @contents[key].to_s
        print other.contents[key].to_s
        return false
      end
    }
    @instances.keys { |key|
      if (@instances[key] != other.instances[key])
        print @instances[key].to_s
        print other.instances[key].to_s
        return false
      end
    }
    return true
  end

  def to_s
    ret = ""
    ret << @contents.length.to_s << "\n"
    @contents.each_value { |content|
      ret << content.to_s << "\n"
    }
    ret << @instances.length.to_s << "\n"
    @instances.each_value { |instance|
      ret << instance.to_s << "\n"
    }
    return ret
  end

  def to_file(filename)
    File.open(filename, 'w') {|f| f.write(to_s) }
  end

  def from_file(filename)
    lines = IO.readlines(filename)
    i = 0
    number_of_contents = lines[i].to_i
    i += 1
    number_of_contents.times {
      parameters = lines[i].split(",")
      add_content(Content.new(parameters[0], 
                              parameters[1].to_i, 
                              DateTime.parse(parameters[2])))
      i += 1
    }
    
    number_of_instances = lines[i].to_i
    i += 1
    number_of_instances.times {
      parameters = lines[i].split(",")
      add_instance(ContentInstance.new(parameters[0],
                                       parameters[1].to_i,
                                       parameters[2],
                                       parameters[3],
                                       parameters[4],
                                       DateTime.parse(parameters[5])))
    }
  end
end
