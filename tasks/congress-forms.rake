require File.expand_path("../../config/boot.rb", __FILE__)

namespace :'congress-forms' do
  desc "Git"
  task :stuff do
    errors = 0
    Delayed::Job.all.each do |j|
      if YAML.load(j.handler).object.id == 24
        errors += 1
      end
    end
    successes = FillStatuses.find_all_by_congress_member_id(24).success.count

    puts "Errors " + errors.to_s
    puts "Successes " + successes.to_s
  end
  desc "Git pull, reload into db, and test for each member changed"
  task :update_git, :contact_congress_directory do |t, args|
    g = Git.open args[:contact_congress_directory]

    before_commit = g.log.first
    g.pull
    after_commit = g.log.first

    if before_commit.to_s == after_commit.to_s
      puts "Already at latest commit. Aborting!"
    else
      files_changed = g.diff(before_commit, after_commit).path('members/').map { |d| d.path }

      puts files_changed.count.to_s + " congress members form files have changed between commits " + before_commit.to_s + " and " + after_commit.to_s

      files_changed.each do |file_changed|
        f = args[:contact_congress_directory] + '/' + file_changed
        create_congress_member_exception_wrapper(f) do
          congress_member_details = YAML.load_file(f)
          bioguide = congress_member_details["bioguide"]
          CongressMember.find_or_create_by_bioguide_id(bioguide).actions.each { |a| a.destroy }
          create_congress_member_from_hash congress_member_details
          # mark as untested
        end
      end
    end
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
        f.write("| " + c.bioguide_id + " | [" + uri.host + "](" + uri.scheme + "://" + uri.host + ") | [![" + c.bioguide_id + " status](https://congress-forms.herokuapp.com/recent-fill-image/" + c.bioguide_id + ")](https://congress-forms.herokuapp.com/recent-fill-status/" + c.bioguide_id + ") |\n")
      end
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
      when "fill_in", "select", "click_on", "find", "check", "uncheck", "choose"  
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
