class DelayedJobHelper
  class << self
    def congress_member_id_and_args_from_handler handler
      parser = Psych::Parser.new Psych::TreeBuilder.new
      parser.parse(handler)

      root_mapping = parser.handler.root.children[0].children[0]
      root_hash = hash_from_mapping(root_mapping)

      object_mapping = root_hash["object"]
      object_hash = hash_from_mapping(object_mapping)
      congress_member_hash = hash_from_mapping(object_hash["rep"])

      attributes_mapping = if congress_member_hash.include?("raw_attributes")
        congress_member_hash["raw_attributes"]
      else
        congress_member_hash["attributes"]
      end

      id_scalar = hash_from_mapping(attributes_mapping)["id"]
      id = id_scalar.value

      args = [
        object_hash["fields"].to_ruby, object_hash["campaign_tag"].to_ruby
      ].flatten

      [id, args]
    end

    def tabulate_jobs_by_member cm_hash
      people = Hash.new(0)

      Delayed::Job.where(queue: "error_or_failure").each do |job|
        cm_id, cm_args = congress_member_id_and_args_from_handler(job.handler)
        next if cm_args[1] == "rake"

        cm = CongressMember::retrieve_cached(cm_hash, cm_id)
        people[cm.bioguide_id] += 1
      end

      people
    end

    def destroy_job_and_dependents job
      FillStatusesJob.find_by(delayed_job_id: job.id).try(:destroy)
      job.destroy
    end

    def destroy_jobs_and_dependents jobs
      ids = jobs.map(&:id)
      FillStatusesJob.where(delayed_job_id: ids).delete_all
      Delayed::Job.where(id: ids).delete_all
    end

  private
    def hash_from_mapping mapping
      children = mapping.children

      keys = children.values_at(* children.each_index.select{|i| i.even?}).map{|v| v.value}
      values = children.values_at(* children.each_index.select{|i| i.odd?})

      keys.zip(values).to_h
    end

  end
end
