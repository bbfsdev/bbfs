# Author: Genady Petelko (nukegluk@gmail.com)
# This file gives an example of index validations

# params[instance_check_level] used to control check level
# Supported levels are:
#   shallow - quick, tests instance for file existence and attributes.
#   deep - can take more time, in addition to shallow recalculates hash sum.
require 'params'
# Information about incorrect instances and contents will be written into log
require 'log'
require 'content_data'
require 'validations/index_validations'


# To check index that contains data about files from the local machine
# (i.e. same machine that index located)

# local index we want to check
local_index = ContentData::ContentData.new
local_index.from_file(index_path)  # suppose that index_path contains path to index we want to check
# this index used to get failed instances
failed = ContentData::ContentData.new

if local_index.validate(:failed => failed)
  # All instances are valid
else
  # Log contains information about failed instances and reasons of errors
  # failed object contains failed instances,
  # so we can process them
end

# To check that contents from remote machine have valid instances on local machine
# remote index we want to check
remote_index = ContentData::ContentData.new
remote_index.from_file(remote_index_path)  # suppose that remote_index_path contains path to index we want to check
# this index used to get failed instances
failed = ContentData::ContentData.new

if IndexValidations.validate_remote_index(remote_index, local_index, :failed => failed)
  # All remote contents have valid local instances
else
  # Log contains information about remote contents that have no valid local instances
  # as well as about appropriate absent/invalid instances.
  # failed object contains failed instances,
  # so we can process them
end

