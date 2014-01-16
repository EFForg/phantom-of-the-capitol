namespace :'congress-forms' do
  desc "Maps the forms from their native YAML format into the db"
  task :map_forms, :contact_congress_yaml_directory do |t, args|
    require File.expand_path("../../config/boot.rb", __FILE__)
    Dir[args[:contact_congress_yaml_directory]+'/*.yaml'].each do |f|
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
        end
      rescue Psych::SyntaxError => exception
        puts ""
        puts "File "+f+" could not be parsed"
        puts "  Problem: "+exception.problem
        puts "  Line:    "+exception.line.to_s
        puts "  Column:  "+exception.column.to_s
      end
    end
  end
end

def create_action_add_to_member action, step, member
  cmf = CongressMemberAction.new(:action => action, :step => step)
  yield cmf
  cmf.congress_member = member
  cmf.save
end
