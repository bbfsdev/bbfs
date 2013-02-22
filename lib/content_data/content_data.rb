require 'log'
require 'params'
require 'zlib'

module ContentData
  Params.string('instance_check_level', 'shallow', 'Defines check level. Supported levels are: ' \
                'shallow - quick, tests instance for file existence and attributes. ' \
                'deep - can take more time, in addition to shallow recalculates hash sum.')

  # aka compress
  def self.deflate(string, level)
    z = Zlib::Deflate.new(level)
    dst = z.deflate(string, Zlib::FINISH)
    z.close
    dst
  end


  # aka decompress
  def self.inflate(string)
    zstream = Zlib::Inflate.new
    buf = zstream.inflate(string)
    zstream.finish
    zstream.close
    buf
  end

  # Unfortunately this class is used as mutable for now. So need to be carefull.
  # TODO(kolman): Make this class imutable, but add indexing structure to it.
  # TODO(kolman): Add wrapper to the class to enable dynamic content data
  # (with easy access indexes)
  class ContentData

    def initialize(copy = nil)
      if copy.nil?
        @db = Hash.new  # Checksum --> [size, paths-->time(instance), time(content)]
      else
        @db = copy.db  # db is cloned
      end
    end

    # getting a cloned data base
    def db
      clone_db = Hash.new
      @db.keys.each { |checksum|
        instances = @db[checksum]
        size = instances[0]
        instances_db_cloned = instances[1].clone  # this shallow clone will work
        content_time = instances[2]
        clone_db[checksum] = [size,
                              instances_db_cloned,
                              content_time]
      }
      clone_db
    end

    def private_db
      @db
    end

    def set_db(db)
      @db = db
    end

    def add_content(checksum, size, time)
      @db[checksum] = [size, Hash.new, time] unless @db.has_key?(checksum)
    end

    def add_instance(checksum, size, server_name, device, full_path, modification_time)
      full_path = "%s,%s,%s" % [server_name, device, full_path]
      # remove instance from all contents except from the given checksum
      # if no more instances then remove also the content data
      @db.keys.each { |db_checksum|
        unless db_checksum.eql?(checksum)
          instances_db =  @db[db_checksum][1]
          instances_db.delete(full_path)
          #@db.delete(db_checksum) if instances_db.empty?
        end
      }
      instances = @db[checksum]

      if instances.nil?
        #TODO new appraoch - use this method without add_content?
        #Log.warning sprintf("Adding instance while it's" +
        #                        " checksum %s does not exists.\n", checksum)
        #Log.warning sprintf("instance full path:'%s'\n", full_path)
        #Log.warning sprintf("instances time:'%d'\n", modification_time)
        @db[checksum] = [size,
                         {full_path => modification_time},
                         modification_time]
      elsif size != instances[0]
        Log.warning 'File size different from content size while same checksum'
        Log.warning sprintf("instance full path:'%s'\n", full_path)
        Log.warning sprintf("instance mod time:'%d'\n", modification_time)
      else
        #override file if needed
        instances[1][full_path] = modification_time
      end
    end

    def empty?
      @db.empty?
    end

    def content_exists(checksum)
      @db.has_key?(checksum)
    end

    def instance_exists(full_path)
      @db.values.each { |content_db|
        return true if content_db[1].has_key?(full_path)
      }
      false
    end

    def remove_instance(full_path)
      @db.keys.each { |checksum|
        instances_db =  @db[checksum][1]
        instances_db.delete(full_path)
        @db.delete(checksum) if instances_db.empty?
      }
    end

    def ==(other)
      return false if other == nil
      return false unless @db.size == other.private_db.size
      @db.hash == other.private_db.hash
    end

    def to_s
      return_str = ""
      contents_str = ""
      instances_str = ""
      instances_counter = 0

      # contents loop
      keys = @db.keys
      keys.each { |checksum|
        instances_per_content = @db[checksum]
        size = instances_per_content[0]
        content_mod_time = instances_per_content[2]
        instances_counter += instances_per_content[1].size
        contents_str << "%s,%d,%d\n" % [checksum, size, content_mod_time]
        # instances loop
        instances_per_content[1].keys.each { |global_path|
          instance_mod_time = instances_per_content[1][global_path]
          instances_str <<  "%s,%d,%s,%d\n" % [checksum, size, global_path, instance_mod_time]
        }
      }
      return_str << "%d\n" % [keys.size]
      return_str << contents_str
      return_str << "%d\n" % [instances_counter]
      return_str << instances_str
      return_str
    end

    def to_a
      returned_arr = []
      @db.keys.each { |checksum|
        instance = @db[checksum]
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
      if arr.nil?
        @db = nil
        return
      end
      @db = Hash.new
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
        @db[checksum] = [content_size,instance_db, content_time]
        tmp_ind+=1
      end
    end

    def to_file(filename)
      content_data_dir = File.dirname(filename)
      FileUtils.makedirs(content_data_dir) unless File.directory?(content_data_dir)
      File.open(filename, 'w') {|f| f.write(to_s) }
    end

    def from_file(filename)
      lines = IO.readlines(filename)
      i = 0
      number_of_contents = lines[i].to_i
      i += 1
      number_of_contents.times {
        parameters = lines[i].split(",")

        add_content(parameters[0],
                    parameters[1].to_i,
                    parameters[2].to_i)
        i += 1
      }

      number_of_instances = lines[i].to_i
      i += 1
      number_of_instances.times {
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
        # values is a Hash with keys: :content, :instance and value appropriate to key
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
            params[:failed].add_content(checksum, size, content_mtime)
            params[:failed].add_instance(checksum, size, server, device, file_path, inst_mtime)
          end
        end
      end

      is_valid = true
      @db.keys.each { |checksum|
        instances = @db[checksum]
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

    private :shallow_check, :deep_check, :check_instance, :get_query
  end
  # merges content data a and content data b to a new content data and returns it.
  def self.merge(a, b)
    if a.nil?
      if b.nil?
        #A is nil. B is nil.
        return nil
      else
        # A is nil. B is active.
        return ContentData.new(b)
      end
    else
      if b.nil?
        # A is active. B is nil.
        return ContentData.new(a)
      else
        # A is active. B is active. Start merge
        a_db = a.private_db  #db is not cloned
        b_db = b.db  #db is cloned
                             #loop over contents of A and add non existing contents of A in B to B
        a_db.keys.each { |a_checksum|
          a_instances = a_db[a_checksum]
          b_instances = b_db[a_checksum]
          if b_instances.nil?
            #B does not contain current A content.
            # Add A content to B db
            b_db[a_checksum] = [a_instances[0],
                                a_instances[1].clone,
                                a_instances[2]]
          else
            #checksum exists in both A and B.
            #Loop over instances and add non existing instances of A in B to B
            # TODO: do something with contents time stamps?
            a_instances[1].keys.each { |a_instance_global_path|
              a_time = a_instances[1][a_instance_global_path]
              b_time = b_instances[1][a_instance_global_path]
              if b_time.nil?
                # A instance does not exist in B.
                # Add instance to B
                b_instances[1][a_instance_global_path] = a_time
              end
            }
          end
        }
        return_cd = ContentData.new()
        return_cd.set_db(b_db)
        return return_cd
      end
    end
  end

  def self.merge_override_b(a, b)
    if a.nil?
      if b.nil?
        #A is nil. B is nil.
        return nil
      else
        # A is nil. B is active.
        return ContentData.new(b)
      end
    else
      if b.nil?
        # A is active. B is nil.
        return ContentData.new(a)
      else
        # A is active. B is active. Start merge
        a_db = a.private_db  #db is not cloned
        b_db = b.private_db  #db is not cloned
                             #loop over contents of A and add non existing contents of A in B to B
        a_db.keys.each { |a_checksum|
          a_instances = a_db[a_checksum]
          b_instances = b_db[a_checksum]
          if b_instances.nil?
            #B does not contain current A content.
            # Add A content to B db
            b_db[a_checksum] = [a_instances[0],
                                a_instances[1].clone,
                                a_instances[2]]
          else
            #checksum exists in both A and B.
            #Loop over instances and add non existing instances of A in B to B
            # TODO: do something with contents time stamps?
            a_instances[1].keys.each { |a_instance_global_path|
              a_time = a_instances[1][a_instance_global_path]
              b_time = b_instances[1][a_instance_global_path]
              if b_time.nil?
                # A instance does not exist in B.
                # Add instance to B
                b_instances[1][a_instance_global_path] = a_time
              end
            }
          end
        }
        return_cd = ContentData.new()
        return_cd.set_db(b_db)
        return return_cd
      end
    end
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
    if a.nil?
      if b.nil?
        #A is nil. B is nil.
        return nil
      else
        # A is nil. B is active. Return B.
        return ContentData.new(b)
      end
    else
      if b.nil?
        # A is active. B is nil.
        return nil
      else

        # A is active. B is active. Start merge
        a_db = a.private_db  #db is not cloned
        b_db = b.private_db  #db is not cloned
        c_db = Hash.new  # this is the result hash to be returned
                             #loop over contents of B and add non existing contents of B in A to C
        b_db.keys.each { |b_checksum|
          a_instances = a_db[b_checksum]
          if a_instances.nil?
            #B content is not found in A. Add to C
            b_instances = b_db[b_checksum]
            c_db[b_checksum] = [b_instances[0],
                                b_instances[1].clone,
                                b_instances[2]]
          end
        }
        return_cd = ContentData.new()
        return_cd.set_db(c_db)
        return return_cd

      end
    end
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
    if a.nil?
      if b.nil?
        #A is nil. B is nil.
        return nil
      else
        # A is nil. B is active.
        return ContentData.new(b)  #db is cloned
      end
    else
      if b.nil?
        # A is active. B is nil.
        return nil
      else
        # A is active. B is active. Start merge
        a_db = a.private_db  #db is cloned
        b_db = b.private_db  #db is cloned
        c_db = Hash.new  # this is the result hash to be returned
                             #loop over contents of B and add non existing contents of B in A to C
        b_db.keys.each { |b_checksum|
          a_instances = a_db[b_checksum]
          b_instances = b_db[b_checksum]
          if a_instances.nil?
            #A does not contain current B content.
            # Add B content to C db
            c_db[b_checksum] = [b_instances[0],
                                b_instances[1].clone,
                                b_instances[2]]

          else
            #checksum exists in both A and B.
            #Loop over instances and add non existing instances of B in A to C
            b_instances[1].keys.each { |b_instance_global_path|
              a_time = a_instances[1][b_instance_global_path]
              if a_time.nil?
                # B instance does not exist in A.
                # Add instance to C
                b_time = b_instances[1][b_instance_global_path]
                c_instances = c_db[b_checksum]
                if (c_instances.nil?)
                  c_db[b_checksum] = [b_instances[0], {b_instance_global_path => b_time}, b_instances[2]]
                else
                  c_instances[1][b_instance_global_path] = b_time
                end
              end
            }
          end
        }
        return_cd = ContentData.new()
        return_cd.set_db(c_db)
        return return_cd
      end
    end
  end

  def self.remove_directory(cd, global_dir_path)
    return nil if cd.nil?
    ret_cd = ContentData.new()
    return ret_cd if cd.private_db.nil?
    ret_db = Hash.new
    ret_cd.set_db(ret_db)
    return ret_cd if cd.private_db.size == 0
    #puts "remove_directory: checking dir:#{global_dir_path}"
    # return_cd is a shallow copy (no instances) of input db and is not empty
    # for each instances, check if global_dir_path is a directory in its full path
    # keep only instances with valid dirs
    cd.private_db.keys.each { |checksum|
      instances = cd.private_db[checksum]
      ret_instances = ret_db[checksum]
      #ret_instances[1] = Hash.new.clear  # Replace the shallow copy
      instances[1].keys.each { |full_path|
        #puts "  at instance:#{full_path}"
        if full_path.scan(global_dir_path).size == 0
          # insert only valid instance to the returned db
          if ret_instances.nil?
            ret_db[checksum] = [instances[0],
                                {full_path => instances[1][full_path]},
                                instances[2]]
            ret_instances = ret_db[checksum]
          else
            ret_instances[1][full_path] = instances[1][full_path]
          end
          #puts "    Added valid path:#{full_path}"
        end
      }
    }
    ret_cd
  end

  # returns the common content in both a and b
  def self.intersect(a, b)
    b_minus_a = remove(a, b)
    b_minus_b_minus_a  = remove(b_minus_a, b)
    return b_minus_b_minus_a
  end

  def self.unify_time(cd)
    return nil if cd.nil?
    ret_db = cd.db  # clone db
    ret_cd = ContentData.new()
    ret_cd.set_db(ret_db)
    return ret_cd if cd.private_db.nil?
    return ret_cd if cd.private_db.size == 0

    # ret_cd is a clone of input cd and is not empty
    # for each checksum, find the min time of both content and instances
    # then, update content and instances with this min time
    ret_db.keys.each { |checksum|
      instances = ret_db[checksum]
      min_time_per_checksum = instances[2]
      #puts "min_time_per_checksum:#{min_time_per_checksum}"
      instances[1].keys.each { |full_path|
        instance_time = instances[1][full_path]
        if instance_time < min_time_per_checksum
          min_time_per_checksum = instance_time
          #puts "updating min instance_time:#{instance_time}"
        end
      }
      #puts "min found:#{min_time_per_checksum}"
      # update all instances with min time
      instances[1].keys.each { |full_path|
        instances[1][full_path] = min_time_per_checksum
      }
      # update content time with min time
      instances[2] = min_time_per_checksum
    }
    ret_cd
  end
end