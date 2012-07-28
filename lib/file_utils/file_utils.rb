# This file is the basic file manipulation tool for the distributed system.
# All the basic commands should reside here.

require 'content_data'
require 'file_indexing'
require 'file_utils'
require 'file_utils/file_generator/file_generator'

require 'log'
require 'params'

module BBFS
  module FileUtils
    Params.string 'command', 'command' ,'path'
    Params.string 'ref_cd', 'path' ,'reference path'
    Params.string 'base_cd', 'path' ,'base path'
    Params.string 'dest', 'path' ,'destination path'
    Params.string 'dest_server', 'localhost' ,'server name'
    Params.string 'patterns', 'path' ,'patterns path'
    Params.string 'cd', 'path' ,'path'
    Params.string 'cd_a', 'path' ,'a path'
    Params.string 'cd_b', 'path' ,'b path'
    Params.string 'cd_out', 'path' ,'output path'
    Params.string 'cd_in', 'path' ,'input path'
    #Params.string 'config_file', 'path' ,'configuration file path'
    class FileUtils
      def FileUtils.run
        if Params['command'] == "mksymlink"
          begin
            Log.info "--ref_cd is not set"
            return
          end unless not Params['ref_cd'].nil?
          ref_cd = ContentData.new()
          ref_cd.from_file(Params['ref_cd'])
          begin
            Log.info "Error loading content data ref_cd=%s" % Params['ref_cd']
            return
          end unless not ref_cd.nil?

          begin
            Log.info "--base_cd is not set"
            return
          end unless not Params['base_cd'].nil?
          base_cd = ContentData.new()
          base_cd.from_file(Params['base_cd'])
          begin
            Log.info "Error loading content data base_cd=%s" % Params['base_cd']
            return
          end unless not base_cd.nil?

          begin
            Log.info "--dest is not set"
            return
          end unless not Params['dest'].nil?

          not_found = nil
          begin
            not_found = FileUtil.mksymlink(ref_cd, base_cd, Params['dest'])
          rescue NotImplementedError
            Log.info "symlinks are unimplemented on this machine"
            return nil
          end
          return not_found
        elsif (Params['command'] == "merge" or
            Params['command'] == "intersect" or
            Params['command'] == "minus")

          begin
            Log.info "--cd_a is not set"
            return
          end unless not Params['cd_a'].nil?
          cd_a = ContentData.new()
          cd_a.from_file(Params['cd_a'])
          begin
            Log.info "Error loading content data cd_a=%s" % Params['cd_a']
            return
          end unless not cd_a.nil?

          begin
            Log.info "--cd_b is not set"
            return
          end unless not Params['cd_b'].nil?
          cd_b = ContentData.new()
          cd_b.from_file(Params['cd_b'])
          begin
            Log.info "Error loading content data cd_b=%s" % Params['cd_b']
            return
          end unless not cd_b.nil?

          begin
            Log.info "--dest is not set"
            return
          end unless not Params['cd_b'].nil?

          output = FileUtil.contet_data_command(Params['command'], cd_a, cd_b, Params['dest'])
          #elsif arguments["command"] == "copy"
          #  begin
          #    Log.info "--conf is not set"
          #    return
          #  end unless not arguments["conf"].nil?
          #  conf = Configuration.new(arguments["conf"])
          #
          #  begin
          #    Log.info "Error loading content data conf=%s" % arguments["conf"]
          #    return
          #  end unless not conf.nil?
          #
          #  begin
          #    Log.info "--cd is not set"
          #    return
          #  end unless not arguments["cd"].nil?
          #  cd = ContentData.new()
          #  cd.from_file(arguments["cd"])
          #  begin
          #    Log.info "Error loading content data cd=%s" % arguments["cd"]
          #    return
          #  end unless not cd.nil?
          #
          #  begin
          #    Log.info "--dest_server is not set"
          #    return
          #  end unless not arguments["dest_server"].nil?
          #  dest_server = arguments["dest_server"]
          #
          #  begin
          #    Log.info "--dest_path is not set"
          #    return
          #  end unless not arguments["dest_path"].nil?
          #  dest_path = arguments["dest_path"]
          #
          #  Copy.new(conf, cd, dest_server, dest_path)
        elsif Params['command'] == "unify_time"
          begin
            Log.info "--cd is not set"
            return
          end unless not Params['cd'].nil?
          cd = ContentData.new()
          cd.from_file(Params['cd'])
          begin
            Log.info "Error loading content data cd=%s" % Params['cd']
            return
          end unless not cd.nil?
          output = unify_time(cd)
          # indexer
        elsif Params['command'] == "indexer"
          begin
            Log.info "--patterns is not set"
            return
          end unless not Params['patterns'].nil?

          patterns = BBFS::FileIndexing::IndexerPatterns.new
          Params['patterns'].split(':').each { |pattern|
            Log.info "Pattern: #{pattern}"
            patterns.add_pattern File.expand_path(pattern)
          }

          unless patterns.size > 0
            Log.info "Error loading patterns=%s (empty file)" % Params['patterns']
            return
          end

          exist_cd = nil
          if (Params.has_key?"exist_cd")
            exist_cd = BBFS::ContentData::ContentData.new()
            exist_cd.from_file(Params['exist_cd'])
            begin
              Log.info "Error loading content data exist_cd=%s" % Params['exist_cd']
              return
            end unless not exist_cd.nil?
          end
          indexer = BBFS::FileIndexing::IndexAgent.new
          indexer.index(patterns, exist_cd)
          Log.info indexer.indexed_content.to_s
          # crawler
        elsif Params['command'] == "crawler"
          begin
            Log.info "--conf_file is not set"
            return
          end unless not Params['conf_file'].nil?
          begin
            Log.info "config file doesn't exist conf_file=%s" % Params['conf_file']
            return
          end unless not File.exists?(Params['conf_file'])

          if Params['cd_out'].nil?
            time = Tme.now.utc
            Params['cd_out'] = "crawler.out.#{time.strftime('%Y/%m/%d_%H-%M-%S')}"
          end
          unless (Params['cd_in'].nil?)
            begin
              Log.info "input data file doesn't exist cd_in=%s" % Params['cd_in']
              return
            end unless not File.exists?(Params['conf_file'])
          end

          conf = Configuration.new(Params['conf_file'])
          threads = Array.new
          conf.server_conf_vec.each do |server|
            threads.push(Thread.new { Crawler.new(server, Params['cd_out'], Params['cd_in']) })
          end

          threads.each { |a| a.join }
          join_servers_results(conf.server_conf_vec, Params['cd_out'])
        elsif Params['command'] == "generate_files"
          fg = BBFS::FileGenerator::FileGenerator.new()
          fg.run()
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
            Log.info "file:#{instance.full_path} file_mtime:#{file_mtime}."
            Log.info "update mtime:#{instance.modification_time}"
            Log.info "original instance mtime:#{db.instances[instance.global_path].modification_time}."
            Log.info "unify instance mtime:#{instance.modification_time}."
            Log.info "unify instance mtime:#{instance.modification_time.to_i}."
            Log.info "Comparison: #{file_mtime <=> instance.modification_time}"
            if (file_mtime == db.instances[instance.global_path].modification_time \
                and file_size == instance.size \
                and (file_mtime <=> instance.modification_time) > 0)
              Log.info "Comparison success."
              File.utime File.atime(instance.full_path), instance.modification_time, instance.full_path
              file_mtime = File.open(instance.full_path) { |f| f.mtime }
              Log.info "file mtime:#{file_mtime}."
              Log.info "file mtime:#{file_mtime.to_i}."
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

        not_found = ContentData::ContentData.new
        inverted_index = Hash.new
        base_cd.instances.values.each{ |instance|
          inverted_index[instance.checksum] = instance
        }

        warnings = Array.new

        dest.chop! if (dest.end_with?("/") or dest.end_with?("\\"))

        ref_cd.instances.values.each { |instance|
          if inverted_index.key? instance.checksum
            symlink_path = dest + instance.full_path
            ::FileUtils.mkdir_p(File.dirname(symlink_path)) unless (Dir.exists?(File.dirname(symlink_path)))
            File.symlink(inverted_index[instance.checksum].full_path, symlink_path)
          else
            not_found.add_content(ref_cd.contents[instance.checksum])
            not_found.add_instance(instance)
            warnings << "Warning: base content does not contains:'%s'" % instance.checksum
          end
        }
        Log.info warnings
        return not_found
      end
    end

  end
end
