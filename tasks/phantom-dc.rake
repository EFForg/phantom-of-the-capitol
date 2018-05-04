require File.expand_path("../../config/boot.rb", __FILE__)
require File.expand_path("../../app/helpers/states.rb", __FILE__)

namespace :'phantom-dc' do
  desc "Git pull and reload changed CongressMember records into db"
  task :update_git do |t, args|

    DataSource.all.each do |ds|
      g = Git.open ds.path
      g.pull

      update_db_with_git_object g, ds
    end
  end

  desc "Update CWC office codes. Run once after switching to CWC delivery."
  task :update_cwc_codes do |t, args|
    CongressMember.all.each do |cm|
      if term = get_legislator_info(cm.bioguide_id)["terms"].try(:last)
        if term["type"] == "sen"
          cm.chamber = "senate"
          cm.senate_class = term["class"]
          cm.house_district = nil
        else
          cm.chamber = "house"
          cm.house_district = term["district"]
          cm.senate_class = nil
        end
        cm.state = term["state"]
        cm.save
      end
    end
  end

  desc "Reload CongressMember record into db given data source and bioguide regex"
  task :update_member, :data_source_name, :regex do |t, args|
    data_source = args[:data_source_name].blank? ? nil : DataSource.find_by_name(args[:data_source_name])
    cm = args[:regex].blank? ? [] : CongressMember.where("bioguide_id REGEXP '" + args[:regex].gsub("'","") + "'")

    cm.each do |c|
      f = data_source.path + '/' + data_source.yaml_subpath + '/' + c.bioguide_id + '.yaml'
      update_db_member_by_file f, data_source.prefix
    end
  end

  desc "Set updated at for congress members"
  task :updated_at, :regex, :time do |t, args|
    time = args[:time].blank? ? Time.now : eval(args[:time])

    cm = args[:regex].blank? ? CongressMember.all : CongressMember.where("bioguide_id REGEXP '" + args[:regex].gsub("'","") + "'")
    cm.each do |c|
      c.updated_at = time
      c.save
    end
  end

  desc "Analyze how common the expected values of fields are"
  task :common_fields do |t, args|
    values_hash = {}
    required_hash = {}
    congress_hash = {}

    all_members = CongressMember.all
    all_members.each do |c|
      congress_hash[c.bioguide_id] = {}
      c.actions.each do |a|
        if congress_hash[c.bioguide_id][a.value].nil? && a.value.to_s.start_with?("$")
          values_hash[a.value] = (values_hash[a.value].nil? ? 1 : values_hash[a.value] + 1)
          required_hash[a.value] = (required_hash[a.value].nil? ? 1 : required_hash[a.value] + 1) if a.required
          congress_hash[c.bioguide_id][a.value] = true
        end
      end
    end
    puts "Percent of congress members contact forms the common fields appear on:"
    puts "Format given as '$VAR_NAME : PERCENT_PRESENT (PERCENT_REQUIRED)\n\n"
    values_hash = values_hash.select{ |i, v| v >= all_members.count * 0.1 } # only show values that appear in >= 10% of congressmembers
    values_arr = values_hash.sort_by{|i, v| v}.reverse!
    values_arr.each do |v|
      appears_percent = v[1] * 100 / all_members.count
      required_percent = required_hash[v[0]] * 100 / all_members.count
      puts v[0] + " : " + appears_percent.to_s + "% (" + required_percent.to_s + "%)"
    end
  end

  desc "Run through filling out of all congress members"
  task :fill_out_all, :regex do |t, args|
    response = Typhoeus.get("https://raw.githubusercontent.com/EFForg/congress-zip-plus-four/master/legislators.json")
    congress_defaults = JSON.parse(response.body.gsub(/^define\(|\)$/, ''))

    response = Typhoeus.get("https://raw.githubusercontent.com/unitedstates/contact-congress/master/support/variables.yaml")
    defaults = YAML.load(response.body)

    possible_validation = {
      "$ADDRESS_STREET" => "example_address",
      "$ADDRESS_CITY" => "example_city",
      "$ADDRESS_STATE_POSTAL_ABBREV" => "example_state",
      "$ADDRESS_STATE_FULL" => "example_state"
    }

    captchad = []
    noncaptchad = []
    notfound = []

    cm = args[:regex].blank? ? CongressMember.all : CongressMember.where("bioguide_id REGEXP '" + args[:regex].gsub("'","") + "'")
    cm.each do |c|
      if congress_defaults.include? c.bioguide_id
        if !c.has_captcha?
          noncaptchad.push(c)
        else
          captchad.push(c)
        end
      else
        notfound.push(c.bioguide_id)
      end
    end

    (captchad + noncaptchad).each do |c|
      fields_hash = {}

      fields_hash["$ADDRESS_ZIP4"] = congress_defaults[c.bioguide_id]["zip4"] || defaults["$ADDRESS_ZIP4"]["example"]
      fields_hash["$ADDRESS_ZIP5"] = congress_defaults[c.bioguide_id]["zip5"] || defaults["$ADDRESS_ZIP5"]["example"]

      c.required_actions.each do |ra|
        if ra.value == "$ADDRESS_ZIP4" or ra.value == "$ADDRESS_ZIP5"
        elsif possible_validation.keys.include? ra.value
          if ra.value == "$ADDRESS_STATE_FULL"
            fields_hash[ra.value] = STATES[congress_defaults[c.bioguide_id][possible_validation[ra.value]]] || defaults[ra.value]["example"]
          else
            fields_hash[ra.value] = congress_defaults[c.bioguide_id][possible_validation[ra.value]] || defaults[ra.value]["example"]
          end
        elsif defaults.keys.include? ra.value
          if ra.options.nil?
            fields_hash[ra.value] = defaults[ra.value]["example"]
          else
            options = YAML.load(ra.options)
            values = options.is_a?(Hash) ? options.values : options
            fields_hash[ra.value] = values[Random.rand(values.length)]
          end
        end
      end
      begin
        c.fill_out_form fields_hash, "rake" do |c|
          puts "Please type in the value for the captcha at " + c + "\n"
          STDIN.gets.strip
        end
      rescue
      end
    end

    puts "No congressional defaults found for the following members: " + notfound.inspect
  end

  desc "Enable defunct status of congressmember"
  task :defunct, :bioguide_id, :contact_url do |t, args|
    cm = CongressMember.find_by!(bioguide_id: args[:bioguide_id])
    attrs = { defunct: true }
    attrs.merge!(contact_url: args[:contact_url]) if args[:contact_url]
    cm.update!(attrs)
  end

  desc "Disable defunct status of congressmember"
  task :undefunct, :bioguide_id do |t, args|
    cm = CongressMember.find_by!(bioguide_id: args[:bioguide_id])
    cm.update!(defunct: false, contact_url: nil)
  end
