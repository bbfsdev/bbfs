rem echo ---------------
rem echo install bundler
rem echo ----------------
rem call gem install bundle
rem echo --------------------------------------------
rem echo install infrastructure gems (bundle install)
rem echo -------------------------------------------
rem call bundle install
rem echo ---------------------------------
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
call gem install log-1.1.0.gem
call gem install content_data-1.1.0.gem
call gem install email-1.1.0.gem
call gem install file_copy-1.1.0.gem
call gem install file_indexing-1.1.0.gem
call gem install file_monitoring-1.1.0.gem
call gem install file_utils-1.1.0.gem
call gem install networking-1.1.0.gem
call gem install params-1.1.0.gem
call gem install process_monitoring-1.1.0.gem
call gem install run_in_background-1.1.0.gem
call gem install validations-1.1.0.gem
call gem install content_server-1.1.0.gem
