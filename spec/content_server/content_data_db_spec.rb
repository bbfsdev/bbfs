# NOTE Code Coverage block must be issued before any of your application code is required
if ENV['BBFS_COVERAGE']
  require_relative '../spec_helper.rb'
  SimpleCov.command_name 'content_server'
end

require 'rspec'
require 'tmpdir'
require 'params'
require 'log'

require_relative '../../lib/content_server/content_data_db.rb'

module ContentServer
  module Spec
    describe 'ContentDataDb' do

      # Workaround to test singleton
      # Creates classes that behaves like a DB class.
      def get_db_instance
        base = 'DbWrapper'
        get_name = Proc.new { |i| base + i.to_s }

        free_index = 1.upto(100).find do |i|
          name = get_name.call(i)
          eval("defined?(#{name}) && #{name}.is_a?(Class)").nil?
        end

        if free_index.nil?
          raise 'No free index found. Can not create a DB test class.'
        else
          classname = get_name.call(free_index)
        end
        klass = Class.new(ContentServer::ContentDataDb) {}
        Object.const_set(classname, klass)
        klass.instance
      end

      def create_diff(mtime)
        idx = @content_datas.size
        mtime_epoch = mtime.strftime('%s').to_i

        added_cd_diff = ContentData::ContentData.new
        added_cd_diff.add_instance(CHECKSUM+"#{idx}", SIZE+idx, SERVER, "changed_#{idx}", mtime_epoch, mtime_epoch)
        added_cd_diff.add_instance(CHECKSUM, SIZE, SERVER, "added_#{idx}", mtime_epoch, mtime_epoch)

        removed_cd_diff = ContentData::ContentData.new
        removed_cd_diff.add_instance(CHECKSUM, SIZE, SERVER, "changed_#{idx}", BASE_MTIME, BASE_MTIME)
        removed_cd_diff.add_instance(CHECKSUM, SIZE, SERVER, "removed_#{idx}", BASE_MTIME, BASE_MTIME)

        prev_mtime = @content_datas.keys.sort.last
        prev_cd = @content_datas[prev_mtime]
        cd_new = ContentData.remove_instances(removed_cd_diff, prev_cd)
        ContentData.merge_override_b(added_cd_diff, cd_new)

        {idx: idx, cd_new: cd_new, added_cd_diff: added_cd_diff, removed_cd_diff: removed_cd_diff}
      end

      # Simulates indexation
      def add_diff(mtime)
        diff = create_diff mtime
        idx = diff[:idx]

        @added_diffs[mtime] = diff[:added_cd_diff]
        @removed_diffs[mtime] = diff[:removed_cd_diff]

        @content_datas.each_value do |cd|
          cd.add_instance(CHECKSUM, SIZE, SERVER, "changed_#{idx}", BASE_MTIME, BASE_MTIME)
          cd.add_instance(CHECKSUM, SIZE, SERVER, "removed_#{idx}", BASE_MTIME, BASE_MTIME)
        end

        @content_datas[mtime] = diff[:cd_new]
      end

      before :all do
        Params.init []
        Log.init

        SIZE = 1000
        SERVER = "server"
        CHECKSUM = "1000"
        BASE_TIMESTAMP = '2014-12-29T04:01+03:00'
        BASE_DATETIME = DateTime.iso8601(BASE_TIMESTAMP)
        BASE_MTIME = BASE_DATETIME.strftime('%s').to_i

        @base = ContentData::ContentData.new
        @base.add_instance(CHECKSUM, SIZE, SERVER, "unchanged_1", BASE_MTIME, BASE_MTIME)
        @base.add_instance(CHECKSUM, SIZE, SERVER, "unchanged_2", BASE_MTIME, BASE_MTIME)

        @content_datas = {}
        @content_datas[BASE_DATETIME] = @base
        @removed_diffs = {}
        @added_diffs = {}

        add_diff(BASE_DATETIME + 1)
        add_diff(BASE_DATETIME + 2)
        add_diff(BASE_DATETIME + 365)
        add_diff(BASE_DATETIME + 366)
      end

      before :each do
        @db_dir = Dir.mktmpdir
        Params['content_data_db_path'] = @db_dir
        @db_instance = get_db_instance

        @content_datas.each do |mtime, cd|
          $local_content_data = cd
          @db_instance.add((mtime - BASE_DATETIME)%365 == 0)
        end

        puts `tree #{@db_dir}`
      end

      after :each do
        FileUtils.remove_entry_secure @db_dir
      end

      pending "Init" do
        it 'create storage directories lazily' do
          # Given
          FileUtils.rm_rf @db_dir

          # check that test environment is correct
          Dir.exist?(@db_dir).should be_false
          @db_instance = get_db_instance

          # When
          $local_content_data = @base
          @db_instance.add true

          # Then
          Dir.exist?(@db_dir).should be_true
          Dir.exist?(@db_instance.diffs_path).should be_true
          Dir.exist?(@db_instance.snapshots_path).should be_true
        end

        it 'pick a latest timestamp from exist entries in DB' do
          # When
          @db_instance = get_db_instance

          # Then
          #expected_timestamp = DateTime.from_epoch(MTIME_3).to_content_data_timestamp
          expected_timestamp = @content_datas.keys.sort.last
          @db_instance.latest_timestamp.should == expected_timestamp
            #DateTime.from_content_data_timestamp(expected_timestamp)
        end
      end

      context 'Add' do
        before :all do
          # + 2 years, then new folder for the next year should be created
          DATETIME_NEW = (BASE_DATETIME + 365*2)
          diff = create_diff(DATETIME_NEW)
          puts diff[:added_cd_diff].to_s
          puts diff[:removed_cd_diff].to_s
          @cd_new = diff[:cd_new]
        end

        before :each do
          $local_content_data = @cd_new
        end

        it 'adds a snapshot' do
          # When
          @db_instance.add true

          # Then
          snapshot_db = @db_instance.get DATETIME_NEW
          snapshot_db.should == $local_content_data
        end

        # Implementation dependant
        it 'stores a diff when adds snapshot' do
          # Given
          exist_diff_files = @db_instance.diff_files

          # When
          @db_instance.add true
          puts "In ADD"
          puts `tree #{@db_dir}`

          #Then
          current_diff_files = @db_instance.diff_files
          #puts "Diff #{current_diff_files.size - exist_diff_files.size}"
          expect(current_diff_files.size - exist_diff_files.size).to eq(2)
        end

        xit 'adds a diff' do
        end

        xit 'do not add DB entries for empty added or removed diff' do
        end

      end

      xit 'diffs between two timestamps' do
      end

      xit 'diffs between two timestamps from different years' do
      end

      xit 'get a snapshot' do
      end

      xit 'gat a snapshot with default, now, date' do
      end
    end
  end
end
