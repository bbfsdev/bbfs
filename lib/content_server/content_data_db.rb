require 'date'
require 'singleton'
require 'fileutils'
require 'params'
require 'content_data'

class DateTime
  def self.from_epoch(epoch_time)
    DateTime.strptime("#{epoch_time}", '%s')
  end

  def self.from_content_data_timestamp(timestamp)
    DateTime.strptime(timestamp, ContentDataDiffFile::TIME_FORMAT)
  end

  def to_content_data_timestamp()
    strftime(ContentDataDiffFile::TIME_FORMAT)
  end
end

module ContentServer

  # TODOs
  # - dirs by year
  # - use a DateTime instead String as a timestamp

  # A singleton used to keep and reign content data diffs and snapshots.
  # NOTEs
  # * "full", "base", "snapshot" notations used in method/variable names
  #    have the same meaning but
  #      - "full" is from user perspective, when adding an entry to the db
  #      - "snapshot" is from user perspective when requesting an entry from db
  #      - "base" is from db perspective when calculating snapshot.
  # * When there was a choice between time performance and
  #   memory consuming, then memory economy was preferred,
  #   cause memory is more critical for us and operations on
  #   content data files are run once a period of time.
  # * Added/removed files do not intersect
  #   this suggestion is used in timestamps comparioson.
  # * UTC time used in content_data objects and in timestamps
  # * time objects in DateTime format
  class ContentDataDb
    include Singleton

    # Params
    Params.path('content_data_db_path', '~/.bbfs/db', 'Root of CntentData DB')

    # Constants
    DIFFS_DIRNAME = 'diffs'
    SNAPSHOTS_DIRNAME = 'snapshots'

    # Attributes
    # DateTime contains timestamp of the last content data added to the DB
    attr_reader :latest_timestamp

    def initialize
      @diffs_path = File.join(Params['content_data_db_path'], DIFFS_DIRNAME)
      @snapshots_path = File.join(Params['content_data_db_path'], SNAPSHOTS_DIRNAME)

      exist_snapshot_files = snapshot_files
      if exist_snapshot_files.nil? || exist_snapshot_files.empty?
      end
        exist_diff_files = diff_files
        @latest_timestamp =
          exist_diff_files.inject(exist_diff_files.first.till) do |latest, f|
          latest = f.till if f.later_than?(latest)
          latest
          end
      #end
    end

    # Store a global content data object as a part of content data keeping service.
    # If type is full flush then content data is saved as it.
    # Otherwise incremental diff of comparison with the latest saved file
    # is calculated and saved. In the later case content data objects containing
    # data regarding added files and removed files is stored in a separate files.
    # If there is no added or/and removed files, then appropreate diff files
    # are not created.
    # NOTE global content data object should be locked for writing while adding
    # it to this service.
    #
    # @param is_full_flush [Boolean] true to store as a snapshot, false to store
    # as a diff
    def add(is_full_flush)
      content_data = $local_content_data

      latest_index_time = nil
      content_data.each_instance do |_,_,_,_,_,_,index_time|
        if latest_index_time.nil? || latest_index_time < index_time
          latest_index_time = index_time
        end
      end

      content_data_timestamp = DateTime.from_epoch(latest_index_time)
      if !@latest_timestamp.nil? && (content_data_timestamp <=> @latest_timestamp) < 0
        fail "latest index time of the content data: #{latest_index_time}" +
          "must be later then latest timestamp: #{latest_timestamp}"
      end

      if is_full_flush
        save(content_data,
             ContentDataDiffFile::SNAPSHOT_TYPE,
             nil,  # 'from' param is not relevant for full flush
             content_data_timestamp)
      end

      # If it is not the first content data that we store,
      # i.e there are already stored content data,
      # then a diff files are relevant.
      # NOTE we save diff (added/removed) files even in the case of full flush
      # cause of data consistency. It is crucial for the diff operation.
      if @latest_timestamp
        diff_from_latest = diff(@latest_timestamp, content_data_timestamp)
        diff_from_latest.each do |type, diff_cd|
          unless diff_cd.empty?
            save(diff_cd, type, @latest_timestamp, content_data_timestamp)
          end
        end
      end

      @latest_timestamp = content_data_timestamp
    end

    # Save content data file in the DB.
    # ContentData DB directories created in the lazy manner,
    # so if they are still absent, they will be created during add content data
    # operation.
    #
    # @param content_data [ContentData]
    # @param type [String] one from the predefined diff types
    # @param from [DateTime] diff file contains data from this timestamp
    # @param till [DateTime] diff file contains data till (including) this timestamp
    #
    # @return [String] filename of the file where provided ContentData was saved
    def save(content_data, type, from, till)
      filename = ContentDataDiffFile.compose_filename(type, from, till)
      path = case type
             when ContentDataDiffFile::SNAPSHOT_TYPE
               File.join(@snapshots_path, till.year, filename)
             when ContentDataDiffFile::ADDED_TYPE, ContentDataDiffFile::REMOVED_TYPE
               File.join(@diffs_path, till.year, filename)
             else
               fail ArgumentError, "Unrecognized type: #{type}"
             end
      dirname = File.dirname(path)
      unless Dir.exist?(dirname)
        FileUtils.mkdir_p dirname
      end

      content_data.to_file(path)
      filename
    end
    private :save

    # Returns a snapshot of instances indexed before (including)
    # provided timestamp.
    #
    # @param till [DateTime] index time upper limit
    #                        Default is a current time.
    #
    # @return [ContentData] content data that contains data regarding files
    #   that where indexed no later (including) the provided timestamp.
    def get(till = DateTime.now)
      # looking for the latest base file that is earlier than till argument
      base = snapshot_files.reject(nil) do |cur_base, f|
        if (cur_base.nil? || f.same_time_as?(till) ||
            (f.earlier_than?(till) && f.later_than?(cur_base.till)))
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

    # Diff between two timestamps.
    # @param from [DateTime] diff index time lower limit
    # @param till [DateTime] diff index time upper (including) limit.
    #                        Default is a current time.
    #
    # @return [Hash] map with 2 key-value pairs:
    #   ContentDataDiffFile::REMOVED_TYPE => content data contains data of removed files
    #   ContentDataDiffFile::ADDED_TYPE => content data contains data of added files
    def diff(from, till = DateTime.now)
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
      # Example: "/path/to/diff_files/**/*.{added,removed}"
      pattern = @diffs_path + File::SEPARATOR + '**' + File::SEPARATOR + '*.{' +
                 ContentDataDiffFile::ADDED_TYPE + ',' +
                 ContentDataDiffFile::REMOVED_TYPE + '}'
      Dir.glob(pattern).each do |f|
        ContentDataDiffFile.new(f)
      end
    end

    def snapshot_files
      # Example: "/path/to/snapshot_files/*.snapshot
      pattern = @snapshots_path + File::SEPARATOR + '**' +
                File::SEPARATOR + '*.' + ContentDataDiffFile::SNAPSHOT_TYPE
      Dir.glob(pattern).each do |f|
        ContentDataDiffFile.new(f)
      end
    end


    class ContentDataDiffFile
      # Constants
      # %Y%m%dT%H%M => 20071119T0837
      # Corresponds with ISO 8601 => can be parsed by Ryby date/time libraries
      TIME_FORMAT = '%Y%m%dT%H%M'
      # Time searching pattern
      # year is 4 digits
      # month is 2 digits
      # day is 2 digits
      # hour is 2 digits
      # seconds are 2 digits
      TIME_PATTERN = '\d{8}T\d{4}'
      TIMESTAMPS_SEPARATOR = '-'
      SNAPSHOT_TYPE = 'snapshot'
      ADDED_TYPE = 'added'
      REMOVED_TYPE = 'removed'

      attr_reader :from, :till, :type, :filename

      def initialize(filename)
        parse(filename)
      end

      def self.compose_filename(type, from, till)
        from = from.to_content_data_timestamp
        till = till.to_content_data_timestamp
        case type
        when SNAPSHOT_TYPE
          till + '.' + SNAPSHOT_TYPE
        when ADDED_TYPE
          from + TIMESTAMPS_SEPARATOR + till + '.' + ADDED_TYPE
        when REMOVED_TYPE
          from + TIMESTAMPS_SEPARATOR + till + '.' + REMOVED_TYPE
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
            @till = DateTime.from_content_data_timestamp(timestamps[0])
            @type = type
          else
            err_msg =  "Not a diff file, full data filename must have one timestamp: \
                         #{diff_filename}"
            raise ArgumentError, err_msg
          end
        when ADDED_TYPE, REMOVED_TYPE
          if timestamps.size == 2
            @from = DateTime.from_content_data_timestamp(timestamps[0])
            @till = DateTime.from_content_data_timestamp(timestamps[1])
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
        (@till <=> date_time) < 1
      end

      def later_than?(date_time)
        (@till <=> date_time) > 1
      end

      def same_time_as?(date_time)
        (@till <=> date_time) == 0
      end
    end
  end
end
