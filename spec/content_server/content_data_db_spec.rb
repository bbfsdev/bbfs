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

        classname = String.new
        free_index = 1.upto(100).find do |i|
          classname = base + i.to_s
          eval("defined?(#{classname}) && #{classname}.is_a?(Class)").nil?
        end

        if free_index.nil?
          raise 'No free index found. Can not create a DB test class.'
        end
        klass = Class.new(ContentServer::ContentDataDb) {}
        Object.const_set(classname, klass)
        klass.instance
      end

      def is_snapshot?(mtime)
        (mtime - BASE_DATETIME)%365 == 0
      end

      before :all do
        Params.init []
        Log.init

        SIZE = 1000
        SERVER = "server"
        CHECKSUM = "1000"
        BASE_TIMESTAMP = '2010-11-29T04:01+03:00'
        BASE_DATETIME = DateTime.iso8601(BASE_TIMESTAMP)
        BASE_MTIME = BASE_DATETIME.strftime('%s').to_i

        @base = ContentData::ContentData.new
        @base.add_instance(CHECKSUM, SIZE, SERVER, "unchanged_1", BASE_MTIME, BASE_MTIME)
        @base.add_instance(CHECKSUM, SIZE, SERVER, "unchanged_2", BASE_MTIME, BASE_MTIME)

        @init_content_datas = {}
        @init_content_datas[BASE_DATETIME] = @base
        @removed_diffs = {}
        @added_diffs = {}
        @added_diffs[BASE_DATETIME] = ContentData::ContentData.new(@base)

        # Simulates indexation
        # @param mtime [DateTime]
        add_diff = Proc.new do |mtime|
          idx = @init_content_datas.size
          mtime_epoch = mtime.strftime('%s').to_i

          added_cd_diff = ContentData::ContentData.new
          added_cd_diff.add_instance(CHECKSUM+"#{idx}", SIZE+idx, SERVER, "changed_#{idx}", mtime_epoch, mtime_epoch)
          added_cd_diff.add_instance(CHECKSUM, SIZE, SERVER, "added_#{idx}", mtime_epoch, mtime_epoch)
          @added_diffs[mtime] = added_cd_diff

          removed_cd_diff = ContentData::ContentData.new
          removed_cd_diff.add_instance(CHECKSUM, SIZE, SERVER, "changed_#{idx}", BASE_MTIME, BASE_MTIME)
          removed_cd_diff.add_instance(CHECKSUM, SIZE, SERVER, "removed_#{idx}", BASE_MTIME, BASE_MTIME)
          @removed_diffs[mtime] = removed_cd_diff
          # suppose that changed_idx and removed_idx locations
          # were indexed first time at BASE_DATETIME
          @added_diffs[BASE_DATETIME].merge!(removed_cd_diff)

          prev_mtime = @init_content_datas.keys.sort.last
          prev_cd = @init_content_datas[prev_mtime]
          # prev_cd still do not contain removed_cd_diff instances,
          # we add them later
          #cd_new = prev_cd.remove_instances(removed_cd_diff)
          cd_new = prev_cd.merge(added_cd_diff)

          # suppose that changed_idx and removed_idx were indexed before,
          # therefore need to update appropriately content data files.
          @init_content_datas.each_value do |cd|
            cd.merge!(removed_cd_diff)
          end

          @init_content_datas[mtime] = cd_new
        end


        [1, 2, 3, 365, 366, 367].each do |supplement|
          add_diff.call(BASE_DATETIME + supplement)
        end

        #puts "ADDED SIZE = #{@added_diffs.size}"

        #@init_content_datas.each do |date, cd|
          #puts date.to_s
          #puts cd.to_s
        #end
        #puts "ADDED:"
        #@added_diffs.each do |date, cd|
          #puts date.to_s
          #puts cd.to_s
        #end
        #puts "REMOVED:"
        #@removed_diffs.each do |date, cd|
          #puts date.to_s
          #puts cd.to_s
        #end
      end

      before :each do
        @db_dir = Dir.mktmpdir
        Params['content_data_db_path'] = @db_dir
        @db_instance = get_db_instance

        @init_content_datas.keys.sort.each do |mtime|
          $local_content_data = @init_content_datas[mtime]
          @db_instance.add(is_snapshot?(mtime))
        end

        #puts `tree #{@db_dir}`
      end

      after :each do
        FileUtils.remove_entry_secure @db_dir
      end

      describe "Init" do
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
          expected_timestamp = @init_content_datas.keys.sort.last
          @db_instance.latest_timestamp.should == expected_timestamp
        end
      end

      describe 'Add' do
        before :all do
          # new folder for the next year should be created
          DATETIME_NEW = @init_content_datas.keys.sort.last + 365
          mtime_epoch = DATETIME_NEW.strftime('%s').to_i

          @added_cd_diff = ContentData::ContentData.new
          @added_cd_diff.add_instance(CHECKSUM+"a", SIZE+365*2, SERVER, "added_new", mtime_epoch, mtime_epoch)

          prev_mtime = @init_content_datas.keys.sort.last
          prev_cd = @init_content_datas[prev_mtime]
          @removed_cd_diff = @added_diffs[prev_mtime]
          #puts @removed_cd_diff

          @cd_new = prev_cd.remove_instances(@removed_cd_diff)
          @cd_new.merge!(@added_cd_diff)
        end

        before :each do
          $local_content_data = @cd_new
        end

        context 'Snapshot' do
          it 'adds a snapshot entry' do
            # Given
            exist_snapshot_files = @db_instance.snapshot_files

            # When
            @db_instance.add true

            # Then
            snapshot_db = @db_instance.get DATETIME_NEW
            snapshot_db.should == $local_content_data

            current_snapshot_files = @db_instance.snapshot_files
            expect(current_snapshot_files.size - exist_snapshot_files.size).to eq(1)
          end

          it 'adds a diff entries' do
            # Given
            exist_diff_files = @db_instance.diff_files

            # When
            @db_instance.add true

            #Then
            current_diff_files = @db_instance.diff_files
            expect(current_diff_files.size - exist_diff_files.size).to eq(2)
          end
        end

        context 'Diff' do
          it 'adds removed and added entires (files)' do
            # Given
            exist_diff_files = @db_instance.diff_files

            # When
            @db_instance.add false

            # Then
            current_diff_files = @db_instance.diff_files
            expect(current_diff_files.size - exist_diff_files.size).to eq(2)

            new_diff_files = current_diff_files.reject do |df|
              exist_diff_files.include?(df)
            end

            new_diff_files.each do |df|
              cd = ContentData::ContentData.new
              cd.from_file(df.filename)
              if df.type == ContentDataDb::DiffFile::ADDED_TYPE
                cd.should == @added_cd_diff
              elsif df.type == ContentDataDb::DiffFile::REMOVED_TYPE
                cd.should == @removed_cd_diff
              end
            end
          end
        end

        shared_examples 'Empty diff' do
          it "do not add DB entry (file) for this type" do
            # Given
            exist_diff_files = @db_instance.diff_files
            exist_type_fnames = exist_diff_files.inject([]) do |fnames, df|
                                  if df.type == type
                                    fnames << df.filename
                                  end
                                  fnames
                                end

            # When
            $local_content_data = cd_new
            @db_instance.add false

            # Then
            current_diff_files = @db_instance.diff_files
            expect(current_diff_files.size - exist_diff_files.size).to eq(1)

            new_diff_file = current_diff_files.first do |df|
              df.type == type &&
                !exist_added_fnames.include?(df.filename)
            end
            expect(new_diff_file).not_to be nil
          end
        end

        context 'No added instances' do
          let(:type) { ContentDataDb::DiffFile::ADDED_TYPE }
          let(:cd_new) { @init_content_datas[@init_content_datas.keys.sort.last].
                           merge(@added_cd_diff) }
          include_examples 'Empty diff'
        end

        context 'No removed instances' do
          let(:type) { ContentDataDb::DiffFile::REMOVED_TYPE }
          let(:cd_new) { @init_content_datas[@init_content_datas.keys.sort.last].
                           remove_instances(@removed_cd_diff) }
          include_examples 'Empty diff'
        end

        # Examples:
        #   1. snapshot file for the '20141129T010100' will be saved as
        #      <content_data_db_path>/snapshots/2014/20141129T010100.snapshot
        #   1. snapshot file for the '20151129T010100' will be saved as
        #      <content_data_db_path>/snapshots/2015/20141129T010100.snapshot
        it 'save entries by year' do
          pending 'TODO'
        end
      end

      describe 'Diff' do
        shared_examples 'diff spec' do
          describe 'returns instances with index times' do
            it "later than 'from' and not earlier than 'till'" do
              # When
              diff = @db_instance.diff(from, till)
              #puts "BASE_DATETIME: #{BASE_DATETIME}"
              #puts "FROM: #{from.to_s} : #{from.strftime("%s")}"
              #puts "TILL: #{till.to_s} : #{till.strftime("%s")}"

              # Then
              expected_removed_size = 0
              @removed_diffs.each do |timestamp, diff_cd|
                if (timestamp <=> from) == 1 && (timestamp <=> till) != 1
                  expected_removed_size += diff_cd.instances_size
                  diff_cd.each_instance do |checksum,_,_,_,server,path,_|
                    diff[ContentDataDb::DiffFile::REMOVED_TYPE].
                      content_has_instance?(checksum, server, path).
                      should be_true
                  end
                end
              end
              diff[ContentDataDb::DiffFile::REMOVED_TYPE].
                instances_size.should == expected_removed_size

              #puts "DIFF: #{diff[ContentDataDb::DiffFile::ADDED_TYPE].to_s}"
              expected_added_size = 0
              @added_diffs.each do |timestamp, diff_cd|
                #puts timestamp.to_s
                if (timestamp <=> from) == 1 && (timestamp <=> till) != 1
                  #puts "FOUND"
                  expected_added_size += diff_cd.instances_size
                  diff_cd.each_instance do |checksum,_,_,_,server,path,_|
                    #puts "#{checksum} : #{path}"
                    diff[ContentDataDb::DiffFile::ADDED_TYPE].
                      content_has_instance?(checksum, server, path).
                      should be_true
                  end
                end
              end
              diff[ContentDataDb::DiffFile::ADDED_TYPE].
                instances_size.should == expected_added_size
            end

            it 'latest if there were few for the location' do
              # Given
              # prepare input where:
              # file was few times changed (old revision removed, new added)
              latest_index_time = @init_content_datas.keys.sort.last
              latest_cd = @init_content_datas[latest_index_time]
              changed_fname = "changed_new"
              expected_checksum = nil
              1.upto(4) do |i|
                cd_new = ContentData::ContentData.new(latest_cd)
                if cd_new.instance_exists(SERVER, changed_fname)
                  cd_new.remove_instance(SERVER, changed_fname)
                end
                mtime = latest_index_time + 1
                mtime_epoch = mtime.strftime('%s').to_i
                expected_checksum = CHECKSUM + "#{i}"
                cd_new.add_instance(expected_checksum,
                                    SIZE + i,
                                    SERVER,
                                    changed_fname,
                                    mtime_epoch,
                                    mtime_epoch)
                latest_index_time = mtime
                latest_cd = cd_new
                $local_content_data = cd_new
                @db_instance.add false
              end
              expected_added_time = latest_index_time
              # and finally removed
              cd_new = ContentData::ContentData.new(latest_cd)
              cd_new.remove_instance(SERVER, changed_fname)
              $local_content_data = cd_new
              @db_instance.add false

              # When
              diff = @db_instance.diff(from, @db_instance.latest_timestamp)

              # Then
              diff[ContentDataDb::DiffFile::ADDED_TYPE].
                each_instance do |checksum,_,_,_,_,path,index_time|
                  if (path == changed_fname)
                    index_time.should == expected_added_time.strftime('%s').to_i
                    checksum.should == expected_checksum
                  end
                end
              diff[ContentDataDb::DiffFile::REMOVED_TYPE].
                each_instance do |checksum,_,_,_,_,path,index_time|
                  if (path == changed_fname)
                    # Was removed instance that was indexed at expected_added_time
                    index_time.should == expected_added_time.strftime('%s').to_i
                    checksum.should == expected_checksum
                  end
                end
            end
          end
        end

        context "diffs between two timestamps from same year" do
          let(:from)  { BASE_DATETIME + 1 }
          let(:till)  { BASE_DATETIME + 5 }
          include_examples 'diff spec'
        end

        context 'diffs between two timestamps from different years' do
          let(:from)  { BASE_DATETIME }
          let(:till)  { BASE_DATETIME + 367 }
          include_examples 'diff spec'
        end

      end

      describe 'Get' do
        it 'returns instances indexed before (including) provided timestamp' do
          # Given
          index_time_idx = @init_content_datas.size / 2
          till = @init_content_datas.keys.sort[index_time_idx]

          # When
          snapshot = @db_instance.get(till)

          # Then
          snapshot.should == @init_content_datas[till]
          till_epoch = till.strftime('%s').to_i
          snapshot.each_instance do |_,_,_,_,_,_,index_time|
            expect(index_time).to be <= till_epoch
          end
        end

        context 'No till timestamp provided' do
          it 'returns a latest snapshot' do
            # When
            snapshot = @db_instance.get

            # Then
            snapshot.should == @init_content_datas[@db_instance.latest_timestamp]
          end
        end
      end

      describe 'ContentServer::ContentDataDb#diff_files' do
        it 'returns all recorded added and removed diff files' do
          expected_size = @added_diffs.size + @removed_diffs.size
          expect(@db_instance.diff_files.size).to eq(expected_size)
        end
      end

      describe 'ContentServer::ContentDataDb#snapshot_files' do
        it 'returns all recorded snapshot files' do
          expected_size = @init_content_datas.keys.reduce(0) do |size, dt|
                            size += 1 if is_snapshot?(dt)
                            size
                          end
          expect(@db_instance.snapshot_files.size).to eq(expected_size)
        end
      end

      describe 'Filename' do
        context 'Timestamps' do
          it 'in a UTC Z timezone' do
            diff_fname = @db_instance.diff_files.last.filename
            snapshot_fname = @db_instance.snapshot_files.last.filename
            [diff_fname, snapshot_fname].each do |fname|
              timestamps = fname.scan(/#{ContentDataDb::DiffFile::TIME_PATTERN}/)
              timestamps.each do |ts|
                dt = DateTime.from_content_data_timestamp(ts)
                timezone = dt.strftime("%z")
                # expect to "+0000" or something similar for a Z zone
                expect(timezone).not_to match(/[1-9]/)
              end
            end
          end

          it "in #{ContentDataDb::DiffFile::TIME_FORMAT} format" do
            pending "TODO"
          end
        end

        it 'till part equals latest_timestamp' do
          # Given
          datetime_new = @init_content_datas.keys.sort.last + 365
          mtime_epoch = datetime_new.strftime('%s').to_i

          prev_mtime = @init_content_datas.keys.sort.last
          prev_cd = @init_content_datas[prev_mtime]
          new_cd = ContentData::ContentData.new(prev_cd)
          new_cd.add_instance(CHECKSUM+"a",
                              SIZE+365*2,
                              SERVER,
                              "added_new",
                              mtime_epoch,
                              mtime_epoch)

          exist_snapshot_files =
            @db_instance.snapshot_files.map { |df| df.filename }
          exist_diff_files =
            @db_instance.diff_files.map { |df| df.filename }

          $local_content_data = new_cd
          @db_instance.add true

          # Then
          snapshot = @db_instance.snapshot_files.find do |df|
                       !exist_snapshot_files.include?(df.filename)
                     end
          expect(snapshot.till).to eq(@db_instance.latest_timestamp)

          diffs = @db_instance.diff_files.select do |df|
                    !exist_diff_files.include?(df.filename)
                  end
          diffs.each do |df|
            expect(df.till).to eq(@db_instance.latest_timestamp)
          end
        end
      end
    end
  end
end
