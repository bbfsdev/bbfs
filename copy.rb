require './configuration.rb'
require './content_data.rb'
require './net_utils.rb'
require 'net/ssh'
require 'net/sftp'

class Copy
  def initialize(configuration, content_data, dest_server, dest_path)
    server_conf = configuration.find_server(dest_server)

    ssh = connect(server_conf)
    ssh.sftp.connect do |sftp|
      arr = []
      content_data.instances.values.each { |instance|
        if File.exist?(instance.full_path)
          arr << instance.full_path
        else
          p "File #{instance.full_path} does not exists localy."
        end
      }

      uploads = arr.map { |f|
        dest_base_filename = File.basename(f)
        file_exists = true
        while(file_exists) do
          file_exists = false
          sftp.dir.glob(dest_path, dest_base_filename) do |entry|
            dest_base_filename = dest_base_filename + "_"
            p "File exists at #{dest_path}/#{entry.name} remaning to #{dest_base_filename}"
            file_exists = true
          end
        end
        p "Copying #{f} to #{dest_server}:#{dest_path}/#{dest_base_filename}"
        sftp.upload(f, "%s/%s" % [dest_path, dest_base_filename])
      } # arr.map
      uploads.each { |u| u.wait }
      p "Done."
    end # sftp.connect
  end # def initialize
end # class Copy
