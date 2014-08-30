# NOTE Code Coverage block must be issued before any of your application code is required
if ENV['BBFS_COVERAGE']
  require_relative '../spec_helper.rb'
  SimpleCov.command_name 'content_server'
end

require 'rspec'
require 'tmpdir'

require_relative '../../lib/content_server/content_data_db.rb'

module ContentServer
  module Spec
    describe 'ContentDataDb' do

      before :all do
        INSTANCE_SIZE = 1000
        SERVER = "server"
        CHECKSUM = 1000
        INSTANCE_SIZE = 1000
        MTIME = 1000

        base_cd1 = ContentData::ContentData.new
        base_cd1.add_instance(CHECKSUM, INSTANCE_SIZE, SERVER, "unchanged", MTIME)
        base_cd1.add_instance(CHECKSUM, INSTANCE_SIZE, SERVER, "changed_1", MTIME)
        base_cd1.add_instance(CHECKSUM, INSTANCE_SIZE, SERVER, "unchang_1", MTIME)
        base_cd1.add_instance(CHECKSUM, INSTANCE_SIZE, SERVER, "removed", MTIME)

        changed_cd_diff_1 = ContentData::ContentData.new
        changed_cd_diff_1.add_instance(CHECKSUM, INSTANCE_SIZE, SERVER, "changed_1", MTIME+100)
        changed_cd_diff_1.add_instance(CHECKSUM, INSTANCE_SIZE, SERVER, "added_1", MTIME+100)

        removed_cd_diff_1 = ContentData::ContentData.new
        removed_cd_diff_1.add_instance(CHECKSUM, INSTANCE_SIZE, SERVER, "removed", MTIME+100)

        changed_cd_diff_2 = ContentData::ContentData.new
        changed_cd_diff_2.add_instance(CHECKSUM, INSTANCE_SIZE, SERVER, "changed_2", MTIME+200)
        changed_cd_diff_2.add_instance(CHECKSUM, INSTANCE_SIZE, SERVER, "added_2", MTIME+200)

        removed_cd_diff_2 = ContentData::ContentData.new
        removed_cd_diff_2.add_instance(CHECKSUM, INSTANCE_SIZE, SERVER, "removed", MTIME+200)

        #@db_dir = Dir.mktmpdir
        #Params['local_content_data_path'] = @db_dir
      end

      after :all do
        #FileUtils.remove_entry_secure @db_dir
      end

      context "Init" do
        it 'with no storage directories yet created' do
          # setup
          db_dir = Dir.mktmpdir
          Params['local_content_data_path'] = db_dir
          FileUtils.rm_rf db_dir

          # check that test environment is correct
          Dir.exist?(db_dir).should be_false

          # operation
          ContentServer::ContentDataDb.instance

          # check
          Dir.exist?(db_dir).should be_true
          Dir.exist?(ContentServer::ContentDataDb::SNAPSHOTS_PATH).should be_true
          Dir.exist?(ContentServer::ContentDataDb::DIFFS_PATH).should be_true

          # tear down
          FileUtils.remove_entry_secure db_dir
        end

        it 'with empty storage directories' do
        end

        it 'from the system that was already in use' do
        end
      end

      context 'Operations' do
        it 'save a base file' do
        end

        it 'save a diff file' do
        end

        it 'diff between two timestamps' do
        end

        it 'diff with absent from timestamp failed' do
        end

        it 'get a snapshot' do
        end
      end
    end
  end
end
