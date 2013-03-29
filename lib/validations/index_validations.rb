require 'params'
require 'log'
require 'content_data'
require 'file_indexing/index_agent'

# TODO additional params?
# TODO are params names good enough?
module Validations
  class IndexValidations

    # TODO should it be renamed cause it can validate any indexes, not specially remote, one against another.

    # Validates remote index against local file system.
    # Remote index defined valid when every remote content has at least one valid local instance.
    #
    # There are two levels of validation, controlled by instance_check_level system parameter:
    # * shallow - quick, tests instance for file existence and attributes.
    # * deep - can take more time, in addition to shallow recalculates hash sum.
    # For more infoemation see <tt>ContentData</tt> documentation.
    # @param [ContentData] remote_index it's contents should be validate against local index
    # @param [ContentData] local_index contains local contents and instances used for validation
    # @param [Hash] params hash of parameters of validation, can be used to return additional data
    #
    #     Supported key/value combinations:
    #     * key is <tt>:failed</tt> value is <tt>ContentData</tt> used to return failed instances
    # @return [Boolean] true when every remote content has at least one valid local instance, false otherwise
    # @raise [ArgumentError] when instance_check_level is incorrect
    def IndexValidations.validate_remote_index(remote_index, local_index, params = nil)
      raise ArgumentError 'remote_index must be defined' if remote_index.nil?
      raise ArgumentError 'local index must be defined' if local_index.nil?

      # used to answer whether specific param was set
      param_exists = Proc.new do |param|
        !(params.nil? || params[param].nil?)
      end

      # used to process method parameters centrally
      # TODO consider more convenient form of parameters
      # TODO code duplication with ContentData::validate
      process_params = Proc.new do |checksum, content_mtime, size, instance_mtime, server, device, path|
        if param_exists.call(:failed)
          params[:failed].add_instance(checksum, size, server, device, path, instance_mtime)
        end
      end

      # result variable
      is_valid = true
      # contains contents absent or without valid instances on local system
      # and corresponding local instances
      failed = ContentData::ContentData.new
      # contains checksums of contains absent in local
      absent_checksums = Array.new

      # contains local instances corresponding to given remote index contents
      local_index_to_check = ContentData::ContentData.new

      # check whether remote contents exist locally
      remote_index.each_content do |checksum|
        unless local_index.content_exists checksum
          is_valid = false
          absent_checksums << checksum
        end
      end

      # add instances of contents that should be check, i.e. exist in local
      local_index.each_instance do |checksum, size, content_mtime, instance_mtime, server, device, path|
        if remote_index.content_exists checksum
          local_index_to_check.add_instance checksum, size, server, device, path, instance_mtime
        end
      end


      # validate against local file system
      is_valid = local_index_to_check.validate(:failed => failed) && is_valid

      # contains contents that have at least one valid local instance,
      # then also corresponding remote content defined valid
      contents_with_succeeded_instances = ContentData.remove_instances failed, local_index

      # write summary to log
      # TODO should be controlled from params?
      absent_checksums.each do |checksum|
          Log.warning "Content #{checksum} is absent in the local file system"
      end
      failed.each_content do |checksum|
        if !contents_with_succeeded_instances.content_exists checksum
          # if checked content have no valid local instances
          # then content defined invalid
          Log.warning "Content #{checksum} is invalid in the local file system"
        end
      end

      # if needed process output params
      unless params.nil? || params.empty?
        remote_index.each_instance do |checksum, size, content_mtime, instance_mtime, server, device, path|
          unless contents_with_succeeded_instances.content_exists checksum
            process_params.call checksum, content_mtime, size, instance_mtime, server, device, path
          end
        end
      end

      is_valid
    end

  end  # class IndexValidations
end  # module Validations
