require 'time'
require './content_data.pb.rb'

class Content
  attr_reader :checksum, :size, :first_appearance_time

  def initialize(checksum, size, first_appearance_time, content_serializer = nil)
    if content_serializer != nil
      if (content_serializer.checksum == nil)
        raise ArgumentError.new("checksum have to be defined")
      else
        @checksum = content_serializer.checksum
      end
      if (content_serializer.size == nil)
        raise ArgumentError.new("size have to be defined")
      else
        @size = content_serializer.size
      end
      if (content_serializer.first_appearance_time == nil)
        raise ArgumentError.new("first_appearance_time have to be defined")
      else
        @first_appearance_time = ContentData.parse_time(content_serializer.first_appearance_time)
      end

    else
      @checksum = checksum
      @size = size
      @first_appearance_time = first_appearance_time
    end
  end



  def to_s
    "%s,%d,%s" % [@checksum, @size, ContentData.format_time(@first_appearance_time)]
  end

  def ==(other)
    return (self.checksum.eql? other.checksum and
        self.size.eql? other.size and
        self.first_appearance_time.to_i.eql? other.first_appearance_time.to_i)
  end

  def serialize
    serializer = ContentMessage.new
    serializer.checksum = checksum
    serializer.size = size
    serializer.first_appearance_time = ContentData.format_time(first_appearance_time)

    serializer
  end
end

class ContentInstance
  attr_reader :checksum, :size, :server_name, :device, :full_path, :modification_time

  def initialize(checksum, size, server_name, device, full_path, modification_time, content_instance_serializer = nil)
    if content_instance_serializer != nil
      if (content_instance_serializer.checksum == nil)
        raise ArgumentError.new("checksum have to be defined")
      else
        @checksum = content_instance_serializer.checksum
      end
      if (content_instance_serializer.size == nil)
        raise ArgumentError.new("size have to be defined")
      else
        @size = content_instance_serializer.size
      end
      if (content_instance_serializer.modification_time == nil)
        raise ArgumentError.new("modification_time have to be defined")
      else
        @modification_time = ContentData.parse_time(content_instance_serializer.modification_time)
      end
      if (content_instance_serializer.server_name == nil)
        raise ArgumentError.new("server_name have to be defined")
      else
        @server_name = content_instance_serializer.server_name
      end
      if (content_instance_serializer.device == nil)
        raise ArgumentError.new("device have to be defined")
      else
        @device = content_instance_serializer.device
      end
      if (content_instance_serializer.full_path == nil)
        raise ArgumentError.new("full_path have to be defined")
      else
        @full_path = content_instance_serializer.full_path
      end
    else
      @checksum = checksum
      @size = size
      @server_name = server_name
      @device = device
      @full_path = full_path
      @modification_time = modification_time
    end
  end

  def global_path
    "%s:%s:%s" % [@server_name, @device, @full_path]
  end

  def to_s
    "%s,%d,%s,%s,%s,%s" % [@checksum, @size, @server_name,
                           @device, @full_path, ContentData.format_time(@modification_time)]
  end

  def ==(other)
    return (self.checksum.eql? other.checksum and
        self.size.eql? other.size and
        self.server_name.eql? other.server_name and
        self.device.eql? other.device and
        self.full_path.eql? other.full_path and
        self.modification_time.to_i.eql? other.modification_time.to_i)
  end

  def serialize
    serializer = ContentInstanceMessage.new
    serializer.checksum = checksum
    serializer.size = size
    serializer.modification_time = ContentData.format_time(modification_time)
    serializer.server_name = server_name
    serializer.device = device.to_s
    serializer.full_path = full_path

    serializer
  end

  #@checksum
  #@size
  #@server_name
  #@device
  #@full_path
  #@modification_time
end

