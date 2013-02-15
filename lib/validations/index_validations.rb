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

      # result variable
      is_valid = true
      # contains contents absent or without valid instances on local system
      # and corresponding local instances
      failed = ContentData::ContentData.new
      # contains checksums of contains absent in local
      absent_checksums = Array.new

      # contains local instances corresponding to given remote index contents
      local_index_to_check = ContentData::ContentData.new

      # check whether remote contents exist locally and add them for further validations
      remote_index.contents.each_key do |checksum|
        if local_index.content_exists checksum
          local_index_to_check.add_content local_index.contents[checksum]
        else
          is_valid = false
          failed.add_content remote_index.contents[checksum]
          absent_checksums << checksum
        end
      end

      # add instances of contents that should be check
      local_index.instances.each_value do |instance|
        if remote_index.content_exists instance.checksum
          local_index_to_check.add_instance instance
        end
      end


      # validate against local file system
      is_valid = local_index_to_check.validate(:failed => failed) && is_valid

      # contains contents that have at least one valid local instance,
      # then also corresponding remote content defined valid
      contents_with_succeeded_instances = ContentData::ContentData.remove_instances failed, local_index

      # write summary to log
      # TODO should be controlled from params?
      failed.contents.each_key do |checksum|
        if absent_checksums.include? checksum
          Log.warning "Content #{checksum} is absent in the local file system"
        elsif !contents_with_succeeded_instances.content_exists checksum
          # if checked content have no valid local instances
          # then content defined invalid
          Log.warning "Content #{checksum} is invalid in the local file system"
        end
      end

      # if needed process output params
      unless params.nil? || params.empty?
        remote_index.instances.each_value do |instance|
          unless contents_with_succeeded_instances.content_exists instance.checksum
            process_params.call :content => remote_index.contents[instance.checksum], :instance => instance
          end
        end
      end

      is_valid
    end

  end  # class IndexValidations
end  # module Validations
