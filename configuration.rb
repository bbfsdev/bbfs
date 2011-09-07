# Crawling configuration. Net Topology and Physical Devices.
class Configuration
  attr_reader :server_conf_vec
  # initializes configuration from file
  def initialize(config_file)
    @server_conf_vec = parse_config(config_file)
  end

  def parse_config(config_file)
    server_conf_vec = Array.new
    lines = IO.readlines(config_file)
    i = 0
    while i < lines.length do
      line = lines[i]
      # Disobey comments starting with "#" or "//" or empty lines
      if ((line.lstrip).index("#") == 0 or
        (line.lstrip).index("//") == 0 or
        (line.strip.eql? ""))
        i += 1
        # Now, start reading the only interesting line
      elsif (line.strip.eql? "server")
        server_conf = ServerConf.new
        server_conf_vec.push(server_conf)
        lines_parsed = server_conf.parse(lines, i)
        # debug printf "server parsed %d\n", lines_parsed
        if lines_parsed <= 0
          printf("Error from line %d to line %d\n", i+1, (i-lines_parsed+1))
          return nil
        else
          i += lines_parsed
        end
      else
        printf("Bad configuration file at line:%d\n", i+1)
        printf("Line: %s\n", lines[i])
        return nil
      end
    end
    return server_conf_vec
  end

  def to_s
    ret = ""
    server_conf_vec.each { |server| ret << server.to_s("") }
    return ret
  end
end

class ServerConf
  attr_reader :username, :password, :port, :directories, :servers
  attr_accessor :name

  def initialize()
    @name = ""
    @username = ""
    @password = ""
    @port = ""
    @directories = Array.new
    @servers = Array.new
  end

  def parse(lines, i)
    ident = lines[i].index("server")+2
    parsed = 1
    while (check_ident_ok(lines, i, parsed, ident))
      if (lines[i+parsed].lstrip).index("#") == 0 or
        (lines[i+parsed].lstrip).index("//") == 0 or
        (lines[i+parsed].strip.eql? "")
        # do nothing
      elsif (lines[i+parsed].lstrip.match(/^name:/) != nil)
        @name = lines[i+parsed].strip.split(":")[1].strip
      elsif (lines[i+parsed].lstrip.match(/^username:/) != nil)
        @username = lines[i+parsed].strip.split(":")[1]
        if @username
          @username.strip!
        else
          @username = ""
        end
      elsif (lines[i+parsed].lstrip.match(/^password:/) != nil)
        @password = lines[i+parsed].strip.split(":")[1]
        if @password
          @password.strip!
        else
          @password = ""
        end
      elsif (lines[i+parsed].lstrip.match(/^port:/) != nil)
        @port = lines[i+parsed].strip.split(":")[1].strip
        if @port
          @port.to_i
        end
      elsif (lines[i+parsed].lstrip.match(/^directories:/) != nil)
        lines_parsed = parse_dirs(lines, i+parsed+1, ident+2, @directories)
        if (lines_parsed < 0)
          print "Error parsing directories\n"
          return -(parsed-lines_parsed)
        end
        #debug printf "line parsed dir: %d\n", lines_parsed
        parsed += lines_parsed
      elsif (lines[i+parsed].lstrip.match(/^server/) != nil)
        sc = ServerConf.new
        @servers.push(sc)
        lines_parsed = sc.parse(lines, i+parsed)
        if (lines_parsed < 0)
          print "Error parsing server\n"
          return -(parsed-lines_parsed)
        end
        # debug printf "line parsed ser: %d\n", lines_parsed
        parsed += lines_parsed-1
      else
        print "Error parsing, no legal directive found\n"
        return -parsed
      end
      parsed += 1
    end
    # debug printf "return parsed: %d\n", parsed
    return parsed
  end

  def parse_dirs(lines, i, ident, directories)
    parsed = 0
    while (check_ident_ok(lines, i, parsed, ident))
      if (lines[i+parsed].lstrip).index("#") == 0 or
        (lines[i+parsed].lstrip).index("//") == 0 or
        (lines[i+parsed].strip.eql? "")
        # do nothing
      else
        directories.push(lines[i+parsed].strip)
      end
      parsed += 1
    end
    return parsed
  end

  def check_ident_ok(lines, i, parsed, ident)
    #debug printf "ident: %d, %d, %d %s\n", i, parsed, ident, lines[i+parsed]
    return false unless
      lines[i+parsed] != nil and
      (number_of_leading_spaces(lines[i+parsed]) == ident or
      lines[i+parsed].strip.eql? "")
    return true
  end

  def number_of_leading_spaces(str)
    str.match(/^\s*/).to_s.length
  end

  def to_file(filename)
    File.open(filename, 'w') {|f| f.write(to_s("")) }
  end

  def to_s(prefix="")
    ret = ""
    ret << prefix << "server\n"
    ret << prefix << "  name:" << @name << "\n"
    ret << prefix << "  username:" << @username << "\n"
    ret << prefix << "  password:" << @password << "\n"
    ret << prefix << "  port:" << @port.to_s << "\n"
    ret << prefix << "  directories:\n"
    @directories.each { |dir| ret << "    " << prefix << dir << "\n" }
    @servers.each { |server| ret << server.to_s(prefix+"  ") }
    return ret
  end
end