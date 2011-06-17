#!/usr/bin/ruby

require 'logger'
require './update_agent'

LOCALTZ = Time.now.zone
ENV['TZ'] = 'UTC'
Sequel.default_timezone = :nil

update_agent = UpdateAgent.new('vfs_prod', 'vfs_prod', 'Jdqwd6Fsq1', 'localhost')
update_agent.set_log(nil, Logger::INFO)

update_agent.update_entry_point('/net/server/archive', /^[^.].*\.(mp3|wmv|flv|wma|doc|pdf|tif)$/)