class ContentData
  attr_reader :contents, :instances

  # @param content_data_serializer_str [String]
  def initialize(content_data_serializer = nil)
    @contents = Hash.new # key is a checksum , value is a refernce to the Content object
    @instances = Hash.new  # key is an instance global path , value is a reference to the ContentInstance object
    if (content_data_serializer != nil)
      content_data_serializer.contents.each do |entry|
        key = entry.key
        value = entry.value
        content_serializer = value.content
        raise ArgumentError.new("content have to be defined") if content_serializer.nil?
        content = Content.new(nil, nil, nil, content_serializer)
        @contents[key] = content
      end
      content_data_serializer.instances.each do |entry|
        key = entry.key
        value = entry.value
        content_instance_serializer = value.instance
        raise ArgumentError.new("instance have to be defined") if content_instance_serializer.nil?
        content_instance = ContentInstance.new(nil, nil, nil, nil, nil, nil, content_instance_serializer)
        @instances[key] = content_instance
      end
    end
  end

  def serialize (serializer = nil)
    serializer = ContentDataMessage.new if (serializer == nil)
    contents.each do |key, value|
      hash_value = ContentDataMessage::HashEntry::HashValue.new
      content_serializer = value.serialize
      #content_serializer = ContentMessage.new
      #content_serializer.parse_from_string(content_serializer_str)
      hash_value.content = content_serializer
      hash_entry = ContentDataMessage::HashEntry.new
      hash_entry.key = key
      hash_entry.value = hash_value
      serializer.contents << hash_entry
    end
    instances.each do |key, value|
      hash_value = ContentDataMessage::HashEntry::HashValue.new
      instance_serializer = value.serialize
      #instance_serializer = ContentInstanceMessage.new
      #instance_serializer.parse_from_string(instance_serializer_str)
      hash_value.instance = instance_serializer
      hash_entry = ContentDataMessage::HashEntry.new
      hash_entry.key = key
      hash_entry.value = hash_value
      serializer.instances << hash_entry
    end
    serializer
  end

  def add_content(content)
    @contents[content.checksum] = content
  end

  def add_instance(instance)
    if (not @contents.key?(instance.checksum))
      printf("Warning: Adding instance while it's" +
                 " checksum %s does not exists.\n", instance.checksum)
      printf("%s\n", instance.to_s)
      return false
    elsif (@contents[instance.checksum].size != instance.size)
      print("Warning: File size different from content size while same checksum.\n")
      printf("%s\n", instance.to_s)
      return false
    end

    key = instance.global_path

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

    #print "size:%s\n" % @contents.size
    #print "other size:%s\n" % other.contents.size
    return false if other == nil
    return false unless @contents.size == other.contents.size
    return false unless @instances.size == other.instances.size

    @contents.keys.each { |key|
      if (@contents[key] != other.contents[key])
        #print "%s-" % @contents[key].to_s
        #print other.contents[key].to_s
        #puts " compare - false"
        puts @contents[key].first_appearance_time.to_i
        puts other.contents[key].first_appearance_time.to_i
        return false
      end
    }

    @instances.keys.each { |key|
      if (@instances[key] != other.instances[key])
        #print "%s-" % @instances[key].to_s
        #print other.instances[key].to_s
        #puts " compare - false"
        return false
      end
    }
    #puts "compare - true"
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
                              ContentData.parse_time(parameters[2])))
      i += 1
    }

    number_of_instances = lines[i].to_i
    i += 1
    number_of_instances.times {
      parameters = lines[i].split(",")
      # bugfix: if file name consist a comma then parsing based on comma separating fails
      if (parameters.size > 6)
        (5..parameters.size-2).each do |i|
          parameters[4] = [parameters[4], parameters[i]].join(",")
        end
        (5..parameters.size-2).each do |i|
          parameters.delete_at(5)
        end
      end

      add_instance(ContentInstance.new(parameters[0],
                                       parameters[1].to_i,
                                       parameters[2],
                                       parameters[3],
                                       parameters[4],
                                       ContentData.parse_time(parameters[5])))
      i += 1
    }
  end

  def self.parse_time(time_str)
    return Nil unless time_str.instance_of?String
    time = Time.strptime( time_str, '%Y/%m/%d %H:%M:%S.%L' )
    # another option to parse a time
    #require 'scanf.rb'
    #time_arr = time_str.scanf("%d/%d/%d %d:%d:%d.%d")
    #time = Time.utc(time_arr[0], time_arr[1],time_arr[2],time_arr[3],time_arr[4],time_arr[5],time_arr[6])
  end

  def self.format_time(time)
    return Nil unless time.instance_of?Time
    #puts time.class
    str = time.strftime( '%Y/%m/%d %H:%M:%S.%L' )
    #puts str
    return str
  end

  # merges content data a and content data b to a new content data and returns it.
  def self.merge(a, b)
    return b unless not a.nil?
    return a unless not b.nil?

    return Nil unless a.instance_of?ContentData
    return Nil unless b.instance_of?ContentData

    ret = ContentData.new
    ret.merge(a)
    ret.merge(b)

    return ret
  end

  # removed content data a from content data b and returns the new content data.
  def self.remove(a, b)
    return Nil unless a.instance_of?ContentData
    return Nil unless b.instance_of?ContentData

    ret = ContentData.new

    b.contents.values.each { |content|
      #print "%s - %s\n" % [content.checksum, a.content_exists(content.checksum).to_s]
      ret.add_content(content) unless a.content_exists(content.checksum)
    }

    #puts "kaka"

    b.instances.values.each { |instance|
      #print "%s - %s\n" % [instance.checksum, a.content_exists(instance.checksum).to_s]
      ret.add_instance(instance) unless a.content_exists(instance.checksum)
    }

    #print "kuku %s" % ret.contents.size.to_s
    #print "kuku %s" % ret.instances.size.to_s
    return ret
  end

  # returns the common content in both a and b
  def self.intersect(a, b)
    b_minus_a = ContentData.remove(a, b)
    return ContentData.remove(b_minus_a, b)
  end

  # unify time for all entries with same content to minimal time
  def self.unify_time(db)
    mod_db = ContentData.new # resulting ContentData that will consists objects with unified time 
    checksum2time = Hash.new # key=checksum value=min_time_for_this_checksum
    checksum2instances = Hash.new # key=checksum value=array_of_instances_with_this_checksum (Will be replaced with ContentData method)

    # populate tables with given ContentData entries
    db.instances.each_value do |instance|
      checksum = instance.checksum
      time = instance.modification_time

      unless (checksum2instances.has_key?checksum)
        checksum2instances[checksum] = []
      end
      checksum2instances[checksum] << instance

      if (not checksum2time.has_key?checksum)
        checksum2time[checksum] = time
      elsif ((checksum2time[checksum] <=> time) > 0)
        checksum2time[checksum] = time
      end
    end

    # update min time table with time information from contents
    db.contents.each do |checksum, content|
      time = content.first_appearance_time
      if (not checksum2time.has_key?checksum)
        checksum2time[checksum] = time
      elsif ((checksum2time[checksum] <=> time) > 0)
        checksum2time[checksum] = time
      end
    end

    # add content entries to the output table. in need of case update time field with found min time
    db.contents.each do |checksum, content|
      time = checksum2time[checksum]
      if ((content.first_appearance_time <=> time) == 0)
        mod_db.add_content(content)
      else
        mod_db.add_content(Content.new(checksum, content.size, time))
      end
    end

    # add instance entries to the output table. in need of case update time field with found min time
    checksum2instances.each do |checksum, instances|
      time = checksum2time[checksum]
      instances.each do |instance|
        if ((instance.modification_time <=> time) == 0)
          mod_db.add_instance(instance)
        else # must be bigger then found min time
          mod_instance = ContentInstance.new(instance.checksum, instance.size, instance.server_name, instance.device, instance.full_path, time)
          mod_db.add_instance(mod_instance)
        end
      end
    end
    mod_db
  end
end
