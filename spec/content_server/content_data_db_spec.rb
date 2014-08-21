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
    describe 'ContentServerDb' do

      before :all do
        INSTANCE_SIZE = 1000
        SERVER = "server"
        BASE_CHECKSUM = 1000
        BASE_INSTANCE_SIZE = 1000
        BASE_MTIME = 1000

        base_cd1 = ContentData.new
        base_cd1.add_instance(BASE_CHECKSUM, BASE_INSTANCE_SIZE, SERVER, "unchanged", MTIME)
        base_cd1.add_instance(BASE_CHECKSUM, BASE_INSTANCE_SIZE, SERVER, "changed_1", MTIME)
        base_cd1.add_instance(BASE_CHECKSUM, BASE_INSTANCE_SIZE, SERVER, "unchang_1", MTIME)
        base_cd1.add_instance(BASE_CHECKSUM, BASE_INSTANCE_SIZE, SERVER, "removed", MTIME)

        changed_cd_diff_1 = ContentData.new
        changed_cd_diff_1.add_instance(BASE_CHECKSUM, BASE_INSTANCE_SIZE, SERVER, "changed_1", MTIME+100)
        changed_cd_diff_1.add_instance(BASE_CHECKSUM, BASE_INSTANCE_SIZE, SERVER, "added_1", MTIME+100)

        removed_cd_diff_1 = ContentData.new
        removed_cd_diff_1.add_instance(BASE_CHECKSUM, BASE_INSTANCE_SIZE, SERVER, "removed", MTIME+100)

        changed_cd_diff_2 = ContentData.new
        changed_cd_diff_2.add_instance(BASE_CHECKSUM, BASE_INSTANCE_SIZE, SERVER, "changed_2", MTIME+200)
        changed_cd_diff_2.add_instance(BASE_CHECKSUM, BASE_INSTANCE_SIZE, SERVER, "added_2", MTIME+200)

        removed_cd_diff_2 = ContentData.new
        removed_cd_diff_2.add_instance(BASE_CHECKSUM, BASE_INSTANCE_SIZE, SERVER, "removed", MTIME+200)

        @db_dir = Dir.mktmpdir
      end

      after :all do
        FileUtils.remove_entry_secure @db_dir
      end

      context "Init db" do
        it 'with no storage directories created' do
        end

        it 'with empty storage directories' do
        end

        it 'from the system that was already in use' do
        end
      end

      context 'Db operations' do
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
