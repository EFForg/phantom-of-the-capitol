require "pp"

class PerformFills
  include CwcHelper

  attr_reader :jobs, :regex, :overrides

  def initialize(jobs, regex: nil, overrides: {})
    @jobs = jobs
    @regex = regex
    @overrides = overrides
  end

  def execute(args={})
    captcha_jobs, noncaptcha_jobs = filter_jobs

    queue = []
    queue.concat(captcha_jobs)
    queue.concat(noncaptcha_jobs)

    queue.each do |job|
      Raven::Context.clear!

      success = run_job(job) do |img|
        puts img
        STDIN.gets.strip
      end

      if success
        DelayedJobHelper::destroy_job_and_dependents job
      else
        Delayed::Job.increment_counter(:attempts, job)
        yield(job.reload) if block_given?
      end
    end
  end

  def run_job(job, &block)
    cm_id, cm_args = DelayedJobHelper::congress_member_id_and_args_from_handler(job.handler)
    cm = CongressMember::retrieve_cached(cm_hash, cm_id)

    fields, campaign_tag = cm_args[0].merge(overrides), cm_args[1]
    fields["$SUBJECT"] ||= fields["$MESSAGE"].truncate_words(13)

    if respond_to?(:preprocess_job) && preprocess_job(job, cm.bioguide_id, fields) == false
      return true
    end

    puts red("Job #" + job.id.to_s + ", bioguide " + cm.bioguide_id)
    pp [fields, campaign_tag]

    if cwc_member?(cm)
      begin
        fields["$ADDRESS_STATE_POSTAL_ABBREV"] ||= cm.state

        cm.message_via_cwc(fields, campaign_tag: campaign_tag)
      rescue Cwc::BadRequest => e
        warn("Cwc::BadRequest:")
        e.errors.each{ |error| warn("  * #{error}") }

        Raven.capture_message("Cwc::BadRequest: #{e.errors.last}",
                              tags: { "rake" => true },
                              extra: { bioguide: cm.bioguide_id,
                                       delayed_job_id: job.id,
                                       fields: fields,
                                       errors: e.errors })

        false
      end
    elsif RACK_ENV != "development"
      status = cm.fill_out_form(fields, cm_args[1], &block).success?

      unless status
        Raven.capture_message("Form error: #{cm.bioguide_id}",
                              tags: { "rake" => true, "form_error" => true },
                              extra: { delayed_job_id: job.id })
      end

      status
    end
  rescue => e
    Raven.capture_exception(e, tags: { "rake" => true },
                            extra: { delayed_job_id: job.id })
    return false
  end

  def cm_hash
    @cm_hash ||= CongressMember::to_hash CongressMember.all
  end

  def captcha_hash
    @captcha_hash ||=
      begin
        hash = {}
        CongressMemberAction.where(value: "$CAPTCHA_SOLUTION").each do |cma|
          hash[cma.congress_member_id] = true
        end
        hash
      end
  end

  def retrieve_captchad_cached(captcha_hash, cm_id)
    return captcha_hash[cm_id] if captcha_hash.include? cm_id
    return false
  end

  def captcha_member?(cm)
    !!retrieve_captchad_cached(captcha_hash, cm.id)
  end

  def cwc_member?(cm)
    cwc_office_supported?(cm.cwc_office_code)
  end

  def filter_jobs
    captcha_jobs, noncaptcha_jobs = [], []

    jobs.each do |job|
      cm_id, _ = DelayedJobHelper::congress_member_id_and_args_from_handler(job.handler)
      cm = CongressMember::retrieve_cached(cm_hash, cm_id)

      next unless regex.nil? or regex.match(cm.bioguide_id)

      if captcha_member?(cm)
        captcha_jobs.push(job)
      else
        noncaptcha_jobs.push(job)
      end
    end

    [captcha_jobs, noncaptcha_jobs]
  end
end
