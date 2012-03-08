require './configuration.rb'
require 'net/ssh'

def connect(server)
  username = (server.username and server.username.length > 0) ? server.username : ENV['USER']
  password = (server.password and server.password.length > 0) ? server.password : nil
  port = (server.port) ? server.port : 22 # 22 is a standart SSH port
  if (username and password)
    Net::SSH.start(server.name, username,
                  :password => password,
                  :port => port)
  elsif (username)
    Net::SSH.start(server.name, username,
                  :port => port)
  else
    raise "Undefined username"
  end
end
