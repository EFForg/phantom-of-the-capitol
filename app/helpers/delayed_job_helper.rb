class DelayedJobHelper
  def self.find_by_bioguide bioguide_id
    members_jobs = []
    Delayed::Job.all.each do |job|
      handler = YAML.load job.handler
      if handler.object.bioguide_id == bioguide_id
        members_jobs.push job
      end
    end
    members_jobs
  end
end
