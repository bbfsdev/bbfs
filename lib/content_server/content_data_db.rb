require 'date'
require 'singleton'
require 'fileutils'
require 'params'
require 'content_data'

module ContentServer

  # TODOs
  # * separate base files and diff files phisically,
  #   in a different folders

  # NOTEs
  # * "full", "base", "snapshot" notations used in method/variable names
  #    have the same meaning but
  #      - "full" is from user perspective, when adding an entry to the db
  #      - "snapshot" is from user perspective when requesting an entry from db
  #      - "base" the from db perspective.
  # * When there was a choice between time performance and
  #   memory consuming, then memory economy was preferred,
  #   cause memory is more critical for us and operations on
  #   content data files are run once a period of time.

  # A singleton used to keep and reign content data diffs and snapshots.
  class ContentDataDb
    include Singleton

    # Params
    Params.path('local_content_data_path', '~/.bbfs/db', 'ContentData file path')

    # Constants
    DIFFS_DIRNAME = 'diffs'
    DIFFS_PATH = File.join(Params['local_content_data_path'], DIFFS_DIRNAME)
    SNAPSHOTS_DIRNAME = 'snapshots'
    SNAPSHOTS_PATH = File.join(Params['local_content_data_path'], SNAPSHOTS_DIRNAME)

    # Attributes
    attr_reader :latest_timestamp

    def init_db_directory
      if File.exist?(Params['local_content_data_path'])
        if File.directory?(Params['local_content_data_path'])
          err_msg = "local_content_data_path parameter \
                      #{Params['local_content_data_path']} is not a directory"
          fail ArgumentError, err_msg
        end
      else
        FileUtils.mkdir_p Params['local_content_data_path']
      end

      unless Dir.exist? DIFFS_PATH
        FileUtils.mkdir_p DIFFS_PATH
      end

      unless Dir.exist? SNAPSHOTS_PATH
        FileUtils.mkdir_p SNAPSHOTS_PATH
      end
    end

    def initialize
      init_db_directory

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
      end
    end

    # Store content data as a part of content data keeping service.
    # If type is full flush then content data is saved as it.
    # Otherwise incremental diff of comparison with the latest saved file
    # is calculated and saved. Content data objects containing data regarding
    # added files and removed files is stored in a separate files.
    # If there is no added or/and removed files, then appropreate diff files
    # are not created.
    def add(content_data, is_full_flush)
      if is_full_flush
        filename = save(content_data,
                        ContentDataDiffFile::SNAPSHOT_TYPE,
                        nil,  # 'from' param is not relevant for full flush
                        ContentDataDiffFile.current_timestamp)
        latest_base_file = ContentDataDiffFile.new filename
        @latest_timestamp = latest_base_file.till
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
      path = case type
             when ContentDataDiffFile::SNAPSHOT_TYPE
               File.join(SNAPSHOTS_PATH, filename)
             when ContentDataDiffFile::ADDED_TYPE, ContentDataDiffFile::REMOVED_TYPE
               File.join(DIFFS_PATH, filename)
             else
               fail ArgumentError, "Unrecognized type: #{type}"
             end
      content_data.to_file(path)
    end

    def get(till = ContentDataDiffFile.current_timestamp)
      # looking for the latest base file that is earlier than till argument
      base = snapshot_files.reject(nil) do |cur_base, f|
        if cur_base.nil? ||
            (f.earlier_than?(till) && f.later_than?(cur_base.till))
          cur_base = f
        end
        cur_base
      end
      base_cd = ContentData::ContentData.new.from_file(base.filename)

      # applying diff files between base timestamp and till argument
      diff_from_base = diff(base.till, till)
      added_content_data = diff_from_base[ContentDataDiffFile::ADDED_TYPE]
      removed_content_data = diff_from_base[ContentDataDiffFile::REMOVED_TYPE]

      result = ContentData.merge(added_content_data, base_cd)
      ContentData.remove_instances(removed_content_data, result)
    end

    def diff(from, till = ContentDataDiffFile.current_timestamp)
      if from.nil?
        err_msg =  'from parameter should be defined. Did you mean a get method?'
        fail ArgumentError, err_msg
      end
      diff_files_in_range = diff_files.select do |df|
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
      # Example: "/path/to/diff_files/*.{added,removed}"
      pattern = "#{DIFFS_PATH}#{File::SEPARATOR}*.{\
                 #{ContentDataDiffFile::ADDED_TYPE},\
                 #{ContentDataDiffFile::REMOVED_TYPE}}"
      Dir.glob(pattern).each do |f|
        ContentDataDiffFile.new(f)
      end
    end

    def snapshot_files
      # Example: "/path/to/snapshot_files/*.snapshot
      pattern = "#{SNAPSHOTS_PATH}#{File::SEPARATOR}*.#{ContentDataDiffFile::SNAPSHOT_TYPE}"
      Dir.glob(pattern).each do |f|
        ContentDataDiffFile.new(f)
      end
    end

    # NOTE added/removed files do not intersect
    # this suggestion is used in timestamps comparioson.
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
      SNAPSHOT_TYPE = 'snapshot'
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
        when SNAPSHOT_TYPE
          till + SNAPSHOT_TYPE
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
        when SNAPSHOT_TYPE
          if timestamps.size == 1
            @till = timestamps[0]
            @type = type
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
          else
            err_msg =  "Not a diff file, added/removed data filename must have \
                        from and till timestamps: #{diff_filename}"
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
