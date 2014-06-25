require File.expand_path("../../config/boot.rb", __FILE__)
require File.expand_path("../../app/helpers/states.rb", __FILE__)

namespace :'congress-forms' do
  desc "Git clone the contact congress repo and load records into the db"
  task :clone_git, :repo do |t, args|
    if not args[:repo].nil?
      repository = args[:repo]
    else
      repository = "unitedstates/contact-congress"
    end
    URI = "https://github.com/#{repository}.git"
    NAME = "contact-congress"
    g = Git.clone(URI, NAME, :path => '/tmp/')

    update_db_with_git_object g, "/tmp/contact-congress"
  end
  desc "Git pull and reload changed CongressMember records into db"
  task :update_git, :contact_congress_directory do |t, args|
    g = Git.open args[:contact_congress_directory]
    g.pull

    update_db_with_git_object g, args[:contact_congress_directory]
  end
  desc "Maps the forms from their native YAML format into the db"
  task :map_forms, :contact_congress_directory do |t, args|

    DatabaseCleaner.strategy = :truncation, {:only => %w[congress_member_actions]}
    DatabaseCleaner.clean

    Dir[args[:contact_congress_directory]+'/members/*.yaml'].each do |f|
      create_congress_member_exception_wrapper(f) do
        congress_member_details = YAML.load_file(f)
        create_congress_member_from_hash congress_member_details
      end
    end
    constants = YAML.load_file(args[:contact_congress_directory]+'/support/constants.yaml')
    File.open(File.expand_path("../../config/constants.rb", __FILE__), 'w') do |f|
      f.write "CONSTANTS = "
      f.write constants
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
  desc "Generate a markdown file for the recent fill status of all congress members in the database"
  task :generate_status_markdown, :file do |t, args|
    File.open args[:file], 'w' do |f|
      f.write("| Bioguide ID | Website | Recent Success Rate |\n")
      f.write("|-------------|---------|:------------:|\n")
      CongressMember.order(:bioguide_id).each do |c|
        uri = URI(c.actions.where(action: "visit").first.value)
        f.write("| " + c.bioguide_id + " | [" + uri.host + "](" + uri.scheme + "://" + uri.host + ") | [![" + c.bioguide_id + " status](http://ec2-54-215-28-56.us-west-1.compute.amazonaws.com:3000/recent-fill-image/" + c.bioguide_id + ")](http://ec2-54-215-28-56.us-west-1.compute.amazonaws.com:3000/recent-fill-status/" + c.bioguide_id + ") |\n")
      end
    end
  end
  desc "Run through filling out of all congress members"
  task :fill_out_all, :regex do |t, args|
    response = Typhoeus.get("https://raw.githubusercontent.com/sinak/congress-zip-plus-four/master/legislators.json")
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

    CongressMember.where("bioguide_id REGEXP '" + args[:regex].gsub("'","") + "'").each do |c|
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

            #if values.include? defaults[ra.value]["example"]
              #fields_hash[ra.value] = defaults[ra.value]["example"]
            #else

            fields_hash[ra.value] = values[Random.rand(values.length)]

            #end
          end
        end
      end
      begin
        c.fill_out_form fields_hash do |c|
          puts "Please type in the value for the captcha at " + c + "\n"
          STDIN.gets.strip
        end
      rescue
      end
    end

    puts "No congressional defaults found for the following members: " + notfound.inspect
  end
end

def update_db_with_git_object g, contact_congress_directory
    current_commit = Application.contact_congress_commit

    new_commit = g.log.first.to_s

    if current_commit == new_commit
      puts "Already at latest commit. Aborting!"
    else
      if current_commit.nil?
        files_changed = Dir[contact_congress_directory+'/members/*.yaml'].map { |d| d.sub(contact_congress_directory, "") }
        puts "No previous commit found, reloading all congress members into db"
      else
        files_changed = g.diff(current_commit, new_commit).path('members/').map { |d| d.path }
        puts files_changed.count.to_s + " congress members form files have changed between commits " + current_commit.to_s + " and " + new_commit
      end


      files_changed.each do |file_changed|
        f = contact_congress_directory + '/' + file_changed
        create_congress_member_exception_wrapper(f) do
          begin
            congress_member_details = YAML.load_file(f)
            bioguide = congress_member_details["bioguide"]
            CongressMember.find_or_create_by_bioguide_id(bioguide).actions.each { |a| a.destroy }
            create_congress_member_from_hash congress_member_details
          rescue Errno::ENOENT
            puts "File " + f + " is missing, skipping..."
          end
        end
      end
      
      Application.contact_congress_commit = new_commit
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


def create_congress_member_from_hash congress_member_details
  CongressMember.with_new_or_existing_bioguide(congress_member_details["bioguide"]) do |c|
    step_increment = 0
    congress_member_details["contact_form"]["steps"].each do |s|
      action, value = s.first
      case action
      when "visit"
        create_action_add_to_member(action, step_increment += 1, c) do |cmf|
          cmf.value = value
        end
      when "fill_in", "select", "click_on", "find", "check", "uncheck", "choose", "wait"
        value.each do |field|
          create_action_add_to_member(action, step_increment += 1, c) do |cmf|
            field.each do |attribute|
              if cmf.attributes.keys.include? attribute[0]
                cmf.update_attribute(attribute[0], attribute[1])
              end
            end
          end
        end
      end
    end
    c.success_criteria = congress_member_details["contact_form"]["success"]
    c.save
  end
end

def create_action_add_to_member action, step, member
  cmf = CongressMemberAction.new(:action => action, :step => step)
  yield cmf
  cmf.congress_member = member
  cmf.save
end
