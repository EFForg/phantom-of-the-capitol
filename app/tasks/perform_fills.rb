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
    recaptcha_jobs, captcha_jobs, noncaptcha_jobs = filter_jobs

    queue = []

    if args[:recaptcha_mode].present?
      queue.concat(recaptcha_jobs)
    else
      queue.concat(captcha_jobs)
      queue.concat(noncaptcha_jobs)
    end

    queue.each do |job|
      success = run_job(job) do |img|
        puts img
        STDIN.gets.strip
      end

      if success
        DelayedJobHelper::destroy_job_and_dependents job
      end
    end
  end

  def run_job(job, &block)
    cm_id, cm_args = DelayedJobHelper::congress_member_id_and_args_from_handler(job.handler)
    cm = CongressMember::retrieve_cached(cm_hash, cm_id)

    puts red("Job #" + job.id.to_s + ", bioguide " + cm.bioguide_id)
    pp cm_args

    fields, campaign_tag = cm_args[0].merge(overrides), cm_args[1]

    if cwc_member?(cm)
      begin
        fields["$SUBJECT"] ||= fields["$MESSAGE"].truncate_words(13)
        fields["$ADDRESS_STATE_POSTAL_ABBREV"] ||= cm.state

        cm.message_via_cwc(fields, campaign_tag: campaign_tag)
      rescue Cwc::BadRequest => e
        warn("Cwc::BadRequest:")
        e.errors.each{ |error| warn("  * #{error}") }
        false
      end
    elsif recaptcha_member?(cm) && RACK_ENV != "development"
      cm.fill_out_form_with_watir(cm_args[0].merge(overrides), &block)[:success]
    elsif RACK_ENV != "development"
      cm.fill_out_form(cm_args[0].merge(overrides), cm_args[1], &block).success?
    end
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

  def recaptcha_hash
    @recaptcha_hash ||=
      begin
        hash = {}
        CongressMemberAction.where(action: "recaptcha").each do |cma|
          hash[cma.congress_member_id] = true
        end
        hash
      end
  end

  def retrieve_captchad_cached(captcha_hash, cm_id)
    return captcha_hash[cm_id] if captcha_hash.include? cm_id
    return false
  end

  def recaptcha_member?(cm)
    !!retrieve_captchad_cached(recaptcha_hash, cm.id)
  end

  def captcha_member?(cm)
    !!retrieve_captchad_cached(captcha_hash, cm.id)
  end

  def cwc_member?(cm)
    cwc_office_supported?(cm.cwc_office_code)
  end

  def filter_jobs
    recaptcha_jobs, captcha_jobs, noncaptcha_jobs = [], [], []

    jobs.each do |job|
      cm_id, _ = DelayedJobHelper::congress_member_id_and_args_from_handler(job.handler)
      cm = CongressMember::retrieve_cached(cm_hash, cm_id)

      next unless regex.nil? or regex.match(cm.bioguide_id)

      if recaptcha_member?(cm)
        recaptcha_jobs.push(job)
      elsif captcha_member?(cm)
        captcha_jobs.push(job)
      else
        noncaptcha_jobs.push(job)
      end
    end

    [recaptcha_jobs, captcha_jobs, noncaptcha_jobs]
  end
end
