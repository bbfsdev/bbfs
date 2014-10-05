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
    DateTime.strptime(timestamp,
                      ContentServer::ContentDataDb::DiffFile::TIME_FORMAT)
  end

  def to_content_data_timestamp()
    strftime(ContentServer::ContentDataDb::DiffFile::TIME_FORMAT)
  end
end

module ContentServer
  # NOTES:
  # * Singleton used cause:
  #   * We'd like only one gate to add and control a DB
  #     * Better maintainability and consistency
  #   * Another option was to use a class methods only,
  #     but we have a state for the DB and then it is better to use a singleton.

  # A singleton used to keep and reign content data diffs and snapshots.
  #
  # === File structure:
  #
  # db_root
  #   diffs
  #       year1
  #           date0-date1.added
  #           date0-date1.removed
  #           date1-date2.added
  #           date1-date2.removed
  #           date2-date3.added
  #           date2-date3.removed
  #           date3-date4.added
  #           date3-date4.removed
  #   snaphots
  #       year1
  #           date2.snaphot
  #           date4.snaphot
  #
  # === Filenames:
  #
  # *date1-date2.added* for instances that were added from date1 till date2
  #
  # *date1-date2.removed* for instances that were removed from date1 till date2
  #
  # *date1.snapshot* for the snaphot of indexed files that was exist at date1
  #
  #
  # === Specifications:
  #  Init
  #    create storage directories lazily
  #    pick a latest timestamp from exist entries in DB
  #  Add
  #    save entries by year
  #    Snapshot
  #      adds a snapshot entry
  #      adds a diff entries
  #    Diff
  #      adds removed and added entires (files)
  #    No added instances
  #      do not add DB entry (file) for this type
  #    No removed instances
  #      do not add DB entry (file) for this type
  #  Diff
  #    diffs between two timestamps from same year
  #      returns all instances
  #        added or removed later than 'from' and not later than 'till'
  #        with index times latest if there were few for the location
  #    diffs between two timestamps from different years
  #      returns all instances
  #        added or removed later than 'from' and not later than 'till'
  #        with index times latest if there were few for the location
  #  Get
  #    returns instances indexed before (including) provided timestamp
  #    No till timestamp provided
  #      returns a latest snapshot
  #  ContentServer::ContentDataDb#diff_files
  #    returns all recorded added and removed diff files
  #  ContentServer::ContentDataDb#snapshot_files
  #    returns all recorded snapshot files
  #  Filename
  #    till part equals latest_timestamp
  #    Timestamps
  #      in a UTC Z timezone
  #
  # === NOTEs:
  # * "full", "base", "snapshot" notations used in method/variable names have
  #   the same meaning but:
  #     * "full" is from user perspective, when adding an entry to the db
  #     * "snapshot" is from user perspective when requesting an entry from db
  #     * "base" is from db perspective when calculating snapshot.
  # * When there was a choice between time performance and
  #   memory consuming, then memory economy was preferred,
  #   cause memory is more critical for us and operations on
  #   content data files are run once a period of time.
  # * Diff files do not intersect,
  #   it means that following situation is illegal:
  #     date5-date7.added
  #     date6-date8.added
  #     where date5 < date6 < date7 < date8
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
    # paths to the folders where diffs and snapshots are stored
    attr_reader :diffs_path, :snapshots_path

    def initialize
      @diffs_path = File.join(Params['content_data_db_path'], DIFFS_DIRNAME)
      @snapshots_path = File.join(Params['content_data_db_path'], SNAPSHOTS_DIRNAME)

      # We save a diff file, even when adding a snapshot,
      # so it is enough to look for latest timestamp among diff files.
      # See add method for more information.
      # If there is no diff files then latest timestamp will be set to nil.
      @latest_timestamp =
        diff_files.inject(nil) do |latest, f|
          latest = f.till if latest.nil? || f.later_than?(latest)
          latest
        end
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
      return if content_data.empty?

      # for the latest content data added to the DB
      latest_snapshot = nil
      # for instances that were added regarding latest_snapshot
      added_cd = nil
      # for insrances that were removed regarding latest_snapshot
      removed_cd = nil

      latest_index_time = nil
      content_data.each_instance do |_,_,_,_,_,_,index_time|
        if latest_index_time.nil? || latest_index_time < index_time.to_i
          latest_index_time = index_time.to_i
        end
      end

      # Checking time consistency
      content_data_timestamp = DateTime.from_epoch(latest_index_time)
      if !@latest_timestamp.nil? && (content_data_timestamp <= @latest_timestamp)
        # It is possible when instances added at @latest_timestamp
        # were removed and any new instances addded,
        # then latest indexed time in the new content data
        # is earlier then @latest_timestamp
        # Example:
        #  ContentData for Date1 (noted as latest_snapshot):
        #      Content1
        #          location1
        #          location2
        #  Between Date1 and Date2 location2 was removed
        #  and no other file operations were done.
        #  ContentData for Date2 (noted as content_data):
        #      Content1
        #          location1
        #  Then:
        #      content_data.remove_instances(latest_snapshot) is empty.
        latest_snapshot = get(@latest_timestamp)
        added_cd = content_data.remove_instances(latest_snapshot)
        msg = "latest index time of the content data: #{content_data_timestamp}" +
          "must be later then latest timestamp: #{latest_timestamp}"
        if added_cd.empty?
          # In this case we do not know exactly when the indexation was
          # then the timestamp is fake
          # TODO better solution?
          latest_timestamp_epoch = @latest_timestamp.strftime('%s')
          content_data_timestamp = DateTime.from_epoch(latest_timestamp_epoch.to_i + 1)
          Log.warning msg
        else
          fail msg
        end
      end

      if is_full_flush
        save(content_data,
             DiffFile::SNAPSHOT_TYPE,
             nil,  # 'from' param is not relevant for full flush
             content_data_timestamp)
      end

      # If it is not the first content data that we store,
      # i.e there are already stored content data,
      # then a diff files are relevant.
      # NOTE we save diff (added/removed) files even in the case of full flush
      # cause of data consistency. It is crucial for the diff operation.
      # Example (simple, without removed):
      #     When:
      #         date1-date2.added
      #         date2-date3.added (added along with a snapshot)
      #         date3.snapshot
      #         date3-date4.added
      # Then:
      #     ContentDataDb.diff(date2, date4) = date2-date3.added + date3-date4.added
      if @latest_timestamp.nil?
        earliest_index_time = nil
        content_data.each_instance do |_,_,_,_,_,_,index_time|
          if earliest_index_time.nil? || earliest_index_time > index_time
            earliest_index_time = index_time
          end
        end
        content_data_from = DateTime.from_epoch(earliest_index_time)
        save(content_data,
             DiffFile::ADDED_TYPE,
             content_data_from,
             content_data_timestamp)
      else
        latest_snapshot ||= get(@latest_timestamp)

        added_cd ||= content_data.remove_instances(latest_snapshot)
        unless added_cd.empty?
          save(added_cd,
               DiffFile::ADDED_TYPE,
               @latest_timestamp,
               content_data_timestamp)
        end

        removed_cd = latest_snapshot.remove_instances(content_data)
        unless removed_cd.empty?
          save(removed_cd,
               DiffFile::REMOVED_TYPE,
               @latest_timestamp,
               content_data_timestamp)
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
      filename = DiffFile.compose_filename(type, from, till)
      path = case type
             when DiffFile::SNAPSHOT_TYPE
               File.join(@snapshots_path, till.year.to_s, filename)
             when DiffFile::ADDED_TYPE, DiffFile::REMOVED_TYPE
               File.join(@diffs_path, till.year.to_s, filename)
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
    # @param till [DateTime] index time upper (including) limit
    #                        Default is a current time.
    #
    # @return [ContentData] content data that contains data regarding files
    #   that where indexed no later (including) the provided timestamp.
    def get(till = DateTime.now)
      # looking for the latest base file that is earlier than till argument
      base = snapshot_files.inject(nil) do |cur_base, f|
        if (cur_base.nil? || f.same_time_as?(till) ||
            (f.earlier_than?(till) && f.later_than?(cur_base.till)))
          cur_base = f
        end
        cur_base
      end
      base_cd = ContentData::ContentData.new
      base_cd.from_file(base.filename)
      # applying diff files between base timestamp and till argument
      diff_from_base = diff(base.till, till)
      added_content_data = diff_from_base[DiffFile::ADDED_TYPE]
      removed_content_data = diff_from_base[DiffFile::REMOVED_TYPE]

      result = base_cd.merge(added_content_data)
      result.remove_instances!(removed_content_data)
      result
    end

    # Diff between two timestamps.
    # @note changed files reported twice, one time as removed, with previous
    # revision meta-data, second as an added with new revision meta-data.
    # @param from [DateTime] diff index time lower limit
    # @param till [DateTime] diff index time upper (including) limit.
    #
    # @return [Hash] map with 2 key-value pairs:
    #   1. DiffFile::REMOVED_TYPE => content data contains data of removed files
    #   2. DiffFile::ADDED_TYPE => content data contains data of added files
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

      # diff files sorted by date to enable correct processing of files
      # that were changed few times between the timestamps,
      # thus resulted revision is indeed latest revision.
      diff_files_in_range.sort!.each do |df|
        cd = ContentData::ContentData.new
        cd.from_file(df.filename)
        if df.type == DiffFile::ADDED_TYPE
          added_content_data.merge!(cd)
        elsif df.type == DiffFile::REMOVED_TYPE
          removed_content_data.merge!(cd)
        end
      end

      { DiffFile::REMOVED_TYPE => removed_content_data,
        DiffFile::ADDED_TYPE => added_content_data }
    end

    def diff_files
      # Example: "/path/to/diff_files/**/*.{added,removed}"
      pattern = @diffs_path + File::SEPARATOR + '**' + File::SEPARATOR + '*.{' +
                 DiffFile::ADDED_TYPE + ',' +
                 DiffFile::REMOVED_TYPE + '}'
      Dir.glob(pattern).map do |f|
        DiffFile.new(f)
      end
    end

    def snapshot_files
      # Example: "/path/to/snapshot_files/*.snapshot
      pattern = @snapshots_path + File::SEPARATOR + '**' +
                File::SEPARATOR + '*.' + DiffFile::SNAPSHOT_TYPE
      Dir.glob(pattern).map do |f|
        DiffFile.new(f)
      end
    end


    class DiffFile
      # Constants
      # %Y%m%dT%H%M => 20071119T0837
      # Corresponds with ISO 8601 => can be parsed by Ryby date/time libraries
      TIME_FORMAT = '%Y%m%dT%H%M%S'
      # Time searching pattern
      # year is 4 digits
      # month is 2 digits
      # day is 2 digits
      # hour is 2 digits
      # minutes are 2 digits
      # seconds are 2 digits
      TIME_PATTERN = '\d{8}T\d{6}'
      # Separator between 'from' and 'till' timestamps in a diff filename
      TIMESTAMPS_SEPARATOR = '-'
      SNAPSHOT_TYPE = 'snapshot'
      ADDED_TYPE = 'added'
      REMOVED_TYPE = 'removed'

      attr_reader :from, :till, :type, :filename

      def initialize(filename)
        @filename = filename
        parse(filename)
      end

      def self.compose_filename(type, from, till)
        if from.nil? && type != SNAPSHOT_TYPE
          fail ArgumentError, "from parameter must be defined for #{type}"
        elsif type != SNAPSHOT_TYPE
          from = from.to_content_data_timestamp
        end
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
        (@till <=> date_time) == -1
      end

      def later_than?(date_time)
        (@till <=> date_time) == 1
      end

      def same_time_as?(date_time)
        (@till <=> date_time) == 0
      end

      def <=>(other)
        @till <=> other.till
      end

      def ==(other)
        @till == other.till &&
          @from == other.from &&
          @filename == other.filename &&
          @type == other.type
      end
    end
  end
end