end

def update_db_with_git_object g, data_source
  current_commit = data_source.latest_commit

  new_commit = g.log.first.sha

  if current_commit == new_commit
    puts data_source.name + ": Already at latest commit. Aborting!"
  else
    if current_commit.nil?
      files_changed = Dir[data_source.path + '/' + data_source.yaml_subpath + '/*.yaml'].map { |d| d.sub(data_source.path, "") }
      puts data_source.name + "No previous commit found, reloading all congress members into db"
    else
      files_changed = g.diff(current_commit, new_commit).path(data_source.yaml_subpath).map { |d| d.path }
      puts files_changed.count.to_s + " congress members form files have changed between commits " + current_commit.to_s + " and " + new_commit
    end

    files_changed.each do |file_changed|
      f = data_source.path + '/' + file_changed
      update_db_member_by_file f, data_source.prefix
    end

    data_source.latest_commit = new_commit
    data_source.save
  end
end

def update_db_member_by_file f, prefix
  create_congress_member_exception_wrapper(f) do
    begin
      congress_member_details = YAML.load_file(f)
      bioguide = congress_member_details["bioguide"]
      congress_member_details.merge!(get_legislator_info(bioguide))
      CongressMember.find_or_create_by(bioguide_id: prefix + bioguide).actions.delete_all
      create_congress_member_from_hash congress_member_details, prefix
    rescue Errno::ENOENT
      puts "File " + f + " is missing, skipping..."
    rescue NoMethodError
      puts "File " + f + " does not have a bioguide defined, skipping..."
    end
  end
end

def create_congress_member_exception_wrapper file_path
  begin
    yield
  rescue Psych::SyntaxError => exception
    puts ""
    puts "File "+file_path+" could not be parsed"
    puts "  Problem: "+exception.problem
    puts "  Line:    "+exception.line.to_s
    puts "  Column:  "+exception.column.to_s
  end
end

def create_congress_member_from_hash congress_member_details, prefix
  bioguide_id = "#{prefix}#{congress_member_details["bioguide"]}"
  rep = CongressMember.find_or_create_by(bioguide_id: bioguide_id)
  step_increment = 0
  congress_member_details["contact_form"]["steps"].each do |s|
    action, value = s.first
    case action
    when "visit"
      create_action_add_to_member(action, step_increment += 1, rep) do |cmf|
        cmf.value = value
      end
    when "fill_in", "select", "click_on", "find", "check", "uncheck", "choose", "wait", "javascript", "recaptcha"
      value.each do |field|
        create_action_add_to_member(action, step_increment += 1, rep) do |cmf|
          field.each do |attribute|
            if cmf.attributes.keys.include? attribute[0]
              cmf.assign_attributes(attribute[0] => attribute[1])
            end
          end
        end
      end
    end
  end
  rep.success_criteria = congress_member_details["contact_form"]["success"]

  # Git updates shouldn't fail if we can't match a senate/house code from CWC, just let them proceed without it.
  # Very useful for custom forms.
  if term = get_legislator_info(rep.bioguide_id)["terms"].try(:last)
    if term["type"] == "sen"
      rep.chamber = "senate"
      rep.senate_class = term["class"]
      rep.house_district = nil
    else
      rep.chamber = "house"
      rep.house_district = term["district"]
      rep.senate_class = nil
    end
    rep.state = term["state"]
    rep.contact_url ||= term["contact_form"]
    rep.contact_url ||= term["url"]
  end
  rep.name = congress_member_details.dig("name", "last")
  rep.updated_at = Time.now
  rep.save
end

def create_action_add_to_member action, step, member
  cmf = CongressMemberAction.new(:action => action, :step => step)
  yield cmf
  cmf.congress_member = member
  cmf.save
end

def get_legislator_info(bioguide_id)
  @legislator_info ||=
    begin
      url = "https://raw.githubusercontent.com/unitedstates/congress-legislators/master/legislators-current.yaml"
      info = YAML.load(RestClient.get(url)).map{ |i| [i["id"]["bioguide"], i] }.to_h

      url = "https://raw.githubusercontent.com/unitedstates/congress-legislators/master/legislators-historical.yaml"
      historical_info = YAML.load(RestClient.get(url)).
                        select{ |i| i["terms"][-1]["start"] > "2010-01-01" }.
                        map{ |i| [i["id"]["bioguide"], i] }.to_h
      info.merge!(historical_info)
    end

  # defaults to empty so it won't break if it fails to match the member to CWC data
  @legislator_info.fetch(bioguide_id, {})
end
