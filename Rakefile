require 'rubygems'
require 'rake'
require 'json'

desc 'Default: run specs and tests.'
task :default => [:spec]

desc 'Builds the gem'
task :build do
  FileList['*.gemspec'].each { |gemspec|
    sh "gem build #{gemspec}"
  }
end

desc 'Builds and installs the gem'
task :install => :build do
  FileList['*.gem'].each { |gem|
    sh "gem install #{gem}"
  }
end

desc 'Unistall gems'
task :uninstall do
  FileList['*.gem'].each { |gem|
    sh "echo | gem uninstall #{gem[/[^-]*/]}"
  }
end

# Creates coverage report based on rspecs.
# Current implementation: 
#   SimpleCov package.
# SimpleCov suggestions:
#   * see spec/spec_helper.rb and .simplecov files
#   * SimpleCov related code must be issued before any of your application code is required
# Output:
#   <project root>/coverage directory, containing report files, will be created.
# To view report:
#   open in a browser <project root>/coverage/index.html file. 
desc 'Run coverage'
task :coverage do
  ENV['BBFS_COVERAGE'] = 'true'
  Rake::Task["spec"].reenable
  Rake::Task["spec"].invoke
end

# Creates new template rspec file associated with provided source file.
# Parameter:
#   src=<path of associated source file>
#   If no parameter was provided, then user will be asked to enter a source file.
# Usage:
#   rake new_spec src=<path of associated source file>
#   rake new_spec
#   Examples:
#     rake new_spec src=lib/email/email.rb
#     rake new_spec
# Output:
#   New template rspec file will be created.
#   If absent then a suite directory will be created (see examples below).
#   Example:
#     * rake new_spec src=lib/email/email.rb
#       Suite directory will be created: spec/email/    
#       RSpec file will be created: spec/email/email_spec.rb
#     * rake new_spec src=lib/file_monitoring/file_monitoring.rb  
#       We already have spec/file_monitoring/ directory, so no need to create new one.
#       RSpec file will be created: spec/file_monitoring/file_monitoring_spec.rb
desc 'Add new spec template'
task :new_spec do
  if (ENV['src'].nil? || ENV['src'].empty?)
    puts 'Enter path to the source file:'
    src_path = STDIN::gets
    src_path.chomp!
  else
    src_path = ENV['src']
  end
  unless (File.exists?(src_path) && File.file?(src_path))
    puts "Source file #{src_path} does not exists. Exit.."
    exit 1
  end
  
  require 'pathname'
  src_abs_pathname = Pathname.new(File.absolute_path(src_path))
  # suggestion that Rakefile under the root dir of the project
  project_abs_pathname = Pathname.new(File.absolute_path(File.dirname(__FILE__)))
  src_rel_pathname = src_abs_pathname.relative_path_from(project_abs_pathname)

  src_lines = File.readlines(src_path)
  # lines that contain module declaration (e.g. "module ContentData")
  module_lines = src_lines.select { |l| l =~ /module / }
  if (module_lines.length > 0)
    # convention: suite name is a highest module among all modules declared in the source.
    # e.g for the following module hierarchy
    # module ContentData
    #   module Validations
    # the suite is a content_data
    module_name = module_lines.at(0).split(/\s+/).at(1).scan(/[A-Z][a-z0-9]*/).join('_').downcase
  else
    module_name = ''
  end

  spec_dir_name = File.join(project_abs_pathname.to_s, 'spec', module_name)
  unless(File.exists?(spec_dir_name) && File.directory?(spec_dir_name))
    puts "New suite directory created: #{spec_dir_name}"
    FileUtils.mkdir(spec_dir_name)
  end
  spec_name = File.basename(src_path, '.rb') + '_spec.rb'
  spec_path = File.join(spec_dir_name, spec_name)
  if (File.exists?(spec_path))
    puts "Spec #{spec_path} already exists. Do nothing. Exit.."
    exit
  end
  
  File.open(spec_path, 'w') do |f|
    # NOTE Do not change indentation, cause it will break correct indentation in the spec file
    f.write (
"# NOTE Code Coverage block must be issued before any of your application code is required
if ENV['BBFS_COVERAGE']
  require_relative '../spec_helper.rb'
  SimpleCov.command_name '#{module_name}'
end
require 'rspec'
require_relative '../../#{src_rel_pathname}'

"
    )
    ends = Array.new
    module_lines.each do |l|
      ends << l.match(/^\s*/)[0] + "end\n"
      f.write(l)
    end
    indent = if (ends.length > 1)
               ends[1].match(/^\s*/)[0].length - ends[0].match(/^\s*/)[0].length
             else
               2
             end
    f.write(' '*(module_lines.length)*indent + "module Spec\n")
    f.write(' '*(module_lines.length+1)*indent + "# TODO your spec code here\n")
    ends << ' '*(ends.length)*indent + "end\n"
    ends.reverse_each do |l|
      f.write(l)
    end
  end
  puts "New spec created: #{spec_path}"
end

require 'rspec/core/rake_task'
desc "Run specs"
RSpec::Core::RakeTask.new do |t|
  t.pattern = ["./test/**/*_spec.rb", "./spec/**/*_spec.rb"]
end

