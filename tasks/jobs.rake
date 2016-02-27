# tasks/jobs.rake

task :environment do
  require File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'boot.rb'))
end

namespace :jobs do
  desc "Clear the delayed_job queue."
  task :clear => :environment do
    Delayed::Job.delete_all
    FillStatusesJob.delete_all
  end

  desc 'delayed_job worker process'
  task :work => :environment do
    queues = ENV['QUEUES'].split(",") unless ENV['QUEUES'].nil?
    Delayed::Worker.new(:min_priority => ENV['MIN_PRIORITY'], :max_priority => ENV['MAX_PRIORITY'], :queues => queues).start
  end
end
