require 'file_indexing/index_agent'
require 'file_indexing/indexer_patterns'
require 'content_server/server'
require 'log'
require 'params'

module ContentServer

  # Simple indexer, gets inputs events (files to index) and outputs
  # content data updates into output queue.
  class QueueIndexer

    def initialize(input_queue)
      @input_queue = input_queue
    end

    # index files and add to copy queue
    # delete directory with it's sub files
    # delete file
    def run
      # Start indexing on demand and write changes to queue
      thread = Thread.new do
        while true do
          (state, is_dir, path, mtime, size) = @input_queue.pop
          $process_vars.set('monitor to index queue size', @input_queue.size)
          Log.debug1("index event: state:%s  dir?%s  path:%s  time:%s  size:%s ",
                     state, is_dir, path, mtime, size)
          if state == FileMonitoring::FileStatEnum::STABLE && !is_dir
            # Calculating checksum
            checksum = calc_SHA1(path)
            $process_vars.inc('indexed_files')
            $indexed_file_count += 1
            Log.debug1("Index checksum:%s Adding index to content data. put in queue for dynamic update.",
                       checksum)
            $local_content_data_lock.synchronize{
              $local_content_data.add_instance(checksum, size, Params['local_server_name'], path, mtime)
            }
          elsif ((state == FileMonitoring::FileStatEnum::NON_EXISTING ||
              state == FileMonitoring::FileStatEnum::CHANGED) && !is_dir)
            # Remove file but only when non-existing.
            Log.debug1("File to remove: %s", path)
            $local_content_data_lock.synchronize{
              $local_content_data.remove_instance(Params['local_server_name'], path)
            }
          elsif state == FileMonitoring::FileStatEnum::NON_EXISTING && is_dir
            # Remove directory but only when non-existing.
            Log.debug1("Directory to remove: %s", path)
            $local_content_data_lock.synchronize{
              $local_content_data.remove_directory(path, Params['local_server_name'])
            }
          else
            Log.debug1("This case should not be handled: %s, %s, %s", state, is_dir, path)
          end
        end  # while true do
      end  # Thread.new do
      thread
    end  # def run

    # Opens file and calculates SHA1 of it's content, returns SHA1
    def calc_SHA1(path)
      begin
        digest = Digest::SHA1.new
        File.open(path, 'rb') { |f|
          while buffer = f.read(65536) do
            digest << buffer
          end
        }
      rescue
       Log.warning("Monitored path'#{path}' does not exist. Probably file changed")
      end
      return digest.hexdigest.downcase
    end

    # Remove when not needed.
    # Check file existence, check it's size and modification date.
    # If something wrong reindex the file and update content data.
    #def shallow_check(file_name, file_size, file_mod_time)
    #  shallow_instance = FileIndexing::IndexAgent.create_shallow_instance(file_name)
    #  return false unless shallow_instance
    #  return (shallow_instance[0] == file_size &&
    #      shallow_instance[2] == file_mod_time)
    #end

  end  # class QueueIndexer
end

