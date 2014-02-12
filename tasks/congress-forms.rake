require File.expand_path("../../config/boot.rb", __FILE__)

namespace :'congress-forms' do
  desc "Maps the forms from their native YAML format into the db"
  task :map_forms, :contact_congress_directory do |t, args|

    DatabaseCleaner.strategy = :truncation, {:only => %w[congress_member_actions]}
    DatabaseCleaner.clean

    Dir[args[:contact_congress_directory]+'/members/*.yaml'].each do |f|
      begin
        congress_member_details = YAML.load_file(f)
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
      rescue Psych::SyntaxError => exception
        puts ""
        puts "File "+f+" could not be parsed"
        puts "  Problem: "+exception.problem
        puts "  Line:    "+exception.line.to_s
        puts "  Column:  "+exception.column.to_s
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
end

def create_action_add_to_member action, step, member
  cmf = CongressMemberAction.new(:action => action, :step => step)
  yield cmf
  cmf.congress_member = member
  cmf.save
end
