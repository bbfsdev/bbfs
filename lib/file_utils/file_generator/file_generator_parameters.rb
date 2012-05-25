require 'yaml'

#Represents parameters for file generation
class FileGeneratorParameters
  attr_accessor :target_path, :file_name_template, :file_size_in_mb,
    :total_created_directories, :total_files_in_dir, :sleep_time_in_seconds,
    :is_use_random_size, :down_size_in_mb, :upper_size_in_mb,
    :is_tot_files_in_dir_random, :lower_limit_4_files_in_dir,
    :upper_limit_4_files_in_dir,
    :dir_name_template, :is_use_content_server_conf

  def initialize(yml_file_path = "file_generator_parameters.yml")
    read_config(yml_file_path)
    read_content_server_config if is_use_content_server_conf
  end

  def read_config(yml_file_path)
    begin
      config = YAML.load_file(yml_file_path)
      config["defaults"].each { |key, value| set_def_par_val(key, value) }
    rescue Exception
      #Do nothing
    end
  end

  def read_content_server_config
    yml_file_path = File.expand_path('~/.bbfs/etc/file_monitoring.yml')
    begin
      config = YAML.load_file(yml_file_path)
      config["paths"][0].each { |key, value| set_def_par_val(key, value) }
    rescue Exception
      #Do nothing
    end
  end

  def is_use_content_server_conf
    @is_use_content_server_conf ||= get_def_hc_par_val :is_use_content_server_conf
  end

  #Represents the Upper limit for total files in directory
  def upper_limit_4_files_in_dir
    if @upper_limit_4_files_in_dir == nil || @upper_limit_4_files_in_dir.to_i <= 0
      @upper_limit_4_files_in_dir = get_def_hc_par_val :upper_limit_4_files_in_dir
    end
    @upper_limit_4_files_in_dir.to_i
  end

  #Represents the Lower limit for total files in directory
  def lower_limit_4_files_in_dir
    if @lower_limit_4_files_in_dir == nil || @lower_limit_4_files_in_dir.to_i <= 0
      @lower_limit_4_files_in_dir = get_def_hc_par_val :lower_limit_4_files_in_dir
    end
    @lower_limit_4_files_in_dir.to_i
  end

  #Indicates that total files in a directory will be calculated randomly.
  def is_tot_files_in_dir_random
    @is_tot_files_in_dir_random ||= get_def_hc_par_val :is_tot_files_in_dir_random
  end

  #Represents the sleeping time for generation files
  #Use any negative value or zero non sleeping
  def  sleep_time_in_seconds
    if @sleep_time_in_seconds == nil
      @sleep_time_in_seconds = get_def_hc_par_val :sleep_time_in_seconds
    end
    @sleep_time_in_seconds.to_i
  end

  #Represents the total files in directory
  #Use any negative value or zero for Infinity
  def  total_files_in_dir
    if @total_files_in_dir == nil
      @total_files_in_dir = get_def_hc_par_val :total_files_in_dir
    end
    @total_files_in_dir.to_i
  end

  #Represents the total created directories
  #Use any negative value or zero for Infinity
  def  total_created_directories
    if @total_created_directories == nil
      @total_created_directories = get_def_hc_par_val :total_created_directories
    end
    @total_created_directories.to_i
  end

  #Indicates that file size will be calculated randomly.
  def is_use_random_size
    @is_use_random_size ||= get_def_hc_par_val :is_use_random_size
  end

  #Represents the upper limit file size in MB for random size calculation
  def upper_size_in_mb
    if @upper_size_in_mb == nil || @upper_size_in_mb.to_i <= 0
      @upper_size_in_mb = get_def_hc_par_val :upper_size_in_mb
    end
    @upper_size_in_mb.to_i
  end

  #Represents the Lower limit file size in MB for random size calculation
  def down_size_in_mb
    if @down_size_in_mb == nil || @down_size_in_mb.to_i <= 0
      @down_size_in_mb = get_def_hc_par_val :down_size_in_mb
    end
    @down_size_in_mb.to_i
  end

  #Represents the file size in MB
  def file_size_in_mb
    if @file_size_in_mb == nil ||
        @file_size_in_mb.to_s.length == 0 || @file_size_in_mb.to_i <= 0
      @file_size_in_mb = get_def_hc_par_val :file_size_in_mb
    end
    @file_size_in_mb.to_i
  end

  #Represents the directory name template for generated file
  def dir_name_template
    if @dir_name_template == nil || @dir_name_template.to_s.length == 0
      @dir_name_template = get_def_hc_par_val :dir_name_template
    end
    @dir_name_template
  end

  #Represents the file name template for generated file
  def file_name_template
    if @file_name_template == nil || @file_name_template.to_s.length == 0
      @file_name_template = get_def_hc_par_val :file_name_template
    end
    @file_name_template
  end

  #Represents the target path for files generation
  def target_path
    if @target_path == nil || @target_path.to_s.length == 0
      @target_path = get_def_hc_par_val :target_path
    end
    @target_path
  end

  #Returns the default hard coded parameter by the given parameter name symbol
  #In case if parameter is not defined returns string fgp_param_symbol
  def get_def_hc_par_val(param_symbol)
    retVal = case param_symbol
              when :is_use_random_size then true
              when :is_tot_files_in_dir_random then true
              when :upper_limit_4_files_in_dir then 20
              when :lower_limit_4_files_in_dir then 10
              when :down_size_in_mb then 100
              when :upper_size_in_mb then 500
              when :sleep_time_in_seconds then 10
              when :total_files_in_dir then -1
              when :total_created_directories then -1
              when :file_size_in_mb then 500
              when :dir_name_template then "test_dir_4_backup_server"
              when :file_name_template then "auto_generated_file_4_backup_server"
              when :target_path then "./test_files"
              when :is_use_content_server_conf then true
              else "fgp_#{param_symbol}"
    end

  end

  def set_def_par_val(key, value)
    case key
      when "is_tot_files_in_dir_random"
        self.is_tot_files_in_dir_random = value.to_s.downcase == "true"
      when "is_use_random_size"
        self.is_use_random_size = value.to_s.downcase == "true"
      when "upper_limit_4_files_in_dir"
        self.upper_limit_4_files_in_dir = value
      when "lower_limit_4_files_in_dir"
        self.lower_limit_4_files_in_dir = value
      when "down_size_in_mb"
        self.down_size_in_mb = value
      when "upper_size_in_mb"
        self.upper_size_in_mb = value
      when "sleep_time_in_seconds"
        self.sleep_time_in_seconds = value
      when "total_files_in_dir"
        self.total_files_in_dir = value
      when "total_created_directories"
        self.total_created_directories = value
      when "file_size_in_mb"
        self.file_size_in_mb = value
      when "dir_name_template"
        self.dir_name_template = value
      when "file_name_template"
        self.file_name_template = value
      when "target_path"
        self.target_path = value
      when "is_use_content_server_conf"
        self.is_use_content_server_conf = value
      when "path"
        self.target_path = value
    end
  end
end
