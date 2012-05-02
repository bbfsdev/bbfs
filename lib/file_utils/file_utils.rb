# This file is the basic file manipulation tool for the distributed system.
# All the basic commands should reside here.

require 'file_utils'

require 'content_data'
require 'file_indexing'
require 'params'

module BBFS
  module FileUtils

    class FileUtils
      def initialize(arguments)
        if arguments["command"] == "mksymlink"
          begin
            puts "--ref_cd is not set"
            return
          end unless not arguments["ref_cd"].nil?
          ref_cd = ContentData.new()
          ref_cd.from_file(arguments["ref_cd"])
          begin
            puts "Error loading content data ref_cd=%s" % arguments["ref_cd"]
            return
          end unless not ref_cd.nil?

          begin
            puts "--base_cd is not set"
            return
          end unless not arguments["base_cd"].nil?
          base_cd = ContentData.new()
          base_cd.from_file(arguments["base_cd"])
          begin
            puts "Error loading content data base_cd=%s" % arguments["base_cd"]
            return
          end unless not base_cd.nil?

          begin
            puts "--dest is not set"
            return
          end unless not arguments["dest"].nil?

          not_found = nil
          begin
            not_found = FileUtil.mksymlink(ref_cd, base_cd, arguments["dest"])
          rescue NotImplementedError
            puts "symlinks are unimplemented on this machine"
            return nil
          end
          return not_found
        elsif (arguments["command"] == "merge" or
            arguments["command"] == "intersect" or
            arguments["command"] == "minus")

          begin
            puts "--cd_a is not set"
            return
          end unless not arguments["cd_a"].nil?
          cd_a = ContentData.new()
          cd_a.from_file(arguments["cd_a"])
          begin
            puts "Error loading content data cd_a=%s" % arguments["cd_a"]
            return
          end unless not cd_a.nil?

          begin
            puts "--cd_b is not set"
            return
          end unless not arguments["cd_b"].nil?
          cd_b = ContentData.new()
          cd_b.from_file(arguments["cd_b"])
          begin
            puts "Error loading content data cd_b=%s" % arguments["cd_b"]
            return
          end unless not cd_b.nil?

          begin
            puts "--dest is not set"
            return
          end unless not arguments["dest"].nil?

          output = FileUtil.contet_data_command(arguments["command"], cd_a, cd_b, arguments["dest"])
          #elsif arguments["command"] == "copy"
          #  begin
          #    puts "--conf is not set"
          #    return
          #  end unless not arguments["conf"].nil?
          #  conf = Configuration.new(arguments["conf"])
          #
          #  begin
          #    puts "Error loading content data conf=%s" % arguments["conf"]
          #    return
          #  end unless not conf.nil?
          #
          #  begin
          #    puts "--cd is not set"
          #    return
          #  end unless not arguments["cd"].nil?
          #  cd = ContentData.new()
          #  cd.from_file(arguments["cd"])
          #  begin
          #    puts "Error loading content data cd=%s" % arguments["cd"]
          #    return
          #  end unless not cd.nil?
          #
          #  begin
          #    puts "--dest_server is not set"
          #    return
          #  end unless not arguments["dest_server"].nil?
          #  dest_server = arguments["dest_server"]
          #
          #  begin
          #    puts "--dest_path is not set"
          #    return
          #  end unless not arguments["dest_path"].nil?
          #  dest_path = arguments["dest_path"]
          #
          #  Copy.new(conf, cd, dest_server, dest_path)
        elsif arguments["command"] == "unify_time"
          begin
            puts "--cd is not set"
            return
          end unless not arguments["cd"].nil?
          cd = ContentData.new()
          cd.from_file(arguments["cd"])
          begin
            puts "Error loading content data cd=%s" % arguments["cd"]
            return
          end unless not cd.nil?
          output = unify_time(cd)
          # indexer
        elsif arguments["command"] == "indexer"
          begin
            puts "--patterns is not set"
            return
          end unless not arguments["patterns"].nil?

          patterns = BBFS::FileIndexing::IndexerPatterns.new
          arguments["patterns"].split(':').each { |pattern|
            p "Pattern: #{pattern}"
            patterns.add_pattern File.expand_path(pattern)
          }

          unless patterns.size > 0
            puts "Error loading patterns=%s (empty file)" % arguments["patterns"]
            return
          end

          exist_cd = nil
          if (arguments.has_key?"exist_cd")
            exist_cd = BBFS::ContentData::ContentData.new()
            exist_cd.from_file(arguments["exist_cd"])
            begin
              puts "Error loading content data exist_cd=%s" % arguments["exist_cd"]
              return
            end unless not exist_cd.nil?
          end
          indexer = BBFS::FileIndexing::IndexAgent.new
          indexer.index(patterns, exist_cd)
          puts indexer.indexed_content.to_s
          # crawler
        elsif arguments["command"] == "crawler"
          begin
            puts "--conf_file is not set"
            return
          end unless not arguments["conf_file"].nil?
          begin
            puts "config file doesn't exist conf_file=%s" % arguments["conf_file"]
            return
          end unless not File.exists?(arguments["conf_file"])

          if arguments["cd_out"].nil?
            time = Tme.now.utc
            arguments["cd_out"] = "crawler.out.#{time.strftime('%Y/%m/%d_%H-%M-%S')}"
          end
          unless (arguments["cd_in"].nil?)
            begin
              puts "input data file doesn't exist cd_in=%s" % arguments["cd_in"]
              return
            end unless not File.exists?(arguments["conf_file"])
          end

          conf = Configuration.new(arguments["conf_file"])
          threads = Array.new
          conf.server_conf_vec.each do |server|
            threads.push(Thread.new { Crawler.new(server, arguments["cd_out"], arguments["cd_in"]) })
          end

          threads.each { |a| a.join }
          join_servers_results(conf.server_conf_vec, arguments["cd_out"])
        end
      end

      def self.contet_data_command(command, cd_a, cd_b, dest_path)
        dest = nil
        if command == "merge"
          dest = ContentData.merge(cd_a, cd_b)
        elsif command == "intersect"
          dest = ContentData.intersect(cd_a, cd_b)
        elsif command == "minus"
          dest = ContentData.remove(cd_b, cd_a)
        end
        if dest
          dest.to_file(dest_path)
        end
      end

      # Unify modification/first_appearance time according to input DB
      # Input: ContentData
      # Output: ContentData with unified times
      #         Files modification time attribute physically updated
      # Assumption: Files in the input db are from this device.
      #             There is no check what device they are belong - only the check of server name.
      #             It is a user responsibility (meanwhile) to provide a correct input
      #             If file has a modification time attribute that doesn't present in the input db,
      #             then the assumption is that this file wasnt indexized and it will not be treated
      #             (e.i. we do nothing with it)
      def self.unify_time(db)
        mod_db = ContentData::ContentData.unify_time(db)
        mod_db.instances.each_value do |instance|
          next unless db.instances.has_key? instance.global_path
          if (File.exists?(instance.full_path))
            file_mtime, file_size = File.open(instance.full_path) { |f| [f.mtime, f.size] }
			p "file:#{instance.full_path} file_mtime:#{file_mtime}."
			p "update mtime:#{instance.modification_time}"
			p "original instance mtime:#{db.instances[instance.global_path].modification_time}."
			p "unify instance mtime:#{instance.modification_time}."
			p "unify instance mtime:#{instance.modification_time.to_i}."
			p "Comparison: #{file_mtime <=> instance.modification_time}"
            if (file_mtime == db.instances[instance.global_path].modification_time \
			    and file_size == instance.size \
                and (file_mtime <=> instance.modification_time) > 0)
			  p "Comparison success."
              File.utime File.atime(instance.full_path), instance.modification_time, instance.full_path
			  file_mtime = File.open(instance.full_path) { |f| f.mtime }
			  p "file mtime:#{file_mtime}."
			  p "file mtime:#{file_mtime.to_i}."
            end
          end
        end
        mod_db
      end

      # Creates directory structure and symlinks with ref_cd structure to the base_cd files and dest as a root dir
      # Parameters: ref_cd [ContentData]
      #             base_cd [ContentData]
      #             dest [String]
      # Output: ContentData object consists of contents/instances from ref_cd that have no target in base_cd
      def self.mksymlink(ref_cd, base_cd, dest)
        # symlinks are not implemented in Windows
        raise NotImplementedError.new if (RUBY_PLATFORM =~ /mingw/ or RUBY_PLATFORM =~ /ms/ or RUBY_PLATFORM =~ /win/)

        not_found = ContentData.new
        inverted_index = Hash.new
        base_cd.instances.values.each{ |instance|
          inverted_index[instance.checksum] = instance
        }

        warnings = Array.new

        dest.chop! if (dest.end_with?("/") or dest.end_with?("\\"))

        ref_cd.instances.values.each { |instance|
          if inverted_index.key? instance.checksum
            symlink_path = dest + instance.full_path
            FileUtils.mkdir_p(File.dirname(symlink_path)) unless (Dir.exists?(File.dirname(symlink_path)))
            File.symlink(inverted_index[instance.checksum].full_path, symlink_path)
          else
            not_found.add_content(ref_cd.contents[instance.checksum])
            not_found.add_instance(instance)
            warnings << "Warning: base content does not contains:'%s'" % instance.checksum
          end
        }
        puts warnings
        return not_found
      end
    end

    COMMANDS = Hash.new
    COMMANDS["mksymlink"] = "  mksymlink --ref_cd=<path> --base_cd=<path> --dest=<path>"
    COMMANDS["merge"] = "  merge --cd_a=<path> --cd_b=<path> --dest=<path>"
    COMMANDS["intersect"] = "  intersect --cd_a=<path> --cd_b=<path> --dest=<path>"
    COMMANDS["minus"] = "  minus --cd_a=<path> --cd_b=<path> --dest=<path>"
    COMMANDS["copy"] = "  copy --conf=<path> --cd=<path> --dest_server=<server name> --dest_path=<dir>"
    COMMANDS["unify_time"] = "  unify_time --cd=<path>"
    COMMANDS["indexer"] = "  indexer --patterns=<path> [--exist_cd=<path>]"
    COMMANDS["crawler"] = "  crawler --conf_file=<path> [--cd_out=<path>] [--cd_in=<path>]"

    def self.print_usage
      puts "Usage: fileutil <command> params..."
      puts "Commands:"
      COMMANDS.each { |name, description|
        puts description
      }
    end

    def self.run
      parsed_arguments = Hash.new
      begin
        print_usage
        return
      end unless Params::ReadArgs.read_arguments(ARGV, parsed_arguments, COMMANDS)
      FileUtils.new(parsed_arguments)
    end

  end
end
