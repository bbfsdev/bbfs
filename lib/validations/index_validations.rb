require 'params'
require 'log'
require 'file_indexing/index_agent'

# TODO module description
# TODO additional params?
# TODO are params names good enough?

module BBFS
  module Validations
    Params.string('instance_check_level', 'shallow', 'Defines check level. Supported levels are: ' \
      'shallow - quick, tests instance for file existence and attributes. ' \
      'deep - can take more time, in addition to shallow recalculates hash sum.')

    class IndexValidations
      # TODO params support
      def IndexValidations.validate_index(index, params = {})
        raise ArgumentError 'index must be defined' if index.nil?

        isValid = true
        check_method = if Params['instance_check_level'] == 'deep'
                         'deep_check'
                       else
                         'shallow_check'
                       end
        instances = index.instances

        instances.each_value do |instance|
          send(check_method, instance) or isValid = false
        end

        isValid
      end

      def IndexValidations.shallow_check(instance)
        path = instance.full_path

        if (File.exists?(path))
          isValid = true
          if File.size(path) != instance.size
            Log.warning "#{path} size #{File.size(path)} differs from indexed size #{instance.size}"
            isValid = false
          end
          if File.mtime(path) != instance.modification_time
            Log.warning "#{path} modification time #{File.mtime(path)} differs from " \
            + "indexed size #{instance.modification_time}"
            isValid = false
          end
          isValid
        else
          Log.warning "Indexed file #{path} doesn't exist"
          false
        end
      end

      def IndexValidations.deep_check(instance)
        if (shallow_check(instance))
          path = instance.full_path
          current_checksum = FileIndexing::IndexAgent.get_checksum(path)
          if instance.checksum == current_checksum
            true
          else
            Log.warning "#{path} checksum #{current_checksum} differs from indexed #{instance.checksum}"
            false
          end
        else
          false
        end
      end
      private_class_method :shallow_check, :deep_check
    end  # class IndexValidations
  end  # module Validations
end  # module BBFS

