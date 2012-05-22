require 'digest'
require 'file_utils/file_generator/file_generator_parameters'
require 'fileutils'

#Generates files with random content with random file size
# according to given FileGeneratorParameters
class FileGenerator
  attr_accessor :file_gen_params
  attr_reader :one_mb_string

  def initialize (file_gen_params = FileGeneratorParameters.new())
    @file_gen_params = file_gen_params
  end

  def one_mb_string
    @one_mb_string || @one_mb_string = prepare_one_mb_string
  end

  def get_small_rand_unique_str
    rand(36**8).to_s(36)
  end

  def get_unique_name
    "#{Time.new.to_i}_#{get_small_rand_unique_str}"
  end

  def get_random_letter
    (rand(122-97) + 97).chr
  end

  def get_new_dir_name
    "#{@file_gen_params.dir_name_template}_#{get_unique_name}"
  end

  def get_new_file_name
    @file_ext = "txt"
    "#{@file_gen_params.file_name_template}_#{get_unique_name}.#{@file_ext}"
  end

  def get_file_mb_size
    if @file_gen_params.is_use_random_size
      rand(@file_gen_params.upper_size_in_mb - @file_gen_params.down_size_in_mb) +
          @file_gen_params.down_size_in_mb
    else
      @file_gen_params.file_size_in_mb
    end
  end

  def prepare_one_mb_string
    (get_random_letter) * (1024 * 1024)
  end

  def is_gen_dir(dir_counter)
    if @file_gen_params.total_created_directories < 1 ||
        dir_counter < @file_gen_params.total_created_directories then
      return true
    else
      return false
    end
  end

  def get_sleep_time_in_seconds
    @file_gen_params.sleep_time_in_seconds
  end

  def is_gen_file(file_counter)
    if file_counter == 0 && @file_gen_params.is_tot_files_in_dir_random  then
      @file_gen_params.total_files_in_dir =
          rand(@file_gen_params.upper_limit_4_files_in_dir -
                   @file_gen_params.lower_limit_4_files_in_dir) +
              @file_gen_params.lower_limit_4_files_in_dir
    end

    if @file_gen_params.total_files_in_dir < 1 ||
        file_counter < @file_gen_params.total_files_in_dir then
      return true
    else
      return false
    end
  end

  def run
    dir_counter = 0
    while is_gen_dir(dir_counter)
      new_dir_name = "#{@file_gen_params.target_path}/#{get_new_dir_name}"
      FileUtils.mkdir_p new_dir_name unless File.directory?(new_dir_name)
      dir_counter +=1
      file_counter = 0

      while is_gen_file(file_counter)
        new_file_name = get_new_file_name
        File.open("#{new_dir_name}/#{new_file_name}", "w") do |f|
          f.write (one_mb_string * get_file_mb_size)
          f.write new_file_name #To make file content unique
        end
        file_counter +=1

        sleep get_sleep_time_in_seconds() if @file_gen_params.sleep_time_in_seconds > 0
      end
    end
  end
end

