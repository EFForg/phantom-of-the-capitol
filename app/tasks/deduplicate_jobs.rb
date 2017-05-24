
class DeduplicateJobs
  attr_reader :jobs

  def initialize(jobs)
    @jobs = jobs
  end

  def execute
    sorted_jobs = jobs.sort_by{ |delayed_job| delayed_job.created_at }
    unique_jobs = sorted_jobs.uniq do |delayed_job|
      job = YAML.load(delayed_job.handler)
      [job.object.bioguide_id, job.args.first]
    end

    DelayedJobHelper.destroy_jobs_and_dependents(sorted_jobs - unique_jobs)
  end
end
