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

  def self.congress_member_id_and_args_from_handler handler
    parser = Psych::Parser.new Psych::TreeBuilder.new
    parser.parse(handler)

    root_mapping = parser.handler.root.children[0].children[0]
    root_hash = self.hash_from_mapping(root_mapping)

    object_mapping = root_hash["object"]
    object_hash = self.hash_from_mapping(object_mapping)
    attributes_mapping = object_hash.include?("raw_attributes") ? object_hash["raw_attributes"] : object_hash["attributes"]
    id_scalar = self.hash_from_mapping(attributes_mapping)["id"]
    id = id_scalar.value

    args = root_hash["args"].to_ruby

    [id, args]
  end

  def self.tabulate_jobs_by_member jobs, cm_hash
    people = {}
    jobs.each do |job|
      cm_id, cm_args = self.congress_member_id_and_args_from_handler(job.handler)
      unless cm_args[1] == "rake"
        cm = CongressMember::retrieve_cached(cm_hash, cm_id)
        if people.keys.include? cm.bioguide_id
          people[cm.bioguide_id] += 1
        else
          people[cm.bioguide_id] = 1
        end
      end
    end
    people
  end

  def self.filter_jobs_by_member jobs, cm
    jobs.select do |job|
      cm_id, cm_args = self.congress_member_id_and_args_from_handler(job.handler)
      cm_id.to_i == cm.id && cm_args[1] != "rake"
    end
  end

  def self.destroy_job_and_dependents job
    begin
      FillStatusesJob.find_by(delayed_job_id: job.id).destroy
    rescue NoMethodError
    end
    job.destroy
  end

private
  def self.hash_from_mapping mapping
    children = mapping.children

    keys = children.values_at(* children.each_index.select{|i| i.even?}).map{|v| v.value}
    values = children.values_at(* children.each_index.select{|i| i.odd?})

    keys.zip(values).to_h
  end

end
