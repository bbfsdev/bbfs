require 'log'
require 'params'
require 'time'

module ContentData
  Params.string('instance_check_level', 'shallow', 'Defines check level. Supported levels are: ' \
                'shallow - quick, tests instance for file existence and attributes. ' \
                'deep - can take more time, in addition to shallow recalculates hash sum.')

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
      ContentInstance.instance_global_path(@server_name, @full_path)
    end

    def ContentInstance.instance_global_path(server_name, full_path)
      "%s:%s" % [server_name, full_path]
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
  end

  # Unfortunately this class is used as mutable for now. So need to be carefull.
  # TODO(kolman): Make this class imutable, but add indexing structure to it.
  # TODO(kolman): Add wrapper to the class to enable dynamic content data
  # (with easy access indexes)
  class ContentData
    attr_reader :contents, :instances

    # @param content_data_serializer_str [String]
    def initialize(copy = nil)
      if copy.nil?
        @contents = Hash.new # key is a checksum , value is a refernce to the Content object
        @instances = Hash.new  # key is an instance global path , value is a reference to the ContentInstance object
      else
        # Regenerate only the hashes, the values are immutable.
        @contents = copy.contents.clone
        @instances = copy.instances.clone
      end
    end

    def add_content(content)
      @contents[content.checksum] = content
    end

    def add_instance(instance)
      if (not @contents.key?(instance.checksum))
        Log.warning sprintf("Adding instance while it's" +
                                " checksum %s does not exists.\n", instance.checksum)
        Log.warning sprintf("%s\n", instance.to_s)
        return false
      elsif (@contents[instance.checksum].size != instance.size)
        Log.warning 'File size different from content size while same checksum'
        Log.warning instance.to_s
        return false
      end

      key = instance.global_path

      #override file if needed
      @instances[key] = instance
    end

    def empty?
      @contents.empty?
    end

    # TODO rename method with finishing '?', cause it returns a boolean
    def content_exists(checksum)
      @contents.key? checksum
    end

    # TODO(kolman): The semantics of thir merge is merge! change in all file.
    def merge(content_data)
      content_data.contents.values.each { |content|
        add_content(content)
      }
      content_data.instances.values.each { |instance|
        add_instance(instance)
      }
    end

    def ==(other)
      return false if other == nil
      return false unless @contents.size == other.contents.size
      return false unless @instances.size == other.instances.size

      @contents.keys.each { |key|
        if (@contents[key] != other.contents[key])
          Log.info @contents[key].first_appearance_time.to_i
          Log.info other.contents[key].first_appearance_time.to_i
          return false
        end
      }
      @instances.keys.each { |key|
        if (@instances[key] != other.instances[key])
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
      content_data_dir = File.dirname(filename)
      FileUtils.makedirs(content_data_dir) unless File.directory?(content_data_dir)
      File.open(filename, 'w') {|f| f.write(to_s) }
    end

    # TODO validation that file indeed contains ContentData missing
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
        if lines[i].nil?
          Log.info "lines[i] if nil !!!, Backing filename: #{filename} to #{filename}.bad"
          FileUtils.cp(filename, "#{filename}.bad")
          Log.info lines[i].join("\n")
        end
        parameters = lines[i].split(',')
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

    def self.parse_time time_str
      return nil unless time_str.instance_of? String
      seconds_from_epoch = Integer time_str  # Not using to_i here because it does not check string is integer.
      time = Time.at seconds_from_epoch
    end

    def self.format_time(time)
      return nil unless time.instance_of?Time
      str = time.to_i.to_s
      return str
    end

    # merges content data a and content data b to a new content data and returns it.
    def self.merge(a, b)
      return b unless not a.nil?
      return a unless not b.nil?

      return nil unless a.instance_of?ContentData
      return nil unless b.instance_of?ContentData

      ret = ContentData.new
      ret.merge(a)
      ret.merge(b)

      return ret
    end

    # removed content data a from content data b and returns the new content data.
    def self.remove(a, b)
      return nil unless a.instance_of?ContentData
      return nil unless b.instance_of?ContentData

      ret = ContentData.new

      b.contents.values.each { |content|
        #print "%s - %s\n" % [content.checksum, a.content_exists(content.checksum).to_s]
        ret.add_content(content) unless a.content_exists(content.checksum)
      }

      #Log.info "kaka"

      b.instances.values.each { |instance|
        #print "%s - %s\n" % [instance.checksum, a.content_exists(instance.checksum).to_s]
        ret.add_instance(instance) unless a.content_exists(instance.checksum)
      }

      #print "kuku %s" % ret.contents.size.to_s
      #print "kuku %s" % ret.instances.size.to_s
      return ret
    end

    def self.remove_instances(a, b)
      return nil unless a.instance_of?ContentData
      return nil unless b.instance_of?ContentData

      ret = ContentData.new
      b.instances.values.each do |instance|
        if !a.instances.key?(instance.global_path)
          ret.add_content(b.contents[instance.checksum])
          ret.add_instance(instance)
        end
      end
      return ret
    end

    def self.remove_directory(cd, global_dir_path)
      return nil unless cd.instance_of?ContentData

      ret = ContentData.new
      cd.instances.values.each do |instance|
        Log.debug3("global path to check: #{global_dir_path}")
        Log.debug3("instance global path: #{instance.global_path}")
        if instance.global_path.scan(global_dir_path).size == 0
          Log.debug3("Adding instance.")
          ret.add_content(cd.contents[instance.checksum])
          ret.add_instance(instance)
        end
      end
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

        unless (checksum2instances.has_key? checksum)
          checksum2instances[checksum] = []
        end
        checksum2instances[checksum] << instance

        if (not checksum2time.has_key? checksum)
          checksum2time[checksum] = time
        elsif ((checksum2time[checksum] <=> time) > 0)
          checksum2time[checksum] = time
        end
      end

      # update min time table with time information from contents
      db.contents.each do |checksum, content|
        time = content.first_appearance_time
        if (not checksum2time.has_key? checksum)
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
            mod_instance = ContentInstance.new(instance.checksum, instance.size,
                                               instance.server_name, instance.device,
                                               instance.full_path, time)
            mod_db.add_instance(mod_instance)
          end
        end
      end
      mod_db
    end

    # Validates index against file system that all instances hold a correct data regarding files
    # that they represrents.
    #
    # There are two levels of validation, controlled by instance_check_level system parameter:
    # * shallow - quick, tests instance for file existence and attributes.
    # * deep - can take more time, in addition to shallow recalculates hash sum.
    # @param [Hash] params hash of parameters of validation, can be used to return additional data.
    #
    #     Supported key/value combinations:
    #     * key is <tt>:failed</tt> value is <tt>ContentData</tt> used to return failed instances
    # @return [Boolean] true when index is correct, false otherwise
    def validate(params = nil)
      # used to answer whether specific param was set
      param_exists = Proc.new do |param|
        !(params.nil? || params[param].nil?)
      end

      # used to process method parameters centrally
      process_params = Proc.new do |values|
        # values is a Hash with keys: :content, :instance and value appropriate to key
        if param_exists.call :failed
          unless values[:content].nil?
            params[:failed].add_content values[:content]
          end
          unless values[:instance].nil?
            # appropriate content should be already added
            params[:failed].add_instance values[:instance]
          end
        end
      end

      is_valid = true
      instances.each_value do |instance|
        unless check_instance instance
          is_valid = false

          unless params.nil? || params.empty?
            process_params.call :content => contents[instance.checksum], :instance => instance
          end
        end
      end

      is_valid
    end

    def shallow_check(instance)
      path = instance.full_path
      is_valid = true

      if (File.exists?(path))
        if File.size(path) != instance.size
          is_valid = false
          err_msg = "#{path} size #{File.size(path)} differs from indexed size #{instance.size}"
          Log.warning err_msg
        end
        #if ContentData.format_time(File.mtime(path)) != instance.modification_time
        if File.mtime(path).to_i != instance.modification_time.to_i
          is_valid = false
          err_msg = "#{path} modification time #{File.mtime(path)} differs from " \
              + "indexed #{instance.modification_time}"
          Log.warning err_msg
        end
      else
        is_valid = false
        err_msg = "Indexed file #{path} doesn't exist"
        Log.warning err_msg
      end
      is_valid
    end

    def deep_check(instance)
      if shallow_check(instance)
        path = instance.full_path
        current_checksum = FileIndexing::IndexAgent.get_checksum(path)
        if instance.checksum == current_checksum
          true
        else
          err_msg = "#{path} checksum #{current_checksum} differs from indexed #{instance.checksum}"
          Log.warning err_msg
          false
        end
      else
        false
      end
    end

    def check_instance(instance)
      case Params['instance_check_level']
        when 'deep'
          deep_check instance
        when 'shallow'
          shallow_check instance
        else
          # TODO remove it when params will support set of values
          throw ArgumentError.new "Unsupported check level #{Params['instance_check_level']}"
      end
    end


    # TODO simplify conditions
    # This mehod is experimental and shouldn\'t be used
    # nil is used to define +/- infinity for to/from method arguments
    # from/to values are exlusive in condition'a calculations
    # Need to take care about '==' operation that is used for object's comparison.
    # In need of case user should define it's own '==' implemementation.
    def get_query(variable, params)
      raise RuntimeError.new 'This method is experimental and shouldn\'t be used'

      exact = params['exact'].nil? ? Array.new : params['exact']
      from = params['from']
      to = params ['to']
      is_inside = params['is_inside']

      unless ContentInstance.new.instance_variable_defined?("@#{attribute}")
        raise ArgumentError "#{variable} isn't a ContentInstance variable"
      end

      if (exact.nil? && from.nil? && to.nil?)
        raise ArgumentError 'At least one of the argiments {exact, from, to} must be defined'
      end

      if (!(from.nil? || to.nil?) && from.kind_of?(to.class))
        raise ArgumentError 'to and from arguments should be comparable one with another'
      end

      # FIXME add support for from/to for Strings
      if ((!from.nil? && !from.kind_of?(Numeric.new.class))\
            || (!to.nil? && to.kind_of?(Numeric.new.class)))
        raise ArgumentError 'from and to options supported only for numeric values'
      end

      if (!exact.empty? && (!from.nil? || !to.nil?))
        raise ArgumentError 'exact and from/to options are mutually exclusive'
      end

      result_index = ContentData.new
      instances.each_value do |instance|
        is_match = false
        var_value = instance.instance_variable_get("@#{variable}")

        if exact.include? var_value
          is_match = true
        elsif (from.nil? || var_value > from) && (to.nil? || var_value < to)
          is_match = true
        end

        if (is_match && is_inside) || (!is_match && !is_inside)
          checksum = instance.checksum
          result_index.add_content(contents[checksum]) unless result_index.content_exists(checksum)
          result_index.add_instance instance
        end
      end
      result_index
    end

    private :shallow_check, :deep_check, :check_instance
  end

  # Validates index against file system that all instances hold a correct data regarding files
  # that they represrents.
  #
  # There are two levels of validation, controlled by instance_check_level system parameter:
  # * shallow - quick, tests instance for file existence and attributes.
  # * deep - can take more time, in addition to shallow recalculates hash sum.
  # @param [Hash] params hash of parameters of validation, can be used to return additional data.
  #
  #     Supported key/value combinations:
  #     * key is <tt>:failed</tt> value is <tt>ContentData</tt> used to return failed instances
  # @return [Boolean] true when index is correct, false otherwise
  # @raise [ArgumentError] when instance_check_level is incorrect
  def validate(params = nil)
    # used to answer whether specific param was set
    param_exists = Proc.new do |param|
      !(params.nil? || params[param].nil?)
    end

    # used to process method parameters centrally
    process_params = Proc.new do |values|
      # values is a Hash with keys: :content, :instance and value appropriate to key
      if param_exists.call :failed
        unless values[:content].nil?
          params[:failed].add_content values[:content]
        end
        unless values[:instance].nil?
          # appropriate content should be already added
          params[:failed].add_instance values[:instance]
        end
      end
    end

    is_valid = true
    instances.each_value do |instance|
      unless check_instance instance
        is_valid = false

        unless params.nil? || params.empty?
          process_params.call :content => contents[instance.checksum], :instance => instance
        end
      end
    end

    is_valid
  end

  def shallow_check(instance)
    path = instance.full_path
    is_valid = true

    if (File.exists?(path))
      if File.size(path) != instance.size
        is_valid = false
        err_msg = "#{path} size #{File.size(path)} differs from indexed size #{instance.size}"
        Log.warning err_msg
      end
      #if ContentData.format_time(File.mtime(path)) != instance.modification_time
      if File.mtime(path).to_i != instance.modification_time.to_i
        is_valid = false
        err_msg = "#{path} modification time #{File.mtime(path)} differs from " \
            + "indexed #{instance.modification_time}"
        Log.warning err_msg
      end
    else
      is_valid = false
      err_msg = "Indexed file #{path} doesn't exist"
      Log.warning err_msg
    end
    is_valid
  end

  def deep_check(instance)
    if shallow_check(instance)
      path = instance.full_path
      current_checksum = FileIndexing::IndexAgent.get_checksum(path)
      if instance.checksum == current_checksum
        true
      else
        err_msg = "#{path} checksum #{current_checksum} differs from indexed #{instance.checksum}"
        Log.warning err_msg
        false
      end
    else
      false
    end
  end

  # @raise [ArgumentError] when instance_check_level is incorrect
  def check_instance(instance)
    case Params['instance_check_level']
      when 'deep'
        deep_check instance
      when 'shallow'
        shallow_check instance
      else
        # TODO remove it when params will support set of values
        throw ArgumentError.new "Unsupported check level #{Params['instance_check_level']}"
    end
  end


  # TODO simplify conditions
  # This mehod is experimental and shouldn\'t be used
  # nil is used to define +/- infinity for to/from method arguments
  # from/to values are exlusive in condition'a calculations
  # Need to take care about '==' operation that is used for object's comparison.
  # In need of case user should define it's own '==' implemementation.
  def get_query(variable, params)
    raise RuntimeError.new 'This method is experimental and shouldn\'t be used'

    exact = params['exact'].nil? ? Array.new : params['exact']
    from = params['from']
    to = params ['to']
    is_inside = params['is_inside']

    unless ContentInstance.new.instance_variable_defined?("@#{attribute}")
      raise ArgumentError "#{variable} isn't a ContentInstance variable"
    end

    if (exact.nil? && from.nil? && to.nil?)
      raise ArgumentError 'At least one of the argiments {exact, from, to} must be defined'
    end

    if (!(from.nil? || to.nil?) && from.kind_of?(to.class))
      raise ArgumentError 'to and from arguments should be comparable one with another'
    end

    # FIXME add support for from/to for Strings
    if ((!from.nil? && !from.kind_of?(Numeric.new.class))\
          || (!to.nil? && to.kind_of?(Numeric.new.class)))
      raise ArgumentError 'from and to options supported only for numeric values'
    end

    if (!exact.empty? && (!from.nil? || !to.nil?))
      raise ArgumentError 'exact and from/to options are mutually exclusive'
    end

    result_index = ContentData.new
    instances.each_value do |instance|
      is_match = false
      var_value = instance.instance_variable_get("@#{variable}")

      if exact.include? var_value
        is_match = true
      elsif (from.nil? || var_value > from) && (to.nil? || var_value < to)
        is_match = true
      end

      if (is_match && is_inside) || (!is_match && !is_inside)
        checksum = instance.checksum
        result_index.add_content(contents[checksum]) unless result_index.content_exists(checksum)
        result_index.add_instance instance
      end
    end
    result_index
  end

  private :shallow_check, :deep_check, :check_instance, :get_query
end

