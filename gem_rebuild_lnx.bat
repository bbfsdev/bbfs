#!/bin/sh
echo ---------------------------------------
echo uninstall all gemspecs\gems\version\executables:
echo ---------------------------------------
for x in `gem list --no-versions`; do gem uninstall $x -a -x -I; done
rm *.gem
echo ---------------
#echo install bundler
#echo ----------------
#gem install bundle
#echo --------------------------------------------
#echo 'install infrastructure gems (bundle install)'
#echo -------------------------------------------
#bundle install
#echo ---------------------------------
echo Start build content server gems:
echo --------------------------------
gem build log.gemspec
gem build content_data.gemspec
gem build content_server.gemspec
gem build email.gemspec
gem build file_copy.gemspec
gem build file_indexing.gemspec
gem build file_monitoring.gemspec
gem build file_utils.gemspec
gem build networking.gemspec
gem build params.gemspec
gem build process_monitoring.gemspec
gem build run_in_background.gemspec
gem build validations.gemspec
echo -------------------------------------
echo Start installing content server gems:
echo -------------------------------------
gem install log-1.1.0.gem
gem install content_data-1.1.0.gem
gem install email-1.1.0.gem
gem install file_copy-1.1.0.gem
gem install file_indexing-1.1.0.gem
gem install file_monitoring-1.1.0.gem
gem install file_utils-1.1.0.gem
gem install networking-1.1.0.gem
gem install params-1.1.0.gem
gem install process_monitoring-1.1.0.gem
gem install run_in_background-1.1.0.gem
gem install validations-1.1.0.gem
gem install content_server-1.1.0.gem
