# Author: Slava Pasechnik (slavapas13@gmail.com)
# Run from bbfs> file_utils generate_files

require 'digest'
require 'fileutils'
require 'params'
require 'yaml'

require 'log'

module FileGenerator
  Params.path('target_path', '~/.bbfs/test_files', 'Represents the target path for files generation')
  Params.boolean('is_clear_target_path', false, 'Should files and directories already presented in target path be removed')
  Params.string('file_name_prefix', 'auto_generated_file_4_backup_server',
                'Represents the file name template for generated file')
  Params.string('dir_name_prefix', 'test_dir_4_backup_server',
                'Represents the directory name template for generated file')
  Params.integer('file_size_in_bytes', 500,
                 'Represents the required file size in bytes. Not relevant if random calculation is triggered')
  Params.integer('total_created_directories', -1,
                 'Represents the total created directories. Use any negative value or zero for Infinity.
                      Not relevant if random calculation is triggered')
  Params.integer('max_total_files', 0, 'Maximum number of files to generate, 0 for no limit.')
  Params.integer('total_files_in_dir', 10,
                 'Represents the total files in directory. Use any negative value or zero for Infinity')
  Params.float('sleep_time_in_seconds', 10, 'Represents the sleeping time for generation files')
  Params.float('upper_size_in_bytes', 500, 'Represents the upper limit file size in MB for random size calculation')
  Params.float('down_size_in_bytes', 50, 'Represents the Lower limit file size in MB for random size calculation')
  Params.integer('lower_limit_4_files_in_dir', 10,
                 'Represents the Lower limit for total files in directory for random calculation')
  Params.integer('upper_limit_4_files_in_dir', 20,
                 'Represents the Upper limit for total files in directory for random calculation')
  Params.boolean('is_tot_files_in_dir_random', true,
                 'Indicates that total files in a directory will be calculated randomly.')
  Params.boolean('is_use_random_size', true, 'Indicates that file size will be calculated randomly.')

  #Generates files with random content with random file size according to the given Params
  class FileGenerator
    attr_reader :one_bytes_string
    FILE_EXT = 'txt'

    #Gets one MB string
    def one_bytes_string
      @one_bytes_string ||= prepare_one_bytes_string
    end

    #Gets the some random string
    def get_small_rand_unique_str
      rand(36**8).to_s(36)
    end

    #Gets the unique name according to current time and random string
    def get_unique_name
      "#{Time.new.to_i}_#{get_small_rand_unique_str}"
    end

    #Gets the random letter
    def get_random_letter
      (rand(122-97) + 97).chr
    end

    #Gets the new directory name
    def get_new_directory_name
      "#{Params['dir_name_prefix']}_#{get_unique_name}"
    end

    #Gets the new file name
    def get_new_file_name
      "#{Params['file_name_prefix']}_#{get_unique_name}.#{FILE_EXT}"
    end

    #Gets the required file size im MB
    def get_file_bytes_size
      if Params['is_use_random_size']
        rand(Params['upper_size_in_bytes'] - Params['down_size_in_bytes']) +
            Params['down_size_in_bytes']
      else
        Params['file_size_in_bytes']
      end
    end

    #Generates one MB string with random content
    def prepare_one_bytes_string
      get_random_letter
    end

    #Determines whether to generate new directory or not
    def is_generate_dir(dir_counter, total_file_counter)
      if Params['max_total_files'] > 0 && total_file_counter > Params['max_total_files']
        return false
      end

      if Params['total_created_directories'] < 1 || #Any negative value or zero will be indication for Infinity
          dir_counter < Params['total_created_directories'] then
        return true
      else
        return false
      end
    end

    #Determines whether to generate new file or not
    def is_generate_file(file_counter, total_file_counter)
      if Params['max_total_files'] > 0 && total_file_counter > Params['max_total_files']
        return false
      end

      total_files_in_dir = Params['total_files_in_dir']
      if file_counter == 0 && Params['is_tot_files_in_dir_random']  then
        total_files_in_dir =
            rand(Params['upper_limit_4_files_in_dir'] -
                     Params['lower_limit_4_files_in_dir']) +
                Params['lower_limit_4_files_in_dir']
      end

      #When total_files_in_dir < 1 it will be treated as unlimited files creation in directory
      if total_files_in_dir < 1 ||
          file_counter < total_files_in_dir then
        return true
      else
        return false
      end
    end

    #Generates files with random content with random file size according to the given Params
    def run
      dir_counter = 0
      total_file_count = 0
      if Params['is_clear_target_path']
        target_path_all_regexp = File.expand_path(File.join(Params['target_path'], '*'))
        Dir[target_path_all_regexp].each {|file| FileUtils.rm_rf file}
      end
      while is_generate_dir dir_counter, total_file_count
        new_dir_name = File.expand_path(File.join Params['target_path'], get_new_directory_name)
        ::FileUtils.mkdir_p new_dir_name unless File.directory?(new_dir_name)
        dir_counter += 1
        file_counter = 0

        while is_generate_file file_counter, total_file_count
          new_file_name = get_new_file_name
          File.open(File.join(new_dir_name, new_file_name), "w") do |f|
            get_file_bytes_size.to_i.times { f.write(get_random_letter) }
          end
          file_counter += 1
          total_file_count += 1

          sleep Params['sleep_time_in_seconds'] if Params['sleep_time_in_seconds'] > 0
        end
      end
    end
  end
end # module FileGenerator





