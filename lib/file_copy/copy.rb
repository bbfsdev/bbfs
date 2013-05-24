require 'net/ssh'
require 'net/sftp'

require 'log'
require 'params'

module FileCopy

  # Creates ssh connection, assumes username and password
  # or without password but with ssh keys.
  def ssh_connect(username, password, server)
    username = (username and username.length > 0) ? username : ENV['USER']
    password = (password and password.length > 0) ? password : nil
    port = 22 # 22 is a standart SSH port
    raise "Undefined server" unless server
    Log.debug1 "Trying to connect(ssh): #{username}, #{password}, #{server}, #{port}."
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
  module_function :ssh_connect

  # Simply copy map files using sftp server on dest_server.
  # Note: stfp.upload support parallel uploads - default is 2.
  # TODO(kolman): packing files, all, not all, determine by part of file.
  def sftp_copy(username, password, server, files_map)
    ssh = FileCopy.ssh_connect(username, password, server)
    ssh.sftp.connect do |sftp|
      uploads = files_map.map { |from,to|
        remote_dir = File.dirname(to)
        sftp_mkdir_recursive(sftp, File.dirname(to))
        Log.debug1 "Copying #{from} to #{to}"
        sftp.upload(from, to)
      }
      uploads.each { |u| u.wait }
      Log.debug1 "Done."
    end # ssh.sftp.connect
  end # def initialize
  module_function :sftp_copy

  def sftp_mkdir_recursive(sftp, path)
    dir_stat = nil
    begin
      Log.debug1 "Stat remote dir: #{path}."
      dir_stat = sftp.stat!(path).directory?
      Log.debug1 "Stat result #{dir_stat}."
    rescue Net::SFTP::StatusException
    end
    if !dir_stat
      Log.debug1 "Directory does not exists: #{path}."
      sftp_mkdir_recursive sftp, File.dirname(path)
      Log.debug1 "Making dir #{path}."
      response = sftp.mkdir!(path)
      Log.debug1 "Making dir ok:#{response.ok?}."
    end
  end
  module_function :sftp_mkdir_recursive

end


