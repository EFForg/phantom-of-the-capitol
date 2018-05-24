CongressForms::App.helpers do

  # respond with an error if bio_id was not specified in params
  # else lookup congress member, exposed as @c
  # will respond with error if CongressMember not found
  def requires_bio_id params, retrieval_string
    return error_response("You must provide a bio_id to retrieve the #{retrieval_string}.") unless has_params("bio_id")

    @c = CongressMember.find_by(bioguide_id: params["bio_id"])
    halt 200, error_response("Congress member with provided bio id not found") if @c.nil?
  end

  def requires_job_id params, error_string
    return error_response("You must provide a delayed job id to #{error_string}.") unless has_params("job_id")
    job_id = params["job_id"]

    begin
      @job = Delayed::Job.find job_id
    rescue ActiveRecord::RecordNotFound
      halt 200, error_response("Job with provided id not found.") if @job.nil?
    end
  end

  def requires_date params, error_string
    return error_response("You must provide a date to #{error_string}.") unless has_params("date")
    @date = Time.zone.parse(params["date"])
  end

  def requires_uid_and_answer params, error_string
    msg = "You must provide a uid and answer to #{error_string}."
    halt 200, error_response(msg) unless has_params(["uid", "answer"])

    @uid = params["uid"]
    @answer = params["answer"]
  end

  private

  def error_response(message)
    { status: "error", message: message }.to_json
  end

  def has_params(required_params)
    required_params = [required_params].flatten # handle one param or a list
    required_params.all? {|p| params.include?(p) }
  end
end
