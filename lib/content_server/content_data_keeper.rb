require 'date'
require 'singleton'
require 'params'
require 'content_data'

module ContentServer

  # NOTEs
  # * "full" and "base" notations used in method/variable names
  #    have the same meaning but "full" is from user perspective,
  #    and "base" from keeper perspective.
  # * When there was a choice between time performance and
  #   memory consuming, then memory economy was preferred.

  # A singleton used to keep and reign content data diffs and snapshots.
  class ContentDataKeeper
    include Singleton

    # Params
    Params.path('local_content_data_path', '', 'ContentData file path.')

    # Attributes
    attr_reader :latest_timestamp

    def initialize
      exist_diff_files = diff_files
      if exist_diff_files.nil? || exist_diff_files.empty?
        # No diff files were still saved
        # For the consistancy of diff search
        # we add an empty starting point - an empty full diff file,
        # so we always have a latest diff/full content data file,
        add(ContentData::ContentData.new, true)
      else
        @latest_timestamp =
          exist_diff_files.inject(exist_diff_files.first.till) do |latest, f|
            latest = f.till if f.later_than?(latest)
            latest
          end
        @latest_base_file =
          exist_diff_files.inject(nil) do |latest,f|
            if (f.type == ContentDataDiffFile::FULL_TYPE &&
                (latest.nil? || latest.earlier_than?(f.till)))
              latest = f
            end
            latest
          end
      end
    end

    # Store content data as a part of content data keeping service.
    # If type is full flush then content data is saved as it.
    # Otherwise incremental diff of comparison with the latest saved file
    # is calculated. Content data objects containing data regarding added files and
    # removed files is stored in a separate files. If there is no added or/and
    # removed files, then appropreate diff files are not created.
    def add(content_data, is_full_flush)
      if (is_full_flush)
        filename = save(content_data, ContentDataDiffFile::FULL_TYPE)
        @latest_base_file = ContentDataDiffFile.new filename
        @latest_timestamp = @latest_base_file.till
      else
        diff_from_latest = diff(@latest_timestamp)
        added_content_data = diff_from_latest[ContentDataDiffFile::ADDED_TYPE]
        removed_content_data = diff_from_latest[ContentDataDiffFile::REMOVED_TYPE]

        from = @latest_timestamp
        till = ContentDataDiffFile.current_timestamp

        # TODO
        unless added_content_data.empty?
          filename = save(added_content_data,
                          ContentDataDiffFile::ADDED_TYPE,
                          from,
                          till)
          diff_file = ContentDataDiffFile.new filename
          @latest_timestamp = diff_file.till
        end
        unless removed_content_data.empty?
          save(removed_content_data, ContentDataDiffFile::REMOVED_TYPE)
        end
      end
    end

    def save(content_data, type, from, till)
      filename = ContentDataDiffFile.compose_filename(type, from, till)
      path = File.join(Params['local_content_data_path'], filename)
      content_data.to_file(path)
    end

    def get(till = ContentDataDiffFile.current_timestamp)
      # looking for the latest full file that is earlier than till argument
      base = diff_files.inject(latest_base_file) do |cur_base, f|
        if (f.type == ContentDataDiffFile::FULL_TYPE &&
            f.earlier_than?(till) && f.later_than?(cur_base))
          cur_base = f
        end
        cur_base
      end
      base_cd = ContentData.new.from_file(base.filename)

      # applying diff files between base timestamp and till argument
      diff_from_base = diff(base.till, till)
      added_content_data = diff_from_base[ContentDataDiffFile::ADDED_TYPE]
      removed_content_data = diff_from_base[ContentDataDiffFile::REMOVED_TYPE]

      result = ContentData.merge(added_content_data, base_cd)
      ContentData.remove_instances(removed_content_data, result)
    end

    def diff(from, till = ContentDataDiffFile.current_timestamp)
      diff_files_in_range = diff_files.select do |df|
        # full type files actually are snapshots and not a diff files
        df.type != ContentDataDiffFile::FULL_TYPE &&
          df.later_than?(from) &&
          (df.earlier_than?(till) || df.same_time_as?(till))
      end

      added_content_data = ContentData::ContentData.new
      removed_content_data = ContentData::ContentData.new
      diff_files_in_range.each do |df|
        cd = ContentData::ContentData.new.from_file(df)
        if df.type == ContentDataDiffFile::ADDED_TYPE
          ContentData.merge_override_b(cd, added_content_data)
        elsif df.type == ContentDataDiffFile::REMOVED_TYPE
          ContentData.merge_override_b(cd, removed_content_data)
        end
      end

      {ContentDataDiffFile::REMOVED_TYPE => removed_content_data,
        ContentDataDiffFile::ADDED_TYPE => added_content_data}
    end

    def diff_files
      # Example: "/path/to/diff_files/*.{full,added,removed}"
      pattern = "#{Params[local_content_data_path]}#{File::SEPARATOR}*.{\
                 #{ContentDataDiffFile::FULL_TYPE},#{ContentDataDiffFile::ADDED_TYPE},\
                 #{ContentDataDiffFile::REMOVED_TYPE}}"
      Dir.glob(pattern).each do |f|
        ContentDataDiffFile.new(f)
      end
    end

    # NOTE added/removed files do intersect
    # thissuggestion is used in timestamps comparioson.
    class ContentDataDiffFile

      # Constants
      # %Y%m%dT%H%M => 20071119T0837  Calendar date and local time (basic)
      # Corresponds with ISO 8601 => can be parsed by Ryby date/time libraries
      TIME_FORMAT = '%Y%m%dT%H%M'
      # Time searching pattern
      # year is 4 digits
      # month is 2 digits
      # day is 2 digits
      # hour is 2 digits
      # seconds are 2 digits
      TIME_PATTERN = '\d{8}T%d{4}'
      TIMESTAMPS_SEPARATOR = '-'
      FULL_TYPE = 'full'
      ADDED_TYPE = 'added'
      REMOVED_TYPE = 'removed'

      attr_reader :from, :till, :type, :filename

      def initialize(filename)
        parse(filename)
      end

      def self.current_timestamp
        DateTime.now.strftime(TIME_FORMAT)
      end

      def self.compose_filename(type, from, till = self.current_timestamp)
        case type
        when FULL_TYPE
          till + FULL_TYPE
        when ADDED_TYPE
          from + TIMESTAMPS_SEPARATOR + till + ADDED_TYPE
        when REMOVED_TYPE
          from + TIMESTAMPS_SEPARATOR + till + REMOVED_TYPE
        else
          raise ArgumentError, "Usupportd argument: #{type}"
        end
      end

      # @note must be synchronized with compose_filename method
      def parse(diff_filename)
        extension = File.extname(diff_filename)
        if extension.nil?
          err_msg =  "Not a diff file: #{diff_filename}, should have a supported extension. "
          raise ArgumentError, err_msg
        end

        type = extension.delete('.')
        basename = File.basename(diff_filename, extension)
        timestamps = basename.scan(/#{TIME_PATTERN}/)

        case type
        when FULL_TYPE
          if timestamps.size == 1
            @till = timestamps[0]
            @type = type
            #return { :till => timestamps[0], :type => type }
          else
            err_msg =  "Not a diff file, full data filename must have one timestamp: \
                         #{diff_filename}"
            raise ArgumentError, err_msg
          end
        when ADDED_TYPE, REMOVED_TYPE
          if timestamps.size == 2
            @from = timestamps[0]
            @till = timestamps[1]
            @type = type
            #return { :from => timestamps[0], :till => timestamps[1], :type => type }
          else
            err_msg =  "Not a diff file, added/removed data filename must have two timestamps: \
                         #{diff_filename}"
            raise ArgumentError, err_msg
          end
        else
          err_msg = "Not a diff file, unsupported extension #{diff_filename}"
          raise ArgumentError, err_msg
        end
      end

      def earlier_than?(date_time)
        (@till <=> Date.new(date_time)) < 1
      end

      def later_than?(date_time)
        (@till <=> Date.new(date_time)) > 1
      end

      def same_time_as?(date_time)
        (@till <=> Date.new(date_time)) == 0
      end
    end
  end
end
