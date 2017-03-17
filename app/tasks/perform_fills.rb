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

    if args[:recaptcha_mode].present?
      recaptcha_jobs.each do |job|
        run_job(job)
        DelayedJobHelper::destroy_job_and_dependents job
      end
      return
    end

    captcha_jobs.each do |job|
      run_job(job) do |img|
        puts img
        STDIN.gets.strip
      end
      DelayedJobHelper::destroy_job_and_dependents job
    end

    noncaptcha_jobs.each do |job|
      run_job(job)
      DelayedJobHelper::destroy_job_and_dependents job
    end
  end

  def run_job(job, &block)
    cm_id, cm_args = DelayedJobHelper::congress_member_id_and_args_from_handler(job.handler)
    cm = CongressMember::retrieve_cached(cm_hash, cm_id)

    puts red("Job #" + job.id.to_s + ", bioguide " + cm.bioguide_id)
    pp cm_args

    if recaptcha_member?(cm)
      cm.fill_out_form_with_watir cm_args[0].merge(overrides), &block
    elsif cwc_member?(cm)
      cm.message_via_cwc(cm_args[0].merge(overrides), campaign_tag: cm_args[1])
    else
      cm.fill_out_form cm_args[0].merge(overrides), cm_args[1], &block
    end
  rescue
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
