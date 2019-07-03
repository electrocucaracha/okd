# -*- mode: ruby -*-
# vi: set ft=ruby :

if ENV['no_proxy'] != nil or ENV['NO_PROXY']
  $no_proxy = ENV['NO_PROXY'] || ENV['no_proxy'] || "127.0.0.1,localhost"
  $no_proxy += ",192.168.125.0/27,10.0.2.15,172.30.1.1"
end
socks_proxy = ENV['socks_proxy'] || ENV['SOCKS_PROXY'] || ""

Vagrant.configure("2") do |config|
  config.vm.provider :libvirt
  config.vm.provider :virtualbox

  config.vm.box = "fedora/29-cloud-base"
  config.vm.provision 'shell', privileged: false do |sh|
    sh.env = { 
        'SOCKS_PROXY': "#{socks_proxy}",
    }   
    sh.inline = <<-SHELL
      cd /vagrant/
      ./postinstall.sh | tee install.log
    SHELL
  end 

  if ENV['http_proxy'] != nil and ENV['https_proxy'] != nil
    if not Vagrant.has_plugin?('vagrant-proxyconf')
      system 'vagrant plugin install vagrant-proxyconf'
      raise 'vagrant-proxyconf was installed but it requires to execute again'
    end
    config.proxy.http     = ENV['http_proxy'] || ENV['HTTP_PROXY'] || ""
    config.proxy.https    = ENV['https_proxy'] || ENV['HTTPS_PROXY'] || ""
    config.proxy.no_proxy = $no_proxy
    config.proxy.enabled = { docker: false }
  end

  [:virtualbox, :libvirt].each do |provider|
    config.vm.provider provider do |p, override|
      p.cpus = 4
      p.memory = 32768
    end
  end
  config.vm.provider 'libvirt' do |v, override|
    v.nested = true
    v.cpu_mode = 'host-passthrough'
    v.management_network_address = "192.168.125.0/27"
    v.management_network_name = "okd-mgmt-net"
    v.random_hostname = true
  end
end
