require './time_modification.rb'
require './index_agent'
require './content_data.rb'
require 'time.rb'
require 'test/unit'
require 'fileutils'

class TestTimeModification < Test::Unit::TestCase  
  RESOURCES_DIR = "./resources/time_modification_test" # directory where tested files will be placed
  MOD_TIME_CONTENTS = ContentData.parse_time("2001/02/01 02:23:59.000")  # minimal time that will be inserted in content
  MOD_TIME_INSTANCES = ContentData.parse_time("2002/02/01 02:23:59.000")  # minimal time that will be inserted in instance
  FILE_MIN_TIME = ContentData.parse_time("2000/02/01 02:23:59.000").utc  # minimal time for file  
  
  @input_db
  @mod_content_checksum = nil  # checksum of the content that was manually modified 
  @mod_instance_checksum = nil  # checksum of the instance that was manually modified 
  #@mod_file_checksum = nil # checksum of the file that was manually modified 
  
  def setup
    sizes = [500, 1000, 1500]
    numb_of_copies = 2
    test_file_name = "test_file"
    
    # prepare files for testing
    sizes.each do |size|
      file_name = "#{RESOURCES_DIR}/#{test_file_name}.#{size}"
      File.open(file_name, "w", 0777) do |file|
        content = Array.new
        size.times do |i|
          content.push(sprintf("%5d ", i))
        end
        file.puts(content)
      end
      #file.close # looks like it redundant
      numb_of_copies.times do |i|
        FileUtils.cp(file_name, "#{file_name}.#{i}")
      end
    end

    indexer = IndexAgent.new(`hostname`.chomp, 'hd1')
    patterns = Array.new
    patterns.push('hd1:+:' + RESOURCES_DIR + '\*')
    indexer.index(patterns)
    
    
    @input_db = ContentData.new  # ContentData that will contain manually modified entries
    
    # modifying content
    indexer.db.contents.each_value do |content|
      if (@mod_content_checksum == nil) 
        @input_db.add_content(Content.new(content.checksum, content.size, MOD_TIME_CONTENTS))
        @mod_content_checksum = content.checksum
      else
        @input_db.add_content(content)
      end
    end
    
    # modifying instance that doesn't belong to the instances of modified content 
    indexer.db.instances.each_value do |instance|
      if (instance.checksum != @mod_content_checksum and @mod_instance_checksum == nil)
        mod_instance = ContentInstance.new(instance.checksum, instance.size, instance.server_name, instance.device, instance.full_path, MOD_TIME_INSTANCES)
        @input_db.add_instance(mod_instance)
        @mod_instance_checksum = instance.checksum
        File.utime(File.atime(instance.full_path), MOD_TIME_INSTANCES, instance.full_path) # physically update modification time of the file 
      else
        @input_db.add_instance(instance)        
      end
    end
    
    # phisically modify file modification time
=begin
    indexer.db.instances.each_value do |instance|
      if (File.exists?(instance.full_path) and instance.checksum != @mod_content_checksum and instance.checksum != @mod_instance_checksum)
        File.utime(File.atime(instance.full_path), FILE_MIN_TIME, instance.full_path) # physically update modification time of the file 
        @mod_file_checksum = instance.checksum
        break
      end
    end
=end
    
    raise "one of the time modifications failed" unless @mod_content_checksum != nil and @mod_instance_checksum != nil #and @mod_file_checksum != nil
  end
  
  def test_modify
    mod_db = TimeModification.modify(@input_db) # modified ContentData. Test files also were modified.

    # checking that content was modified according to the instance with minimal time
    mod_db.contents.each_value do |content|
      if (content.checksum == @mod_instance_checksum)
        assert_equal(MOD_TIME_INSTANCES, content.first_appearance_time)
        break
      end
    end
    
    # checking that instances were modified according to the instance and content with minimal time
    mod_db.instances.each_value do |instance|
      if (instance.checksum == @mod_content_checksum) 
        assert_equal(MOD_TIME_CONTENTS, instance.modification_time)
      elsif (instance.checksum == @mod_instance_checksum) 
        assert_equal(MOD_TIME_INSTANCES, instance.modification_time)
=begin
      elsif (instance.checksum == @mod_file_checksum) 
        assert_equal(FILE_MIN_TIME, instance.modification_time.utc)
      end
=end
      end
    end
    # checking that files were actually modified
    instance = mod_db.instances.values[0]
    indexer = IndexAgent.new(instance.server_name, instance.device)
    patterns = Array.new
    patterns.push(instance.device + ":+:" + File.dirname(instance.full_path) + '/*')
    indexer.index(patterns, mod_db)
    assert_equal(indexer.db, mod_db)
  end
end
