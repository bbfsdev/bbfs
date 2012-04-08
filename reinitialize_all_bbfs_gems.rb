def uninstall_gem(gem_name)
  command = "echo | gem uninstall #{gem_name}"
  p command
  system(command)
end

def build_and_install_gem(gem_name)
  command = "gem build #{gem_name}.gemspec"
  p command
  system(command)
  command = "gem install #{gem_name}"
  p command
  system(command)
end

uninstall_gem('content_data')
uninstall_gem('file_monitoring')
uninstall_gem('content_server')
uninstall_gem('parameters')
uninstall_gem('file_copy')
build_and_install_gem('file_copy')
build_and_install_gem('parameters')
build_and_install_gem('content_data')
build_and_install_gem('file_monitoring')
build_and_install_gem('content_server')
