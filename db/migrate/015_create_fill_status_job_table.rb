class CreateFillStatusJobTable < ActiveRecord::Migration
  def self.up
    create_table :fill_statuses_jobs do |t|
      t.integer  :fill_status_id
      t.integer  :delayed_job_id
    end

    add_index(:fill_statuses_jobs, [:fill_status_id, :delayed_job_id], :unique => true)

    FillStatus.error_or_failure.each do |fs|
      extra = YAML.load fs.extra
      delayed_job_id = extra[:delayed_job_id]
      begin
        job = Delayed::Job.find(delayed_job_id)
        FillStatusesJob.create(fill_status_id: fs.id, delayed_job_id: job.id)
      rescue ActiveRecord::RecordNotFound
      end
    end

  end

  def self.down
    drop_table :fill_statuses_jobs
  end
end
