# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.define :ec2 do |ec2_config|
    ec2_config.vm.box = "dummy"
    ec2_config.vm.box_url = "https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box"
    ec2_config.vm.provider :aws do |aws, override|
      aws.access_key_id = ENV['AWS_ACCESS_KEY']
      aws.secret_access_key = ENV['AWS_SECRET_KEY']
      aws.keypair_name = "congress-forms"
      aws.ami = "ami-36b9705e"
      aws.security_groups = "congress-forms"
      aws.instance_type = "m1.small"

      override.ssh.username = "ubuntu"
      override.ssh.private_key_path = "~/.ssh/congressforms.pem"
    end
    ec2_config.vm.provision :shell, :path => "setup_dev.sh", :args => "ubuntu"
    ec2_config.vm.provision :shell, :path => "./packer_deployment/service_setup.sh"
  end

  config.vm.define :ec2janecasey do |ec2_config|
    ec2_config.vm.box = "dummy"
    ec2_config.vm.box_url = "https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box"
    ec2_config.vm.provider :aws do |aws, override|
      aws.access_key_id = ENV['AWS_ACCESS_KEY']
      aws.secret_access_key = ENV['AWS_SECRET_KEY']
      aws.keypair_name = "congress-forms"
      aws.ami = "ami-b08b6cd8"
      aws.security_groups = "congress-forms"
      aws.instance_type = "m1.small"

      override.ssh.username = "ubuntu"
      override.ssh.private_key_path = "~/.ssh/congressforms.pem"
    end
    ec2_config.vm.provision :shell, :path => "setup_dev.sh", :args => "ubuntu ngpvan/jane-caseys-congress-form"
    ec2_config.vm.provision :shell, :path => "./packer_deployment/service_setup.sh"
  end

  config.vm.define :local do |local_config|
    local_config.vm.box = "precise64"
    local_config.vm.box_url = "http://files.vagrantup.com/precise64.box"
    local_config.vm.provision :shell, :path => "setup_dev.sh", :args => "vagrant"
    local_config.vm.network "forwarded_port", guest: 9292, host: 9292
  end
end
