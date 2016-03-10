# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.ssh.forward_agent = true
  config.vm.box = "ubuntu-trusty"
  config.vm.box_url = "https://oss-binaries.phusionpassenger.com/vagrant/boxes/latest/ubuntu-14.04-amd64-vbox.box"
  config.vm.network :private_network, ip: "192.168.33.5"
  config.vm.synced_folder  "../", "/srv/src"
  config.vm.provision :shell, path: "vagrant/provision.sh"
end