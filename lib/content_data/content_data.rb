require 'log'
require 'params'

module ContentData
  Params.string('instance_check_level', 'shallow', 'Defines check level. Supported levels are: ' \
                'shallow - quick, tests instance for file existence and attributes. ' \
                'deep - can take more time, in addition to shallow recalculates hash sum.')

  # Content Data(CD) object holds files information as contents and instances
  # Files info retrieved from hardware: checksum, size, time modification, server, device and path
  # Those attributes are divided into content and instance attributes:
  #   unique checksum, size are content attributes
  #   time modification, server, device and path are instance attributes
  # The relationship between content and instances is 1:many meaning that
  # a content can have instances in many servers.
  # content also has time attribute, which has the value of the time of the first instance.
  # This can be changed by using unify_time method  which sets all time attributes for a content and it's
  # instances to the min time off all.
  # Different files(instances) with same content(checksum), are grouped together under that content.
  # Interface methods include:
  #   iterate over contents and instances info,
  #   unify time, add/remove instance, queries, merge, remove directory and more.
  # Content info data structure:
  #   @contents_info = { Checksum -> [size, *instances*, content_modification_time] }
  #     *instances* = {'server,device,path' -> instance_modification_time }
  # Notes:
  #   1. content_modification_time is the instance_modification_time of the first
  #      instances which was added to @contents_info
  class ContentData

    def initialize(other = nil)
      ObjectSpace.define_finalizer(self,
                                   self.class.method(:finalize).to_proc)
      if Params['enable_monitoring']
        Params['process_vars'].inc('obj add ContentData')
      end
      if other.nil?
        @contents_info = {}  # Checksum --> [size, paths-->time(instance), time(content)]
      else
        @contents_info = other.clone_contents_info
      end
    end

    def self.finalize(id)
      if Params['enable_monitoring']
        Params['process_vars'].inc('obj rem ContentData')
      end
    end

    # getting a cloned data base
    def clone_contents_info
      @contents_info.keys.inject({}) { |clone_contents_info, checksum|
        instances = @contents_info[checksum]
        size = instances[0]
        instances_db_cloned = instances[1].clone  # this shallow clone will work
        content_time = instances[2]
        clone_contents_info[checksum] = [size,
                              instances_db_cloned,
                              content_time]
        clone_contents_info
      }
    end

    # iterator over @contents_info data structure (not including instances)
    # block is provided with: checksum, size and content modification time
    def each_content(&block)
      @contents_info.keys.each { |checksum|
        content_val = @contents_info[checksum]
        # provide checksum, size and content modification time to the block
        block.call(checksum,content_val[0], content_val[2])
      }
    end

    # iterator over @contents_info data structure (including instances)
    # block is provided with: checksum, size, content modification time,
    #   instance modification time, server, device and file path
    def each_instance(&block)
      @contents_info.keys.each { |checksum|
        content_info = @contents_info[checksum]
        content_info[1].keys.each {|location|
          # provide checksum, size, content modification time,instance modification time,
          #   server, device and path to the block
          instance_modification_time = content_info[1][location]
          location_arr = location.split(',')
          block.call(checksum,content_info[0], content_info[2], instance_modification_time,
                     location_arr[0], location_arr[1], location_arr[2])
        }
      }
    end

    # iterator of instances over specific content
    # block is provided with: checksum, size, content modification time,
    #   instance modification time, server, device and file path
    def content_each_instance(checksum, &block)
      content_info = @contents_info[checksum]
      content_info[1].keys.each {|location|
        # provide checksum, size, content modification time,instance modification time,
        #   server, device and path to the block
        instance_modification_time = content_info[1][location]
        location_arr = location.split(',')
        block.call(checksum,content_info[0], content_info[2], instance_modification_time,
                   location_arr[0], location_arr[1], location_arr[2])
      }
    end

    def contents_size()
      @contents_info.size
    end

    def instances_size(checksum)
      content_info = @contents_info[checksum]
      return 0 if content_info.nil?
      content_info[1].size
    end

    def instance_mod_time(checksum, location)
      content_info = @contents_info[checksum]
      return nil if content_info.nil?
      instances = content_info[1]
      instance_time = instances[location]
    end

    def add_instance(checksum, size, server, device, path, modification_time)
      location = "%s,%s,%s" % [server, device, path]
      content_info = @contents_info[checksum]
      if content_info.nil?
        @contents_info[checksum] = [size,
                                    {location => modification_time},
                                    modification_time]
      elsif size != content_info[0]
        Log.warning 'File size different from content size while same checksum'
        Log.warning sprintf("instance location:'%s'\n", location)
        Log.warning sprintf("instance mod time:'%d'\n", modification_time)
      else
        #override file if needed
        instances = content_info[1]
        instances[location] = modification_time
      end
    end

    def empty?
      @contents_info.empty?
    end

    def content_exists(checksum)
      @contents_info.has_key?(checksum)
    end


    # TODO (genadyp) consider about using hash for optional defining of parameters
    def instance_exists(path, server, device, checksum=nil)
      location = "%s,%s,%s" % [server, device, path]
      if checksum.nil?
        @contents_info.values.any? { |content_db|
          content_db[1].has_key?(location)
        }
      else
        content_info = @contents_info[checksum]
        return false if content_info.nil?
        content_info[1].has_key?(location)
      end
    end


    # removes an instance from known content (faster then unknown content)
    # remove also the content, if content becomes empty
    def remove_instance(location, checksum=nil)
      if checksum.nil?
        @contents_info.keys.each { |checksum|
          instances =  @contents_info[checksum][1]
          instances.delete(location)
          @contents_info.delete(checksum) if instances.empty?
        }
      else
        content_info = @contents_info[checksum]
        unless content_info.nil?
          instances =  content_info[1]
          instances.delete(location)
          @contents_info.delete(checksum) if instances.empty?
        end
      end
    end

    def ==(other)
      return false if other.nil?
      return false if @contents_info.size != other.contents_size
      other.each_instance { |checksum, size, content_mod_time, instance_mod_time, server, device, path|
        local_content_info = @contents_info[checksum]
        return false if local_content_info.nil?
        return false if local_content_info[0] != size
        return false if local_content_info[2] != content_mod_time
        #check instances
        local_instances =  local_content_info[1]
        return false if other.instances_size(checksum) != local_instances.size
        location = "%s,%s,%s" % [server, device, path]
        local_instance_mod_time = local_instances[location]
        return false if local_instance_mod_time.nil?
        return false if local_instance_mod_time != instance_mod_time
      }
      true
    end

    def remove_content(checksum)
      @contents_info.delete(checksum)
    end

    def to_s
      return_str = ""
      contents_str = ""
      instances_str = ""
      instances_counter = 0
      each_content { |checksum, size, content_mod_time|
        contents_str << "%s,%d,%d\n" % [checksum, size, content_mod_time]
      }
      instances_counter = 0
      each_instance { |checksum, size, content_mod_time, instance_mod_time, server, device, path|
        instances_counter += 1
        instances_str <<  "%s,%d,%s,%s,%s,%d\n" % [checksum, size, server, device, path, instance_mod_time]
      }
      return_str << "%d\n" % [@contents_info.size]
      return_str << contents_str
      return_str << "%d\n" % [instances_counter]
      return_str << instances_str
      return_str
    end

    def to_a
      returned_arr = []
      @contents_info.keys.each { |checksum|
        instance = @contents_info[checksum]
        returned_arr.push(checksum)
        returned_arr.push(instance[0])
        instances_keys = instance[1].keys
        #returned_arr.push(instances_keys.size)
        instances_keys.each { |path|
          returned_arr.push(path)
          returned_arr.push(instance[1][path])
        }
        returned_arr.push(instance[2])
      }
      returned_arr
    end

    def from_a(arr)
      @contents_info = nil and return if arr.nil?
      @contents_info = {}
      tmp_ind = 0;
      while tmp_ind < arr.size
        checksum = arr[tmp_ind]
        content_size = arr[tmp_ind+1]
        next_elem = arr[tmp_ind+2]
        tmp_ind+=2
        instance_db = Hash.new
        while next_elem.instance_of?(String)
          instance_full_path = next_elem
          instance_time = arr[tmp_ind+1]
          next_elem = arr[tmp_ind+2]
          tmp_ind+=2
          instance_db[instance_full_path]=instance_time
        end
        content_time = next_elem
        @contents_info[checksum] = [content_size,instance_db, content_time]
        tmp_ind+=1
      end
    end

    def to_file(filename)
      content_data_dir = File.dirname(filename)
      FileUtils.makedirs(content_data_dir) unless File.directory?(content_data_dir)
      File.open(filename, 'w') {|f| f.write(to_s) }
    end

    # TODO validation that file indeed contains ContentData missing
    def from_file(filename)
      lines = IO.readlines(filename)
      #i = 0
      #number_of_contents = lines[i].to_i
      #i += 1
      #number_of_contents.times {
      #  parameters = lines[i].split(",")

      #  add_content(parameters[0],
      #              parameters[1].to_i,
      #              parameters[2].to_i)
      #  i += 1
      #}
      number_of_contents = lines[0].to_i
      i = 1 + number_of_contents
      number_of_instances = lines[i].to_i
      i += 1
      number_of_instances.times {
        if lines[i].nil?
          Log.debug1 "lines[i] if nil !!!, Backing filename: #{filename} to #{filename}.bad"
          FileUtils.cp(filename, "#{filename}.bad")
          Log.debug1 lines[i].join("\n")
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

        add_instance(parameters[0],
                     parameters[1].to_i,
                     parameters[2],
                     parameters[3],
                     parameters[4],
                     parameters[5].to_i)
        i += 1
      }
    end

    # for each content, all time fields (content and instances) are replaced with the
    # min time found, while going through all time fields.
    def unify_time()
      @contents_info.keys.each { |checksum|
        content_info = @contents_info[checksum]
        min_time_per_checksum = content_info[2]
        instances = content_info[1]
        instances.keys.each { |location|
          instance_mod_time = instances[location]
          if instance_mod_time < min_time_per_checksum
            min_time_per_checksum = instance_mod_time
          end
        }
        # update all instances with min time
        instances.keys.each { |location|
          instances[location] = min_time_per_checksum
        }
        # update content time with min time
        content_info[2] = min_time_per_checksum
      }
    end

    # Validates index against file system that all instances hold a correct data regarding files
    # that they represents.
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
        if param_exists.call(:failed)
          info = values[:details]
          unless info.nil?
            checksum = info[0]
            content_mtime = info[1]
            size = info[2]
            inst_mtime = info[3]
            server = info[4]
            device = info[5]
            file_path = info[6]
            params[:failed].add_instance(checksum, size, server, device, file_path, inst_mtime)
          end
        end
      end

      is_valid = true
      @contents_info.keys.each { |checksum|
        instances = @contents_info[checksum]
        content_size = instances[0]
        content_mtime = instances[2]
        instances[1].keys.each { |unique_path|
          instance_mtime = instances[1][unique_path]
          instance_info = [checksum, content_mtime, content_size, instance_mtime]
          instance_info.concat(unique_path.split(','))
          unless check_instance(instance_info)
            is_valid = false

            unless params.nil? || params.empty?
              process_params.call({:details => instance_info})
            end
          end
        }
      }
      is_valid
    end

    # instance_info is an array:
    #   [0] - checksum
    #   [1] - content time
    #   [2] - content size
    #   [3] - instance mtime
    #   [4] - server name
    #   [5] - device name
    #   [6] - file path
    def shallow_check(instance_info)
      path = instance_info[6]
      size = instance_info[2]
      instance_mtime = instance_info[3]
      is_valid = true

      if (File.exists?(path))
        if File.size(path) != size
          is_valid = false
          err_msg = "#{path} size #{File.size(path)} differs from indexed size #{size}"
          Log.warning err_msg
        end
        #if ContentData.format_time(File.mtime(path)) != instance.modification_time
        if File.mtime(path).to_i != instance_mtime
          is_valid = false
          err_msg = "#{path} modification time #{File.mtime(path).to_i} differs from " \
            + "indexed #{instance_mtime}"
          Log.warning err_msg
        end
      else
        is_valid = false
        err_msg = "Indexed file #{path} doesn't exist"
        Log.warning err_msg
      end
      is_valid
    end

    # instance_info is an array:
    #   [0] - checksum
    #   [1] - content time
    #   [2] - content size
    #   [3] - instance mtime
    #   [4] - server name
    #   [5] - device name
    #   [6] - file path
    def deep_check(instance_info)
      if shallow_check(instance_info)
        instance_checksum = instance_info[0]
        path = instance_info[6]
        current_checksum = FileIndexing::IndexAgent.get_checksum(path)
        if instance_checksum == current_checksum
          true
        else
          err_msg = "#{path} checksum #{current_checksum} differs from indexed #{instance_checksum}"
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

    private :shallow_check, :deep_check, :check_instance
  end

  # merges content data a and content data b to a new content data and returns it.
  def self.merge(a, b)
    return ContentData.new(a) if b.nil?
    return ContentData.new(b) if a.nil?
    c = ContentData.new(b)
    # Add A instances to content data c
    a.each_instance { |checksum, size, content_mod_time, instance_mod_time, server, device, path|
      c.add_instance(checksum, size, server, device, path, instance_mod_time)
    }
    c
  end

  def self.merge_override_b(a, b)
    return ContentData.new(a) if b.nil?
    return ContentData.new(b) if a.nil?
    # Add A instances to content data B
    a.each_instance { |checksum, size, content_mod_time, instance_mod_time, server, device, path|
      b.add_instance(checksum, size, server, device, path, instance_mod_time)
    }
    b
  end

  # B - A : Remove contents of A from B and return the new content data.
  # instances are ignored
  # e.g
  # A db:
  #    Content_1 ->
  #                   Instance_1
  #                   Instance_2
  #
  #    Content_2 ->
  #                   Instance_3
  #
  # B db:
  #    Content_1 ->
  #                   Instance_1
  #                   Instance_2
  #
  #    Content_2 ->
  #                   Instance_3
  #                   Instance_4
  #    Content_3 ->
  #                   Instance_5
  # B-A db:
  #   Content_3 ->
  #                   Instance_5
  def self.remove(a, b)
    return nil if b.nil?
    return ContentData.new(b) if a.nil?
    c = ContentData.new(b)  # create new cloned content C from B
    # remove contents of A from newly cloned content A
    a.each_content { |checksum, size, content_mod_time|
      c.remove_content(checksum)
    }
    c
  end

  # B - A : Remove instances of A content from B content data B and return the new content data.
  # If all instances are removed then the content record itself will be removed
  # e.g
  # A db:
  #    Content_1 ->
  #                   Instance_1
  #                   Instance_2
  #
  #    Content_2 ->
  #                   Instance_3
  #
  # B db:
  #    Content_1 ->
  #                   Instance_1
  #                   Instance_2
  #
  #    Content_2 ->
  #                   Instance_3
  #                   Instance_4
  # B-A db:
  #   Content_2 ->
  #                   Instance_4
  def self.remove_instances(a, b)
    return nil if b.nil?
    return ContentData.new(b) if a.nil?
    c = ContentData.new(b)  # create new cloned content C from B
    # remove contents of A from newly cloned content A
    a.each_instance { |checksum, size, content_mod_time, instance_mod_time, server, device, path|
      location = "%s,%s,%s" % [server, device, path]
      c.remove_instance(location, checksum)
    }
    c
  end

  def self.remove_directory(content_data, dir_to_remove)
    return nil if content_data.nil?
    result_content_data = ContentData.new()
    content_data.each_instance { |checksum, size, content_mod_time, instance_mod_time, server, device, path|
      location = "%s,%s,%s" % [server, device, path]
      if location.scan(dir_to_remove).size == 0
        # instance location is valid
        result_content_data.add_instance(checksum, size, server, device, path, instance_mod_time)
      end
    }
    result_content_data
  end

  # returns the common content in both a and b
  def self.intersect(a, b)
    return nil if a.nil?
    return nil if b.nil?
    b_minus_a = remove(a, b)
    b_minus_b_minus_a  = remove(b_minus_a, b)
  end
end

