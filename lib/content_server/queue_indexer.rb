require 'file_indexing/index_agent'
require 'file_indexing/indexer_patterns'
require 'log'

module ContentServer

  # Simple indexer, gets inputs events (files to index) and outputs
  # content data updates into output queue.
  class QueueIndexer

    def initialize(input_queue, output_queue, content_data_path)
      @input_queue = input_queue
      @output_queue = output_queue
      @content_data_path = content_data_path
    end

    def run
      server_content_data = ContentData::ContentData.new
      # Shallow check content data files.
        tmp_content_data = ContentData::ContentData.new
        tmp_content_data.from_file(@content_data_path) if File.exists?(@content_data_path)
        #Loop over instances from file
        #  If file time and size matches then add it to DB
        #  Else, monitor the path again
        tmp_content_data.private_db.keys.each { |checksum|
          instances_db = tmp_content_data.private_db[checksum][1]
          instance_size = tmp_content_data.private_db[checksum][0]
          instances_db.keys.each { |full_path|
            instance_mod_time = instances_db[full_path]
            full_path_arr = full_path.split(',')
            local_path = full_path_arr[2]
            if File.exists?(local_path)
              file_mtime, file_size = File.open(local_path) { |f| [f.mtime, f.size] }
              if ((file_size == instance_size) &&
                  (file_mtime.to_i == instance_mod_time))
                Log.info("file exists: #{local_path}")
                # add instance to local DB
                server_name = full_path_arr[0]
                device_name = full_path_arr[1]
                server_content_data.add_instance(checksum, instance_size, server_name,
                                                 device_name, local_path, instance_mod_time)
              else
                Log.info("changed: #{local_path}")
                # Add non existing and changed files to index queue.
                @input_queue.push([FileMonitoring::FileStatEnum::STABLE, local_path])
              end
            else  # File.exists?(local_path) TODO: need to change code
              Log.info("changed: #{local_path}")
              # Add non existing and changed files to index queue.
              @input_queue.push([FileMonitoring::FileStatEnum::STABLE, local_path])
            end
          }
        }

        # Start indexing on demand and write changes to queue
        thread = Thread.new do
          while true do
            Log.info 'Waiting on index input queue.'
            state, is_dir, path = @input_queue.pop
            Log.info "event: #{state}, #{is_dir}, #{path}."

            # index files and add to copy queue
            # delete directory with it's sub files
            # delete file
            if state == FileMonitoring::FileStatEnum::STABLE && !is_dir
              Log.info "Indexing content #{path}."
              index_agent = FileIndexing::IndexAgent.new
              indexer_patterns = FileIndexing::IndexerPatterns.new
              indexer_patterns.add_pattern(path)
              index_agent.index(indexer_patterns, server_content_data)
              Log.info("Failed files: #{index_agent.failed_files.to_a.join(',')}.") \
                  if !index_agent.failed_files.empty?
              Log.info("indexed content #{index_agent.indexed_content}.")
              # merge indexed content into server content data
              ContentData.merge_override_b(index_agent.indexed_content, server_content_data)
            elsif ((state == FileMonitoring::FileStatEnum::NON_EXISTING ||
              state == FileMonitoring::FileStatEnum::CHANGED) && !is_dir)
              # If file content changed, we should remove old instance.
              key = FileIndexing::IndexAgent.global_path(path)
              # Check if deleted file exists at content data.
              Log.info("Instance to remove: #{key}")
              server_content_data.private_db.keys.each { |checksum|
                instances = server_content_data.private_db[checksum]
                file_size = instances[0]
                instances[1].keys.each {|full_path|
                  if (full_path == key)
                    file_mod_time = instances[1][full_path]
                    full_path_arr = full_path.split(',')
                    file_name = full_path_arr[2]
                    if !shallow_check(file_name, file_size, file_mod_time)
                      server_name = full_path_arr[0]
                      device_name = full_path_arr[1]
                      content_data_to_remove = ContentData::ContentData.new
                      content_data_to_remove.add_instance(checksum, file_size, server_name,
                                                          device_name, file_name, file_mod_time)
                      server_content_data = ContentData.remove_instances(
                          content_data_to_remove, server_content_data)
                    else
                      Log.error("Code should not reach this point")
                    end
                    break
                  end
                }
              }
            elsif state == FileMonitoring::FileStatEnum::NON_EXISTING && is_dir
              Log.info("NonExisting/Changed: #{path}")
              # Remove directory but only when non-existing.
              Log.info("Directory to remove: #{path}")
              global_dir = FileIndexing::IndexAgent.global_path(path)
              server_content_data = ContentData.remove_directory(
              server_content_data, global_dir)
            else
              Log.info("This case should not be handled: #{state}, #{is_dir}, #{path}.")
            end
            # TODO(kolman): Don't write to file each change?
            Log.info "Writing server content data to #{@content_data_path}."
            server_content_data.to_file(@content_data_path)

            Log.info 'Adding server content data to queue.'
            @output_queue.push(ContentData::ContentData.new(server_content_data))
          end  # while true do
        end  # Thread.new do
        thread
      end  # def run

      # Check file existence, check it's size and modification date.
      # If something wrong reindex the file and update content data.
      def shallow_check(file_name, file_size, file_mod_time)
        shallow_instance = FileIndexing::IndexAgent.create_shallow_instance(file_name)
        return false unless shallow_instance
        return (shallow_instance[0] == file_size &&
                shallow_instance[2] == file_mod_time)
      end

  end  # class QueueIndexer
end

