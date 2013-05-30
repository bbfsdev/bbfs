echo ---------------------------------------
echo uninstall all gems\version\executables:
echo ---------------------------------------
call ruby -e "`gem list`.split(/$/).each { |line| puts `gem uninstall -Iax #{line.split(' ')[0]}` unless line.empty? }"

echo ---------------
echo install bundler
echo ----------------
rem call gem install bundle

echo --------------------------------------------
echo install infrastructure gems (bundle install)
echo -------------------------------------------
rem call bundle install


echo ---------------------------------
echo Start build content server gems:
echo --------------------------------
call gem build log.gemspec
call gem build content_data.gemspec
call gem build content_server.gemspec
call gem build email.gemspec
call gem build file_copy.gemspec
call gem build file_indexing.gemspec
call gem build file_monitoring.gemspec
call gem build file_utils.gemspec
call gem build networking.gemspec
call gem build params.gemspec
call gem build process_monitoring.gemspec
call gem build run_in_background.gemspec
call gem build validations.gemspec
echo -------------------------------------
echo Start installing content server gems:
echo -------------------------------------
call gem install content_server-1.0.1.gem
call gem install log-1.0.1.gem
call gem install content_data-1.0.1.gem
call gem install email-1.0.1.gem
call gem install file_copy-1.0.1.gem
call gem install file_indexing-1.0.1.gem
call gem install file_monitoring-1.0.1.gem
call gem install file_utils-1.0.1.gem
call gem install networking-1.0.1.gem
call gem install params-1.0.1.gem
call gem install process_monitoring-1.0.1.gem
call gem install run_in_background-1.0.1.gem
call gem install validations-1.0.1.gem


