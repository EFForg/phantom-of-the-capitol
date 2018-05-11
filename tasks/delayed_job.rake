require File.expand_path("../../config/boot.rb", __FILE__)
require File.expand_path("../../app/helpers/colorize.rb", __FILE__)
require File.expand_path("../../app/helpers/delayed_job_helper.rb", __FILE__)

namespace :'phantom-dc' do
  namespace :'delayed_job' do
    desc "perform all fills on the Delayed::Job error_or_failure queue, captchad fills first, optionally provide bioguide regex, job id or activate recaptcha fills mode"
    task :perform_fills, :regex, :job_id, :overrides, :recaptcha_mode do |t, args|
      ActiveRecord::Base.logger.level = Logger::WARN

      regex = args[:regex].blank? ? nil : Regexp.compile(args[:regex])
      overrides = args[:overrides].blank? ? {} : eval(args[:overrides])

      jobs = retrieve_jobs args
      PerformFills.new(jobs, regex: regex, overrides: overrides).execute(args)
    end

    desc "override a field on the Delayed::Job error_or_failure queue, optionally provide bioguide regex or job id"
    task :override_field, :regex, :job_id, :overrides, :conditions do |t, args|
      regex = args[:regex].blank? ? nil : Regexp.compile(args[:regex])
      overrides = args[:overrides].blank? ? {} : eval(args[:overrides])
      conditions = args[:conditions].blank? ? {} : eval(args[:conditions])

      jobs = retrieve_jobs args

      cm_hash = CongressMember::to_hash CongressMember.all

      jobs.each do |job|
        cm_id, = DelayedJobHelper::congress_member_id_and_args_from_handler(job.handler)
        cm = CongressMember::retrieve_cached(cm_hash, cm_id)

        if regex.nil? or regex.match(cm.bioguide_id)
          handler = YAML.load job.handler
          if conditions.all?{ |k, v| handler.args[0][k] == v }
            handler.args[0] = handler.args[0].merge(overrides)
            job.handler = YAML.dump handler
            job.save
          end
        end
      end
    end

    desc "Display the number of queued jobs"
    task :count do
      count = Delayed::Job.count
      today_count = Delayed::Job.where("created_at >= ?", Time.now - 1.day).count
      message = "#{today_count} #{'job'.pluralize(today_count)} queued today, #{count} total"
      Raven.capture_message(message, level: "info")
      puts(count)
    end

    desc "destroy all fills on the Delayed::Job error_or_failure queue provided a specific bioguide or job_id"
    task :destroy_fills, :bioguide, :job_id do |t, args|
      cm = CongressMember.find_by(bioguide_id: args[:bioguide])

      jobs = retrieve_jobs args

      jobs.each do |job|
        cm_id, = DelayedJobHelper::congress_member_id_and_args_from_handler(job.handler)
        if not args[:job_id].nil? or cm_id.to_i == cm.id
          puts red("Destroying job #" + job.id.to_s)
          DelayedJobHelper::destroy_job_and_dependents job
        end
      end
    end

    desc "calculate # of jobs per member on the Delayed::Job error_or_failure queue"
    task :jobs_per_member do |t, args|
      cm_hash = CongressMember::to_hash CongressMember.all
      people = DelayedJobHelper::tabulate_jobs_by_member cm_hash

      captchad_hash = {}
      total_captchad_jobs = 0
      total_jobs = 0
      people.each do |k, v|
        if CongressMember.find_by(bioguide_id: k).has_captcha?
          captchad_hash[k] = true
          total_captchad_jobs += v
        end
        total_jobs += v
      end
      puts "The captcha'd congress members are displayed in red.\n\n"
      people.sort_by { |k, v| v}.reverse.each do |k, v|
        key_colored = captchad_hash[k] ? red(k) : k
        puts key_colored + ": " + v.to_s
      end
      puts "\nTotal jobs: "+total_jobs.to_s
      puts "Total captcha'd jobs: "+total_captchad_jobs.to_s
      puts "\nTotal members: "+people.length.to_s
      puts "Total captcha'd members: "+captchad_hash.length.to_s
    end

    desc "for error_or_failure jobs that have no zip4, look up the zip4, save, and retry"
    task :zip4_retry, :regex do |t, args|
      regex = args[:regex].blank? ? nil : Regexp.compile(args[:regex])

      jobs = Delayed::Job.where(queue: "error_or_failure")

      cm_hash = CongressMember::to_hash CongressMember.all

      non_zip4_jobs = []
      jobs.each do |job|
        cm_id, cm_args = DelayedJobHelper::congress_member_id_and_args_from_handler(job.handler)
        cm = CongressMember::retrieve_cached(cm_hash, cm_id)
        if regex.nil? or regex.match(cm.bioguide_id)
          if cm_args[0]['$ADDRESS_ZIP4'].nil?
            non_zip4_jobs.push job
          end
        end
      end
      puts "# of jobs without zip4: " + non_zip4_jobs.count.to_s
      non_zip4_jobs.each do |job|
        handler = YAML.load job.handler
        puts red("Job #" + job.id.to_s + ", bioguide " + handler.object.bioguide_id)
        begin
          locations = SmartyStreets.standardize do |l|
            l.street = handler.args[0]['$ADDRESS_STREET'] + ", " + handler.args[0]['$ADDRESS_ZIP5']
          end
          raise SmartyStreets::Request::NoValidCandidates if locations.empty?
          handler.args[0]['$ADDRESS_ZIP4'] = locations.first.components["plus4_code"]
        rescue SmartyStreets::Request::NoValidCandidates
          puts "Please enter the zip+4 for the following address:\n" + handler.args[0]['$ADDRESS_STREET'] + ", " + handler.args[0]['$ADDRESS_ZIP5']
          handler.args[0]['$ADDRESS_ZIP4'] = STDIN.gets.strip
        end
        job.handler = YAML.dump(handler)
        job.save
        begin
          FormFiller.new(handler.object, handler.args[0], handler.args[1]).fill_out_form do |img|
            puts img
            STDIN.gets.strip
          end
        rescue
        end
        DelayedJobHelper::destroy_job_and_dependents job
      end
    end

    desc "delete jobs that were generated during the fill_out_all rake task"
    task :delete_rake do |t, args|
      jobs = Delayed::Job.where(queue: "error_or_failure")
      jobs.each do |job|
        handler = YAML.load job.handler
        DelayedJobHelper::destroy_job_and_dependents(job) if handler.args[1] == "rake"
      end
    end

    desc "fix duplicate values of any field: choose the first one"
    task :fix_duplicates, :field, :regex do |t, args|
      regex = args[:regex].blank? ? nil : Regexp.compile(args[:regex])

      jobs = Delayed::Job.where(queue: "error_or_failure")

      cm_hash = CongressMember::to_hash CongressMember.all

      duplicate_jobs = []
      jobs.each do |job|
        cm_id, cm_args = DelayedJobHelper::congress_member_id_and_args_from_handler(job.handler)
        cm = CongressMember::retrieve_cached(cm_hash, cm_id)
        if regex.nil? or regex.match(cm.bioguide_id)
          field = cm_args[0][args[:field]]
          if field.is_a? Array
            duplicate_jobs.push job
          end
        end
      end
      puts "# of jobs with dubplicates: " + duplicate_jobs.count.to_s
      duplicate_jobs.each do |job|
        handler = YAML.load job.handler
        puts red("Fixing job #" + job.id.to_s + ", bioguide " + handler.object.bioguide_id)
        handler.args[0][args[:field]] = handler.args[0][args[:field]].first
        job.handler = YAML.dump(handler)
        job.save
      end
    end

    desc "deduplicate the job queue by legislator + message fields"
    task :deduplicate do |t|
      DeduplicateJobs.new(Delayed::Job.where(queue: "error_or_failure")).execute
    end
  end
end

def retrieve_jobs args
  job_id = args[:job_id].blank? ? nil : args[:job_id].to_i

  if job_id.nil?
    Delayed::Job.where(queue: "error_or_failure").order(created_at: :desc)
  else
    [Delayed::Job.find(job_id)]
  end
end
