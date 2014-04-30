require 'content_server/server'
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
  #     *instances* = {[server,path] -> [instance_modification_time,index_time] }
  # Notes:
  #   1. content_modification_time is the instance_modification_time of the first
  #      instances which was added to @contents_info
  class ContentData

    CHUNK_SIZE = 5000

    # NOTE Cloning is time/memory expensive operation.
    # It is highly recomended to avoid it.
    def initialize(other = nil)
      if other.nil?
        @contents_info = {}  # Checksum --> [size, paths-->time(instance), time(content)]
        @instances_info = {}  # location --> checksum to optimize instances query
        @symlinks_info = {}  # [server,symlink path] -> target
      else
        @contents_info = other.clone_contents_info
        @instances_info = other.clone_instances_info  # location --> checksum to optimize instances query
        @symlinks_info =  other.clone_symlinks_info
      end
    end

    # Content Data unique identification
    # @return [ID] hash identification
    def unique_id
      [@contents_info.hash,@symlinks_info.hash]
    end

    def clone_instances_info
      clone_instances_info = {}
      instances_info_enum = @instances_info.each_key
      loop {
        location = instances_info_enum.next rescue break
        clone_instances_info[[location[0].clone, location[1].clone]] = @instances_info[location].clone
      }
      clone_instances_info
    end

    def clone_contents_info
      clone_contents_info = {}
      contents_info_enum = @contents_info.each_key
      loop {
        checksum = contents_info_enum.next rescue break
        instances = @contents_info[checksum]
        size = instances[0]
        content_time = instances[2]
        instances_db = instances[1]
        instances_db_cloned = {}
        instances_db_enum = instances_db.each_key
        loop {
          location =  instances_db_enum.next rescue break
          inst_mod_times = instances_db[location]
          # we use deep clone for location since map key is using shallow clone.
          # we dont want references between new content data
          # and orig object. This will help the GC dispose the orig object if not used any more.
          instances_db_cloned[[location[0].clone,location[1].clone]] = inst_mod_times.clone
        }
        clone_contents_info[checksum] = [size,
                              instances_db_cloned,
                              content_time]
      }
      clone_contents_info
    end

    def clone_symlinks_info
      symlinks_info_enum = @symlinks_info.each_key
      cloned_symlinks = {}
      loop {
        symlink_key = symlinks_info_enum.next rescue break
        cloned_symlinks[[symlink_key[0].clone, symlink_key[0].clone]] = @symlinks_info[symlink_key].clone
      }
      cloned_symlinks
    end

    # iterator over @contents_info data structure (not including instances)
    # block is provided with: checksum, size and content modification time
    def each_content(&block)
      contents_enum = @contents_info.each_key
      loop {
        checksum = contents_enum.next rescue break
        content_val = @contents_info[checksum]
        # provide checksum, size and content modification time to the block
        block.call(checksum,content_val[0], content_val[2])
      }
    end

    # iterator over @contents_info data structure (including instances)
    # block is provided with: checksum, size, content modification time,
    #   instance modification time, server and file path
    def each_instance(&block)
      contents_enum = @contents_info.each_key
      loop {
        checksum = contents_enum.next rescue break
        content_info = @contents_info[checksum]
        content_info_enum = content_info[1].each_key
        loop {
          location = content_info_enum.next rescue break
          # provide the block with: checksum, size, content modification time,instance modification time,
          #   server and path.
          inst_mod_time, inst_index_time = content_info[1][location]
          block.call(checksum,content_info[0], content_info[2], inst_mod_time,
                     location[0], location[1], inst_index_time)
        }
      }
    end

    # iterator of instances over specific content
    # block is provided with: checksum, size, content modification time,
    #   instance modification time, server and file path
    def content_each_instance(checksum, &block)
      content_info = @contents_info[checksum]
      instances_db_enum = content_info[1].each_key
      loop {
        location = instances_db_enum.next rescue break
        # provide the block with: checksum, size, content modification time,instance modification time,
        #   server and path.
        inst_mod_time,_ = content_info[1][location]
        block.call(checksum,content_info[0], content_info[2], inst_mod_time,
                   location[0], location[1])
      }
    end

    # iterator over @symlinks_info data structure
    # block is provided with: server, file path and target
    def each_symlink(&block)
      symlink_enum = @symlinks_info.each_key
      loop {
        symlink_key = symlink_enum.next rescue break
        symlink_target = @symlinks_info[symlink_key]
        block.call(symlink_key[0], symlink_key[1], symlink_target)
      }
    end

    def contents_size()
      @contents_info.length
    end

    def instances_size()
      @instances_info.length
    end

    def symlinks_size()
      @symlinks_info.length
    end

    def checksum_instances_size(checksum)
      content_info = @contents_info[checksum]
      return 0 if content_info.nil?
      content_info[1].length
    end

    def get_instance_mod_time(checksum, location)
      content_info = @contents_info[checksum]
      return nil if content_info.nil?
      instances = content_info[1]
      instance_time,_ = instances[location]
      instance_time
    end

    def add_instance(checksum, size, server, path, modification_time, index_time=Time.now.to_i)
      location = [server, path]

      # file was changed but remove_instance was not called
      if (@instances_info.include?(location) && @instances_info[location] != checksum)
        Log.warning("#{server}:#{path} file already exists with different checksum")
        remove_instance(server, path)
      end

      content_info = @contents_info[checksum]
      if content_info.nil?
        @contents_info[checksum] = [size,
                                    {location => [modification_time,index_time]},
                                    modification_time]
      else
        if size != content_info[0]
          Log.warning('File size different from content size while same checksum')
          Log.warning("instance location:server:'#{location[0]}'  path:'#{location[1]}'")
          Log.warning("instance mod time:'#{modification_time}'")
        end
        #override file if needed
        content_info[0] = size
        instances = content_info[1]
        instances[location] = [modification_time, index_time]
      end
      @instances_info[location] = checksum
    end

    def add_symlink(server, path, target)
      @symlinks_info[[server,path]] = target
    end

    def remove_symlink(server, path)
      @symlinks_info.delete([server,path])
    end

    def empty?
      @contents_info.empty? and @symlinks_info.empty?
    end

    def content_exists(checksum)
      @contents_info.has_key?(checksum)
    end

    def instance_exists(path, server)
      @instances_info.has_key?([server, path])
    end

    def symlink_exists(path, server)
      @symlinks_info.has_key?([server, path])
    end


    # removes an instance record both in @instances_info and @instances_info.
    # input params: server & path - are the instance unique key (called location)
    # removes also the content, if content becomes empty after removing the instance
    def remove_instance(server, path)
      location = [server, path]
      checksum = @instances_info[location]
      content_info = @contents_info[checksum]
      return nil if content_info.nil?
      instances = content_info[1]
      instances.delete(location)
      @contents_info.delete(checksum) if instances.empty?
      @instances_info.delete(location)
    end

    # removes all instances records which are located under input param: dir_to_remove.
    # found records are removed from @contents_info , @instances_info and @symlinks_info
    # input params: server & dir_to_remove - are used to check each instance unique key (called location)
    # removes also content\s, if a content\s become\s empty after removing instance\s
    def remove_directory(dir_to_remove, server)
      contents_enum = @contents_info.each_key
      loop {
        checksum = contents_enum.next rescue break
        instances =  @contents_info[checksum][1]
        instances_enum = instances.each_key
        loop {
          location = instances_enum.next rescue break
          if location[0] == server and location[1].scan(dir_to_remove).size > 0
            instances.delete(location)
            @instances_info.delete(location)
          end
        }
        @contents_info.delete(checksum) if instances.empty?
      }

      # handle symlinks
      symlinks_enum = @symlinks_info.each_key
      loop {
        symlink_key = symlinks_enum.next rescue break
        if symlink_key[0] == server and symlink_key[1].scan(dir_to_remove).size > 0
          @symlinks_info.delete(symlink_key)
        end
      }
    end

    def ==(other)
      return nil if other.nil?  # for this case: content_data == nil
      unique_id  == other.unique_id
    end

    def remove_content(checksum)
      content_info = @contents_info[checksum]
      if content_info
        content_info[1].each_key { |location|
          @instances_info.delete(location)
        }
        @contents_info.delete(checksum)
      end
    end

    def to_s
      return_str = ""
      contents_str = ""
      instances_str = ""
      each_content { |checksum, size, content_mod_time|
        contents_str << "%s,%d,%d\n" % [checksum, size, content_mod_time]
      }
      each_instance { |checksum, size, content_mod_time, instance_mod_time, server, path|
        instances_str <<  "%s,%d,%s,%s,%d\n" % [checksum, size, server, path, instance_mod_time]
      }
      return_str << "%d\n" % [@contents_info.length]
      return_str << contents_str
      return_str << "%d\n" % [@instances_info.length]
      return_str << instances_str
      return_str
    end

    # Write content data to file.
    # Write is using chunks (for both content chunks and instances chunks)
    # Chunk is used to maximize GC affect. The temporary memory of each chunk is GCed.
    # Without the chunks used in a dipper stack level, GC keeps the temporary objects as part of the stack context.
    def to_file(filename)
      content_data_dir = File.dirname(filename)
      FileUtils.makedirs(content_data_dir) unless File.directory?(content_data_dir)
      File.open(filename, 'w') { |file|
        # Write contents
        file.write("#{@contents_info.length}\n")
        contents_enum = @contents_info.each_key
        content_chunks = @contents_info.length / CHUNK_SIZE + 1
        chunks_counter = 0
        while chunks_counter < content_chunks
          to_file_contents_chunk(file,contents_enum, CHUNK_SIZE)
          GC.start
          chunks_counter += 1
        end

        # Write instances
        file.write("#{@instances_info.length}\n")
        contents_enum = @contents_info.each_key
        chunks_counter = 0
        while chunks_counter < content_chunks
          to_file_instances_chunk(file,contents_enum, CHUNK_SIZE)
          GC.start
          chunks_counter += 1
        end

        # Write symlinks
        symlinks_info_enum = @symlinks_info.each_key
        file.write("#{@symlinks_info.length}\n")
        loop {
          symlink_key = symlinks_info_enum.next rescue break
          file.write("#{symlink_key[0]}<#{symlink_key[1]}<#{@symlinks_info[symlink_key]}\n")
        }
      }
    end

    def to_file_contents_chunk(file, contents_enum, chunk_size)
      chunk_counter = 0
      while chunk_counter < chunk_size
        checksum = contents_enum.next rescue return
        content_info = @contents_info[checksum]
        file.write("#{checksum}<#{content_info[0]}<#{content_info[2]}\n")
        chunk_counter += 1
      end
    end

    def to_file_instances_chunk(file, contents_enum, chunk_size)
      chunk_counter = 0
      while chunk_counter < chunk_size
        checksum = contents_enum.next rescue return
        content_info = @contents_info[checksum]
        instances_db_enum = content_info[1].each_key
        loop {
          location = instances_db_enum.next rescue break
          # provide the block with: checksum, size, content modification time,instance modification time,
          #   server and path.
          instance_modification_time,instance_index_time = content_info[1][location]
          file.write("#{checksum}<#{content_info[0]}<#{location[0]}<#{location[1]}<" +
                     "#{instance_modification_time}<#{instance_index_time}\n")
        }
        chunk_counter += 1
        break if chunk_counter == chunk_size
      end
    end

    # TODO validation that file indeed contains ContentData missing
    # TODO class level method?
    # Loading db from file using chunks for better memory performance
    def from_file(filename)
      # read first line (number of contents)
      # calculate line number (number of instances)
      # read number of instances.
      # loop over instances lines (using chunks) and add instances

      unless File.exists? filename
        raise ArgumentError.new "No such a file #{filename}"
      end

      File.open(filename, 'r') { |file|
        # Get number of contents (at first line)
        number_of_contents = file.gets  # this gets the next line or return nil at EOF
        unless (number_of_contents and number_of_contents.match(/^[\d]+$/))  # check that line is of Number format
          raise("Parse error of content data file:#{filename}  line ##{$.}\n" +
                "number of contents should be a number. We got:#{number_of_contents}")
        end
        number_of_contents = number_of_contents.to_i
        # advance file lines over all contents. We need only the instances data to build the content data object
        # use chunks and GC
        contents_chunks = number_of_contents / CHUNK_SIZE
        contents_chunks += 1 if (contents_chunks * CHUNK_SIZE < number_of_contents)
        chunk_index = 0
        while chunk_index < contents_chunks
          chunk_size = CHUNK_SIZE
          if chunk_index + 1 == contents_chunks
            # update last chunk size
            chunk_size = number_of_contents - (chunk_index * CHUNK_SIZE)
          end
          return unless read_contents_chunk(filename, file, chunk_size)
          GC.start
          chunk_index += 1
        end

        # get number of instances
        number_of_instances = file.gets
        unless (number_of_instances and number_of_instances.match(/^[\d]+$/))  # check that line is of Number format
          raise("Parse error of content data file:#{filename}  line ##{$.}\n" +
                "number of instances should be a Number. We got:#{number_of_instances}")
        end
        number_of_instances = number_of_instances.to_i
        # read in instances chunks and GC
        instances_chunks = number_of_instances / CHUNK_SIZE
        instances_chunks += 1 if (instances_chunks * CHUNK_SIZE < number_of_instances)
        chunk_index = 0
        while chunk_index < instances_chunks
          chunk_size = CHUNK_SIZE
          if chunk_index + 1 == instances_chunks
            # update last chunk size
            chunk_size = number_of_instances - (chunk_index * CHUNK_SIZE)
          end
          return unless read_instances_chunk(filename, file, chunk_size)
          GC.start
          chunk_index += 1
        end

        # get number of symlinks
        number_of_symlinks = file.gets
        unless (number_of_symlinks and number_of_symlinks.match(/^[\d]+$/))  # check that line is of Number format
          raise("Parse error of content data file:#{filename}  line ##{$.}\n" +
                    "number of symlinks should be a Number. We got:#{number_of_symlinks}")
        end
        number_of_symlinks.to_i.times {
          symlinks_line = file.gets
          unless symlinks_line
            raise("Parse error of content data file:#{filename}  line ##{$.}\n" +
                   "Expected to read symlink line but reached EOF")
          end
          parameters = symlinks_line.split('<')
          if (3 != parameters.length)
            raise("Parse error of content data file:#{filename}  line ##{$.}\n" +
                  "Expected to read 3 fields ('<' separated) but got #{parameters.length}.\nLine:#{symlinks_line}")
          end

          @symlinks_info[[parameters[0],parameters[1]]] = parameters[2]
        }
      }
    end

    def read_contents_chunk(filename, file, chunk_size)
      chunk_index = 0
      while chunk_index < chunk_size
        unless file.gets
          raise("Parse error of content data file:#{filename}  line ##{$.}\n" +
                "Expecting content line but reached end of file")
        end
        chunk_index += 1
      end
      true
    end

    def read_instances_chunk(filename, file, chunk_size)
      chunk_index = 0
      while chunk_index < chunk_size
        instance_line = file.gets
        unless instance_line
          raise("Parse error of content data file:#{filename}  line ##{$.}\n" +
                "Expected to read Instance line but reached EOF")
        end

        parameters = instance_line.split('<')
        if (6 != parameters.length)
          raise("Parse error of content data file:#{filename}  line ##{$.}\n" +
                    "Expected to read 6 fields ('<' separated) but got #{parameters.length}.\nLine:#{instance_line}")
        end
        add_instance(parameters[0],        #checksum
                     parameters[1].to_i,   # size
                     parameters[2],        # server
                     parameters[3],        # path
                     parameters[4].to_i,   # mod time
                     parameters[5].to_i)   # index time
        chunk_index += 1
      end
      true
    end

    # for each content, all time fields (content and instances) are replaced with the
    # min time found, while going through all time fields.
    def unify_time()
      contents_enum = @contents_info.each_key
      loop {
        checksum = contents_enum.next rescue break
        content_info = @contents_info[checksum]
        min_time_per_checksum = content_info[2]
        instances = content_info[1]
        instances_enum = instances.each_key
        loop {
          location = instances_enum.next rescue break
          instance_mod_time = instances[location][0]
          if instance_mod_time < min_time_per_checksum
            min_time_per_checksum = instance_mod_time
          end
        }
        # update all instances with min time
        instances_enum = instances.each_key
        loop {
          location = instances_enum.next rescue break
          instances[location][0] = min_time_per_checksum
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
            file_path = info[5]
            params[:failed].add_instance(checksum, size, server, file_path, inst_mtime)
          end
        end
      end

      is_valid = true
      contents_enum = @contents_info.each_key
      loop {
        checksum = contents_enum.next rescue break
        instances = @contents_info[checksum]
        content_size = instances[0]
        content_mtime = instances[2]
        instances_enum = instances[1].each_key
        loop {
          unique_path = instances_enum.next rescue break
          instance_mtime = instances[1][unique_path][0]
          instance_info = [checksum, content_mtime, content_size, instance_mtime]
          instance_info.concat(unique_path)
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
    #   [5] - file path
    def shallow_check(instance_info)
      path = instance_info[5]
      size = instance_info[2]
      instance_mtime = instance_info[3]
      is_valid = true

      if (File.exists?(path))
        if File.size(path) != size
          is_valid = false
          err_msg = "#{path} size #{File.size(path)} differs from indexed size #{size}"
          Log.warning(err_msg)
        end
        #if ContentData.format_time(File.mtime(path)) != instance.modification_time
        if File.mtime(path).to_i != instance_mtime
          is_valid = false
          err_msg = "#{path} modification time #{File.mtime(path).to_i} differs from " \
            + "indexed #{instance_mtime}"
          Log.warning(err_msg)
        end
      else
        is_valid = false
        err_msg = "Indexed file #{path} doesn't exist"
        Log.warning(err_msg)
      end
      is_valid
    end

    # instance_info is an array:
    #   [0] - checksum
    #   [1] - content time
    #   [2] - content size
    #   [3] - instance mtime
    #   [4] - server name
    #   [5] - file path
    def deep_check(instance_info)
      if shallow_check(instance_info)
        instance_checksum = instance_info[0]
        path = instance_info[5]
        current_checksum = FileIndexing::IndexAgent.get_checksum(path)
        if instance_checksum == current_checksum
          true
        else
          err_msg = "#{path} checksum #{current_checksum} differs from indexed #{instance_checksum}"
          Log.warning(err_msg)
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
    a.each_instance { |checksum, size, content_mod_time, instance_mod_time, server, path|
      c.add_instance(checksum, size, server, path, instance_mod_time)
    }
    c
  end

  def self.merge_override_b(a, b)
    return ContentData.new(a) if b.nil?
    return ContentData.new(b) if a.nil?
    # Add A instances to content data B
    a.each_instance { |checksum, size, content_mod_time, instance_mod_time, server, path|
      b.add_instance(checksum, size, server, path, instance_mod_time)
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
    c = ContentData.new
    b.each_instance do |checksum, size, _, instance_mtime, server, path, index_time|
      unless (a.content_exists(checksum))
              c.add_instance(checksum,
                             size,
                             server,
                             path,
                             instance_mtime,
                             index_time)
      end
    end
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
    a.each_instance { |_, _, _, _, server, path|
      c.remove_instance(server, path)
    }
    c
  end

  def self.remove_directory(content_data, dir_to_remove, server_to_remove)
    return nil if content_data.nil?
    result_content_data = ContentData.new(content_data)  # clone from content_data
    result_content_data.remove_directory(dir_to_remove, server_to_remove)
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

