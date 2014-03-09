# NOTE Code Coverage block must be issued before any of your application code is required
if ENV['BBFS_COVERAGE']
  require_relative '../spec_helper.rb'
  SimpleCov.command_name 'content_server'
end
require 'rspec'

require_relative '../../lib/file_copy/copy.rb'

module ContentServer
  module Spec

    describe 'Backup Listener' do

    end

    describe 'Local file monitor' do

    end

    describe 'Local file indexer' do

    end

    describe 'File copier' do

    end

  end
end
