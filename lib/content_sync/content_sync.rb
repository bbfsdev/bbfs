require 'content_data/content_data.rb'

module ContentSync

  @Contents_list_for_sync = nil
  @Last_remote_file_stat = nil
  @Last_local_file_stat = nil

  @Last_remote_content = ContentData::ContentData.new
  @Last_local_content = ContentData::ContentData.new

  @CopiedContentCache = GoogleHashSparseRubyToRuby.new

  @digest = Digest::SHA1.new

  def ContentSync.index_file(file)
    @digest.reset
    File.open(file, 'rb') { |f|
      while buffer = f.read(16384) do
        @digest << buffer
      end
    }
    @digest.hexdigest.downcase
  end

  # Creates destination filename for backup server, input is base folder and sha1.
  # for example: folder:/mnt/hd1/bbbackup, sha1:d0be2dc421be4fcd0172e5afceea3970e2f3d940
  # dest filename: /mnt/hd1/bbbackup/d0/be/d0be2dc421be4fcd0172e5afceea3970e2f3d940
  def ContentSync.destination_filename(folder, checksum)
    File.join(folder, checksum[0,2], checksum[2,2], checksum)
  end

  # Sync remote and local contents. Copy 1 file at each call
  # Files to sync are the product of a diff between remote and local contents
  # if remote and local contents have not changed, copying next file in list
  # if no file left to sync, nothing is done
  def ContentSync.sync(remote_content, local_content, destination_dir)
    puts "start sync. remote_content:#{remote_content}  local_content:#{local_content}   destination_dir:#{destination_dir}"
    # 1. if files changed:
    #    Create new list @Contents_list_for_sync
    # 2. get next file in list
    #    If no file exist --> return (finished sync list)
    # 3. if file exists in cache:
    #    remove from @Contents_list_for_sync
    #    continue from step 2
    # 4. Copy file from remote machine to local machine
    # 5. Index (Calculate checksum) and compare with expected checksum
    # 6. Add to cache
    # 7. copy file to destination folder area (naming convention based on checksum)
    # 8. remove from @Contents_list_for_sync



    # 1. check if files changed:
    remote_stat = File.lstat(remote_content)
    local_stat = File.lstat(local_content)
    files_changed = false
    if not (remote_stat <=> @Last_remote_file_stat)
      @Last_remote_file_stat = remote_stat
      @Last_remote_content.clear
      @Last_remote_content.from_file(remote_content)
      files_changed = true
      puts "remote_content changed"
    end
    if not (local_stat <=> @Last_local_file_stat)
      @Last_local_file_stat = local_stat
      @Last_local_content.clear
      @Last_local_content.from_file(local_content)
      files_changed = true
      puts "local_content changed"
    end

    if files_changed
      #    Create new list @Contents_list_for_sync
      @Contents_list_for_sync = ContentData.remove(@Last_local_content, @Last_remote_content)
      puts "Contents_list_for_sync:#{@Contents_list_for_sync}"
    end

    # 2. loop over list and handle the first file which is not found in cache
    copied_file = false
    @Contents_list_for_sync.each_instance { |next_checksum, _, _, _, next_server, next_path|
      puts "next_checksum:#{next_checksum}  next_path:#{next_path}"
      # 3. if file exists in cache:
      #    remove from @Contents_list_for_sync
      #    continue from step 2
      if @CopiedContentCache[next_checksum]
        puts "next_path checksum is found in cache:#{next_checksum}. Removing from list"
        @Contents_list_for_sync.remove_content(next_checksum)
        next
      end

      # 4. Copy file from remote machine to local machine
      #`rsync -z -e ssh user@#{next_server}:#{next_path} ~/temp/tmp_copied_content`
      #::FileUtils.remove_file('~/temp/tmp_copied_content', force = false)
      copied_file = next_path + '_copied'
      ::FileUtils.copy_file(next_path, copied_file, preserve = false, dereference = true)

      # 5. Index (Calculate checksum) and compare with expected checksum
      copied_checksum = index_file(copied_file)

      if copied_checksum == next_checksum
        # 6. Add to cache
        @CopiedContentCache[next_checksum] = true
        # 7. mv file to destination folder area (naming convention based on checksum)
        dest = ContentSync.destination_filename(destination_dir, next_checksum)
        dest_dir = File.dirname(dest)
        if not File.exists?(dest_dir)
          ::FileUtils.mkdir_p(dest_dir)
        end
        ::FileUtils.mv(copied_file, dest, :force => true)
        # 8. remove from @Contents_list_for_sync
        @Contents_list_for_sync.remove_content(next_checksum)
        puts "Copied source:#{copied_file} to dest:#{dest}"
        copied_file=true
      else
        puts "ERROR: checksum is not the same: next_checksum:#{next_checksum}  copied_checksum:#{copied_checksum}"
      end
      break  # we are copying only one file
    }
    copied_file
  end

  def ContentSync.sync_all()
    puts "Sync_all started"
    # create local content data
    # recreate tmp_local_file_1 and tmp_local_file_2 files
    if not File.exists?(File.expand_path('~/temp'))
      ::FileUtils.mkdir_p(File.expand_path('~/temp'))
    end
    local_file_1 = File.expand_path('~/temp/tmp_local_file_1')
    local_file_2 = File.expand_path('~/temp/tmp_local_file_2')
    if File.exists?(local_file_1)
      ::FileUtils.remove_file(local_file_1, force = false)
    end
    writer = File.open(local_file_1, 'w')
    writer.puts(local_file_1)
    writer.close
    if File.exists?(local_file_2)
      ::FileUtils.remove_file(local_file_2, force = false)
    end
    writer = File.open(local_file_2, 'w')
    writer.puts(local_file_2)
    writer.close
    local_checksum_1 = ContentSync.index_file(local_file_1)
    local_checksum_2 = ContentSync.index_file(local_file_2)
    local_file_1_mtime = File.lstat(local_file_1).mtime.to_i
    local_file_1_size = File.lstat(local_file_1).size
    local_file_2_mtime = File.lstat(local_file_2).mtime.to_i
    local_file_2_size = File.lstat(local_file_2).size
    local_cd = ContentData::ContentData.new
    local_cd.add_instance(local_checksum_1, local_file_1_size, 'lcl_srv', local_file_1, local_file_1_mtime)
    local_cd.add_instance(local_checksum_2, local_file_2_size, 'lcl_srv', local_file_2, local_file_2_mtime)
    local_content_data_file = File.expand_path('~/temp/tmp_local_contents.cd')
    if File.exists?(local_content_data_file)
      ::FileUtils.remove_file(local_content_data_file, force = false)
    end
    local_cd.to_file(local_content_data_file)

    # create remote content data file with 2 files
    remote_file_1 = File.expand_path('~/temp/tmp_remote_file_1')
    remote_file_2 = File.expand_path('~/temp/tmp_remote_file_2')
    if File.exists?(remote_file_1)
      ::FileUtils.remove_file(remote_file_1, force = false)
    end
    writer = File.open(remote_file_1, 'w')
    writer.puts(remote_file_1)
    writer.close
    if File.exists?(remote_file_2)
      ::FileUtils.remove_file(remote_file_2, force = false)
    end
    writer = File.open(remote_file_2, 'w')
    writer.puts(remote_file_2)
    writer.close
    remote_checksum_1 = ContentSync.index_file(remote_file_1)
    remote_checksum_2 = ContentSync.index_file(remote_file_2)
    remote_file_1_mtime = File.lstat(remote_file_1).mtime.to_i
    remote_file_1_size = File.lstat(remote_file_1).size
    remote_file_2_mtime = File.lstat(remote_file_2).mtime.to_i
    remote_file_2_size = File.lstat(remote_file_2).size
    remote_cd = ContentData::ContentData.new
    remote_cd.add_instance(remote_checksum_1, remote_file_1_size, 'rmt_srv', remote_file_1, remote_file_1_mtime)
    remote_cd.add_instance(remote_checksum_2, remote_file_2_size, 'rmt_srv', remote_file_2, remote_file_2_mtime)
    remote_content_data_file = File.expand_path('~/temp/tmp_remote_contents.cd')
    if File.exists?(remote_content_data_file)
      ::FileUtils.remove_file(remote_content_data_file, force = false)
    end
    remote_cd.to_file(remote_content_data_file)


    loop {
      puts "Started one file copy"
      break if false == ContentSync.sync(remote_content_data_file, local_content_data_file, File.expand_path('~/temp'))
    }
  end


 ################# New design ##############################



end