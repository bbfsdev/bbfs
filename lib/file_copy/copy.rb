require 'net/ssh'
require 'net/sftp'

module BBFS
  module FileCopy

    # Creates ssh connection, assumes username and password
    # or without password but with ssh keys.
    def self.ssh_connect(username, password, server)
      username = (username and username.length > 0) ? username : ENV['USER']
      password = (password and password.length > 0) ? password : nil
      port = 22 # 22 is a standart SSH port
      raise "Undefined server" unless server
      if (username and password)
        Net::SSH.start(server, username,
                       :password => password,
                       :port => port)
      elsif (username)
        Net::SSH.start(server, username,
                       :port => port)
      else
        raise "Undefined username"
      end
    end

    # Simply copy map files using sftp server on dest_server.
    # Note: stfp.upload support parallel uploads - default is 2.
    def self.sftp_copy(username, password, server, files_map)
      ssh = FileCopy.ssh_connect(username, password, server)
      ssh.sftp.connect do |sftp|
        uploads = files_map.map { |from,to|
          # TODO(kolman): Create destination directory is not exists.
          p "Copying #{from} to #{to}"
          sftp.upload(from, to)
        }
        uploads.each { |u| u.wait }
        p "Done."
      end # sftp.connect
    end # def initialize

  end
end

