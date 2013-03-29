# Author:
# originator: Kolman Vornovizky (kolmanv@gmail.com)
# update: Alexey Nemytov (alexeyn66@gmail.com) 31/07/2012
# This file is the consist utility functionality for BBFS
# Such as automatic file generation, symlink, etc.
# Run from bbfs> ruby -Ilib bin/file_utils --command=generate_files --log_write_to_console=true --log_debug_level=3

require 'content_data'
require 'file_indexing'
require 'file_utils'
require 'file_utils/file_generator/file_generator'

require 'log'
require 'params'

module FileUtils
  Params.string 'command', nil ,'path'
  Params.string 'ref_cd', nil ,'reference path'
  Params.string 'base_cd', nil ,'base path'
  Params.string 'dest', nil ,'destination path'
  Params.string 'dest_server', nil ,'server name'
  Params.string 'patterns', nil ,'patterns path'
  Params.string 'cd', nil ,'path'
  Params.string 'cd_a', nil ,'a path'
  Params.string 'cd_b', nil ,'b path'
  Params.string 'cd_out', nil ,'output path'
  Params.string 'cd_in', nil ,'input path'
  Params.string 'exist_cd', nil, 'exist_path'
  #Params.string 'config_file', 'path' ,'configuration file path'
  class FileUtils
    def FileUtils.run
      if Params['command'] == 'mksymlink'
        if Params['ref_cd'].nil?
          Log.error ("--ref_cd is not set")
          return
        end
        ref_cd = ContentData.new()
        ref_cd.from_file(Params['ref_cd'])
        if ref_cd.nil?
          Log.error ("Error loading content data ref_cd=%s" % Params['ref_cd'])
          return
        end

        if Params['base_cd'].nil?
          Log.error ("--base_cd is not set")
          return
        end
        base_cd = ContentData.new()
        base_cd.from_file(Params['base_cd'])
        if base_cd.nil?
          Log.error ("Error loading content data base_cd=%s" % Params['base_cd'])
          return
        end

        if Params['dest'].nil?
          Log.error ("--dest is not set")
          return
        end

        not_found = nil
        begin
          not_found = FileUtil.mksymlink(ref_cd, base_cd, Params['dest'])
        rescue NotImplementedError
          Log.error ("symlinks are unimplemented on this machine")
          return nil
        end
        return not_found
      elsif (Params['command'] == "merge" or
          Params['command'] == "intersect" or
          Params['command'] == "minus")

        if Params['cd_a'].nil?
          Log.error ("--cd_a is not set")
          return
        end
        cd_a = ContentData.new()
        cd_a.from_file(Params['cd_a'])
        if cd_a.nil?
          Log.error ("Error loading content data cd_a=%s" % Params['cd_a'])
          return
        end

        if Params['cd_b'].nil?
          Log.error ("--cd_b is not set")
          return
        end
        cd_b = ContentData.new()
        cd_b.from_file(Params['cd_b'])
        if cd_b.nil?
          Log.error ("Error loading content data cd_b=%s" % Params['cd_b'])
          return
        end

        if Params['cd_b'].nil?
          Log.error ("--dest is not set")
          return
        end

        output = FileUtil.contet_data_command(Params['command'], cd_a, cd_b, Params['dest'])

      elsif Params['command'] == 'unify_time'
        if  Params['cd'].nil?
          Log.error ("--cd is not set")
          return
        end
        cd = ContentData.new()
        cd.from_file(Params['cd'])
        if cd.nil?
          Log.error ("Error loading content data cd=%s" % Params['cd'])
          return
        end
        output = unify_time(cd)
        # indexer
      elsif Params['command'] == 'indexer'
        if Params['patterns'].nil?
          Log.error ("--patterns is not set")
          return
        end

        patterns = FileIndexing::IndexerPatterns.new
        Params['patterns'].split(':').each { |pattern|
          Log.info "Pattern: #{pattern}"
          patterns.add_pattern File.expand_path(pattern)
        }

        unless patterns.size > 0
          Log.error ("Error loading patterns=%s (empty file)" % Params['patterns'])
          return
        end

        exist_cd = nil
        if not Params['exist_cd'].nil?
          exist_cd = ContentData::ContentData.new()
          exist_cd.from_file(Params['exist_cd'])
          if exist_cd.nil?
            Log.error ("Error loading content data exist_cd=%s" % Params['exist_cd'])
            return
          end
        end
        indexer = FileIndexing::IndexAgent.new
        indexer.index(patterns, exist_cd)
        Log.info indexer.indexed_content.to_s
        # crawler
      elsif Params['command'] == 'crawler'
        if Params['conf_file'].nil?
          Log.error ("--conf_file is not set")
          return
        end
        if not File.exists?(Params['conf_file'])
          Log.error ("config file doesn't exist conf_file=%s" % Params['conf_file'])
          return
        end

        if Params['cd_out'].nil?
          time = Tme.now.utc
          Params['cd_out'] = "crawler.out.#{time.strftime('%Y/%m/%d_%H-%M-%S')}"
        end
        unless (Params['cd_in'].nil?)
          if not File.exists?(Params['conf_file'])
            Log.error ("input data file doesn't exist cd_in=%s" % Params['cd_in'])
            return
          end
        end

        conf = Configuration.new(Params['conf_file'])
        threads = Array.new
        conf.server_conf_vec.each do |server|
          threads.push(Thread.new { Crawler.new(server, Params['cd_out'], Params['cd_in']) })
        end

        threads.each { |a| a.join }
        join_servers_results(conf.server_conf_vec, Params['cd_out'])
      elsif Params['command'] == 'generate_files'
        fg = FileGenerator::FileGenerator.new()
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
      def self.unify_time(content_data)
        orig_content_data = ContentData::ContentData.new(content_data)
        content_data.unify_time
        content_data.each_instance { |checksum, size, content_mod_time, unified_inst_mod_time, server, device, path|
          location = "%s,%s,%s" % [server, device, path]
          orig_inst_mod_time = orig_content_data.instance_mod_time(checksum, location)
          file_mtime, file_size = File.open(path) { |f| [f.mtime, f.size] }
          Log.info "file:#{path} file_mtime:#{file_mtime}."
          Log.info "update mtime:#{unified_inst_mod_time}"
          Log.info "original instance mtime:#{orig_inst_mod_time}."
          Log.info "unify instance mtime:#{unified_inst_mod_time}."
          Log.info "Comparison: Real file = unified? #{file_mtime.to_i == unified_inst_mod_time}"
          if (file_mtime.to_i == orig_inst_mod_time) \
                and file_size == size \
                and (file_mtime.to_i != unified_inst_mod_time)
            Log.info ("Comparison results: File actual time is same as instance time before unification. Need to modify file time")
            File.utime(File.atime(path), unified_inst_mod_time, path)
            file_mtime = File.open(path) { |f| f.mtime }
            Log.info "new file mtime:#{file_mtime}."
            Log.info "new file mtime in seconds:#{file_mtime.to_i}."
          end
        }
        content_data
      end

      # Creates directory structure and symlinks with ref_cd structure to the base_cd files and dest as a root dir
      # Parameters: ref_cd [ContentData]
      #             base_cd [ContentData]
      #             dest [String]
      # Output: ContentData object consists of contents/instances from ref_cd that have no target in base_cd

      def self.mksymlink(ref_cd, base_cd, dest)
        # symlinks are not implemented in Windows
        raise NotImplementedError.new if (RUBY_PLATFORM =~ /mingw/ or RUBY_PLATFORM =~ /ms/ or RUBY_PLATFORM =~ /win/)

        not_found = {}
        not_found_cd = ContentData::ContentData.new
        warnings = []
        dest.chop! if (dest.end_with?("/") or dest.end_with?("\\"))

        ref_cd.each_instance { |checksum, size, content_mod_time, inst_mod_time, server, device, path|
          if base_cd.content_exists(checksum)
            symlink_path = dest + path
            ::FileUtils.mkdir_p(File.dirname(symlink_path)) unless (Dir.exists?(File.dirname(symlink_path)))
            File.symlink(path, symlink_path)
          else
            # add instance to not_found cd
            not_found_cd.add_instance(checksum, size, server, device, path, inst_mod_time)
            warnings << "Warning: base content does not contains:'%s'" % checksum
          end
        }
        Log.warning (warnings)
        not_found_cd
      end
  end

end

