class AddDelayedJobIdColumnToFillStatus < ActiveRecord::Migration
  def self.up
    add_column :fill_statuses, :delayed_job_id, :integer

    FillStatus.error_or_failure.each do |fs|
      extra = YAML.load fs.extra
      delayed_job_id = extra[:delayed_job_id]
      begin
        job = Delayed::Job.find(delayed_job_id)
        fs.delayed_job_id = job.id
        fs.save
      rescue ActiveRecord::RecordNotFound
      end
    end
  end

  def self.down
    remove_column :fill_statuses, :delayed_job_id
  end
end
