@@upload = ARGV.size > 0 && ARGV[0] == 'upload'

def uninstall_gem(gem_name)
  command = "echo | gem uninstall #{gem_name}"
  p command
  system(command)
end

@@root_dir = File.dirname(File.expand_path(__FILE__))
def upload_gem(gem_name)
  Dir["#{@@root_dir}/#{gem_name}-*.gem"].each do |gem_file|
    command = "gem push #{File.basename(gem_file)}"
    p command
    system(command)
  end
end

def build_and_install_gem(gem_name)
  command = "gem build #{gem_name}.gemspec"
  p command
  system(command)
  upload_gem(gem_name) if @@upload
  command = "gem install #{gem_name}"
  p command
  system(command)
end

uninstall_gem('content_data')
uninstall_gem('file_monitoring')
uninstall_gem('file_indexing')
uninstall_gem('content_server')
uninstall_gem('params')
uninstall_gem('file_copy')
build_and_install_gem('file_copy')
build_and_install_gem('params')
build_and_install_gem('content_data')
build_and_install_gem('file_indexing')
build_and_install_gem('file_monitoring')
build_and_install_gem('content_server')
