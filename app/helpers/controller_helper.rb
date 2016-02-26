CongressForms::App.helpers do

  # respond with an error if bio_id was not specified in params
  # else lookup congress member, exposed as @c
  # will respond with error if CongressMember not found
  def requires_bio_id params, retrieval_string
    return {status: "error", message: "You must provide a bio_id to retrieve the " + retrieval_string + "."}.to_json unless params.include? "bio_id"

    bio_id = params["bio_id"]

    @c = CongressMember.bioguide(bio_id)
    halt 200, {status: "error", message: "Congress member with provided bio id not found"}.to_json if @c.nil?
  end

  def requires_job_id params, error_string
    return {status: "error", message: "You must provide a delayed job id to " + error_string + "."}.to_json unless params.include? "job_id"

    job_id = params["job_id"]

    begin
      @job = Delayed::Job.find job_id
    rescue ActiveRecord::RecordNotFound
      halt 200, {status: "error", message: "Job with provided id not found."}.to_json if @job.nil?
    end
  end

  def requires_date params, error_string
    return {status: "error", message: "You must provide a date to " + error_string + "."}.to_json unless params.include? "date"
    @date = Time.zone.parse(params["date"])
  end

  def requires_arguments params, error_string
    return {status: "error", message: "You must provide arguments to " + error_string + "."}.to_json unless params.include? "arguments"
  end

  def requires_uid_and_answer params, error_string
    halt 200, {status: "error", message: "You must provide a uid and answer to " + error_string + "."}.to_json unless params.include? "uid" and params.include? "answer"
    @uid = params["uid"]
    @answer = params["answer"]
  end
end
