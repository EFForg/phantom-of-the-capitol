require 'aws-sdk'

ami_id = ARGV[0]
environment = ""
unless ARGV[1].nil? || ARGV[1].empty?
	environment = "-#{ARGV[1]}"
end 
launch_config_name = "congress-forms#{environment} #{Time.now.to_i}"

auto_scaling = AWS::AutoScaling.new

auto_scaling.launch_configurations.create(launch_config_name, 
                                          ami_id,
                                          "m1.small",
                                          :security_groups =>
                                            ['sg-b21081d7'],
                                          :key_pair => 'congress-forms')
congress_forms_group = auto_scaling.groups["congress-forms#{environment}"]
old_launch_configuration = congress_forms_group.launch_configuration
old_ami = old_launch_configuration.image_id

congress_forms_group.update(:launch_configuration => 
                                             launch_config_name)

old_launch_configuration.delete

congress_forms_group.ec2_instances.each do |instance|
  if instance.image_id == old_ami
    puts "removing #{instance.id}"
    instance.terminate
    puts "waiting for #{instance.id} to terminate"
    sleep 10 while instance.status != :terminated
  end
end
