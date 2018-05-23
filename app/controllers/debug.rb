require 'securerandom'
include DelayedJobHelper

CongressForms::App.controller do

  before do
    content_type :json

    response.headers['X-Backend-Hostname'] = Socket.gethostname
    halt 401, error_response("You must provide a valid debug key to access this endpoint.") unless params.include? "debug_key" and params["debug_key"] == DEBUG_KEY
  end

  before :'successful-fills-by-hour', :'successful-fills-by-date', :'successful-fills-by-member/' do
    set_campaign_tag_params params
  end

  # For some reason, this is necessary.  See https://stackoverflow.com/questions/24356385/setting-up-time-zone-in-padrino
  before :'successful-fills-by-hour', :'successful-fills-by-date' do
    set_time_zone
  end

  get :'recent-statuses-detailed/:bio_id' do
    requires_bio_id params, "most recent status"

    if params.include? "all_statuses"
      statuses = @c.fill_statuses.order(:updated_at).reverse
    else
      statuses = @c.recent_fill_statuses.order(:updated_at).reverse
    end

    statuses_arr = []
    statuses.each do |s|
      if s.status == 'error' or s.status == 'failure'
        begin
          extra = YAML.load(s.extra)
          status_hash = {id: s.id, status: s.status, run_at: s.updated_at, dj_id: s.delayed_job.id}
          status_hash[:screenshot] = extra[:screenshot] if extra.include? :screenshot
        rescue
          status_hash = {id: s.id, status: s.status, run_at: s.updated_at}
        end
      elsif s.status == 'success'
        status_hash = {id: s.id, status: s.status, run_at: s.updated_at}
      end
      statuses_arr.push(status_hash)
    end
    statuses_arr.to_json
  end

  get :'list-actions/:bio_id' do
    requires_bio_id params, "list of actions"
    {last_updated: @c.updated_at, actions: @c.actions}.to_json
  end

  get :'list-congress-members' do
    reps_ordered = CongressMember.order(:bioguide_id)
    jobs_by_rep = tabulate_jobs_by_member(
      CongressMember.to_hash(reps_ordered)
    )

    reps_ordered.map do |rep|
      hash = { "bioguide_id" => rep.bioguide_id }
      jobs_count = jobs_by_rep.find { |id, count| id == rep.bioguide_id }.try(:last)
      hash["jobs"] = jobs_count if jobs_count
      hash
    end.to_json
  end

  get :'successful-fills-by-date', map: %r{/successful-fills-by-date/([\w]*)} do
    bio_id = params[:captures].first

    date_start = params.include?("date_start") ? Time.zone.parse(params["date_start"]) : nil
    date_end = params.include?("date_end") ? Time.zone.parse(params["date_end"]) : nil

    if bio_id.blank?
      @statuses = FillStatus
    else
      @statuses = CongressMember.find_by(bioguide_id: bio_id).fill_statuses
    end

    @statuses = @statuses.where('created_at >= ?', date_start) unless date_start.nil?
    @statuses = @statuses.where('created_at < ?', date_end) unless date_end.nil?

    filter_by_campaign_tag

    options = {}
    options[:time_zone] = params["time_zone"] if params.include?("time_zone")
    options[:format] = '%Y-%m-%d 00:00:00 UTC' if params.include?("give_as_utc") and params["give_as_utc"] == "true"

    @statuses.success.group_by_day(:created_at, options).count.to_json
  end

  get :'successful-fills-by-hour', map: %r{/successful-fills-by-hour/([\w]*)} do
    bio_id = params[:captures].first

    requires_date params, "retrieve successful fills by hour"

    if bio_id.blank?
      @statuses = FillStatus
    else
      @statuses = CongressMember.find_by(bioguide_id: bio_id).fill_statuses
    end

    @statuses = @statuses.where('created_at >= ?', @date)
    @statuses = @statuses.where('created_at < ?', @date + 1.day)

    filter_by_campaign_tag

    options = {}
    options[:time_zone] = params["time_zone"] if params.include?("time_zone")
    options[:format] = '%Y-%m-%d %H:%M:00 UTC' if params.include?("give_as_utc") and params["give_as_utc"] == "true"

    @statuses.success.group_by_hour(:created_at, options).count.to_json
  end

  get :'successful-fills-by-member/' do
    @statuses = FillStatus
    filter_by_campaign_tag

    member_id_mapping = {}
    member_hash = {}
    @statuses.success.each do |s|
      unless member_id_mapping.include? s.congress_member_id
        member_id_mapping[s.congress_member_id] = s.congress_member.bioguide_id
      end
      bioguide = member_id_mapping[s.congress_member_id]

      member_hash[bioguide] = 0 unless member_hash.include? bioguide
      member_hash[bioguide] += 1
    end

    member_hash.to_json
  end

  get :'job-details/:job_id' do
    requires_job_id params, "retrieve job details"
    id, args = congress_member_id_and_args_from_handler @job.handler
    bioguide = CongressMember.find(id).bioguide_id
    { arguments: args, bioguide: bioguide }.to_json
  end

  put :'job-details/:job_id' do
    error_string = "modify job details"
    requires_job_id params, error_string
    return error_response("You must provide arguments to #{error_string}.") unless has_params("arguments")

    handler = YAML.load(@job.handler)
    handler.args = params['arguments']
    @job.handler = YAML.dump(handler)

    @job.save

    { status: "success" }.to_json
  end

  delete :'job-details/:job_id' do
    requires_job_id params, "retrieve job details"

    destroy_job_and_dependents @job

    { status: "success" }.to_json
  end

  options :'job-details/:job_id' do
    {}.to_json
  end

  post :'batch-job-save/:bio_id' do
    error_string = "batch save jobs"
    requires_bio_id params, error_string
    return error_response("You must provide a delayed job id to #{error_string}.") unless has_params(["if_arguments", "then_arguments"])

    if_arguments = JSON.parse(params["if_arguments"])
    then_arguments = JSON.parse(params["then_arguments"])

    @c.fill_statuses.joins(:delayed_job).order(created_at: :desc).each do |f|
      job = f.delayed_job
      match = true
      cm_id, job_args = congress_member_id_and_args_from_handler(job.handler)
      if_arguments.each.with_index do |arg, arg_i|
        if arg.is_a? Hash
          arg.each do |field_i, field|
            unless job_args[arg_i].include? field_i and job_args[arg_i][field_i] == field
              match = false
              break
            end
          end
        else
          unless job_args.length - 1 >= arg_i and job_args[arg_i] == arg
            match = false
            break
          end
        end
      end
      if match
        then_arguments.each.with_index do |arg, arg_i|
          if arg.is_a? Hash
            arg.each do |field_i, field|
              job_args[arg_i][field_i] = field
            end
          else
            job_args[arg_i] = arg
          end
        end

        handler = YAML.load(job.handler)
        handler.args = job_args
        job.handler = YAML.dump(handler)
        job.save
      end
    end

    { status: "success" }.to_json
  end

  get :'perform-job/:job_id' do
    requires_job_id params, "peform job"

    id, args = congress_member_id_and_args_from_handler @job.handler
    cm = CongressMember.find(id)
    fill_handler = FillHandler.new(cm, args[0], args[1], true)

    destroy_job_and_dependents @job

    result = fill_handler.fill
    result[:uid] = SecureRandom.hex
    debug_captcha_record[result[:uid]] = fill_handler if result[:status] == "captcha_needed"
    result.to_json
  end

  post :'perform-job-captcha/:uid' do
    requires_uid_and_answer params, "fill out captcha"

    return error_response("The unique id provided was not found.") unless debug_captcha_record.include? @uid

    result = debug_captcha_record[@uid].fill_captcha @answer
    debug_captcha_record.delete(@uid) if result[:status] != "captcha_needed"
    result.to_json
  end

  get :'list-jobs/:bio_id' do
    requires_bio_id params, "list of jobs"

    jobs = []
    @c.fill_statuses.joins(:delayed_job).order(created_at: :desc).each do |f|
      jobs << (f.delayed_job.as_json only: [:id, :created_at, :updated_at, :last_error])
    end
    jobs.to_json
  end

  private

  define_method :set_campaign_tag_params do |params|
    if params.include? "campaign_tag"
      ct = CampaignTag.find_by_name(params["campaign_tag"])
      @ct_id = ct.nil? ? -1 : ct.id
    else
      @ct_id = nil
    end

    if @ct_id.nil?
      rake_ct = CampaignTag.find_by_name("rake")
      @rake_ct_id = rake_ct.nil? ? -1 : rake_ct.id
    end
  end

  define_method :set_time_zone do
    Time.zone = TIME_ZONE
  end

  define_method :filter_by_campaign_tag do
    if @ct_id.nil?
      @statuses = @statuses.where('campaign_tag_id != ? OR campaign_tag_id IS NULL', @rake_ct_id.to_s)
    else
      @statuses = @statuses.where(campaign_tag_id: @ct_id)
    end
  end

  define_method :debug_captcha_record do
    @debug_captcha_record ||= CaptchaCache.current
  end
end
