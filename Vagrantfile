# -*- mode: ruby -*-
# vi: set ft=ruby :
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2019
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

box = {
  :ubuntu => { :name => 'elastic/ubuntu-16.04-x86_64', :version=> '20180210.0.0' },
  :centos => { :name => 'centos/7', :version=> '1901.01' },
  :fedora => { :name => 'fedora/29-cloud-base', :version=> '29.20181024.1' },
  :opensuse => { :name => 'opensuse/openSUSE-42.1-x86_64', :version=> '1.0.0' },
  :clearlinux => { :name => 'AntonioMeireles/ClearLinux', :version=> '28510' }
}

require 'yaml'
pdf = File.dirname(__FILE__) + '/config/default.yml'
if File.exist?(File.dirname(__FILE__) + '/config/pdf.yml')
  pdf = File.dirname(__FILE__) + '/config/pdf.yml'
end
nodes = YAML.load_file(pdf)

pullSecret_content = ENV['OKD_PULL_SECRET'] || ""
# install-config.yaml file creation
File.open(File.dirname(__FILE__) + "/install-config.yaml", "w") do |install_config_file|
  install_config_file.puts("apiVersion: v1")
  install_config_file.puts("baseDomain: example.com") # The base domain of the cluster. All DNS records must be sub-domains of this base and include the cluster name.
  masters=0
  workers=0
  nodes.each do |node|
    if node['role'].include?("compute")
      workers+=1
    end
    if node['role'].include?("compute")
      masters+=1
    end
  end
  install_config_file.puts("compute:\n  - name: worker\n    replicas: #{workers}\n    platform: {}")
  install_config_file.puts("controlPlane:\n  hyperthreading: Enabled\n  name: master\n  replicas: #{masters}")
  install_config_file.puts("metadata:\n  name: test") # The cluster name that you specified in your DNS records.
  install_config_file.puts("networking:")
  install_config_file.puts("  clusterNetworks:")
  install_config_file.puts("  - cidr: 10.128.0.0/14") # A block of IP addresses from which Pod IP addresses are allocated.
  install_config_file.puts("    hostPrefix: 23") # The subnet prefix length to assign to each individual node.
  install_config_file.puts("  networkType: OpenShiftSDN")
  install_config_file.puts("  serviceNetwork:\n    - 172.30.0.0/16") # The IP address pool to use for service IP addresses.
  install_config_file.puts("platform:\n  none: {}")
  install_config_file.puts("pullSecret: '#{pullSecret_content}'") # The pull secret that you obtained from the OpenShift Infrastructure Providers page. This pull secret allows you to authenticate with the services that are provided by the included authorities, including Quay.io, which serves the container images for OpenShift Container Platform components.
  install_config_file.puts("sshKey:") # The public portion of the default SSH key for the core user in Red Hat Enterprise Linux CoreOS (RHCOS). 
end

if ENV['no_proxy'] != nil or ENV['NO_PROXY']
  $no_proxy = ENV['NO_PROXY'] || ENV['no_proxy'] || "127.0.0.1,localhost"
  $no_proxy += ",192.168.125.0/27,10.0.2.15,172.30.1.1"
end
socks_proxy = ENV['socks_proxy'] || ENV['SOCKS_PROXY'] || ""
distro = (ENV['OKD_DISTRO'] || :fedora).to_sym

Vagrant.configure("2") do |config|
  config.vm.provider :libvirt
  config.vm.provider :virtualbox

  config.vm.box = box[distro][:name]
  config.vm.box_version = box[distro][:version]
  config.vm.define :bootstrap, primary: true, autostart: false do |bootstrap|
    bootstrap.vm.provision 'shell', privileged: false do |sh|
      sh.env = {
        'SOCKS_PROXY': "#{socks_proxy}",
        'OKD_VERSION': "v3.11.0",
#        'OKD_VERSION': "v4.1.8",
#        'OKD_SOURCE': "source",
        'OKD_DEBUG': "true"
      }
      sh.inline = <<-SHELL
        cd /vagrant/
        ./postinstall.sh | tee okd_install.log
      SHELL
    end
  end

  nodes.each do |node|
    config.vm.define node['name'] do |nodeconfig|
      nodeconfig.vm.hostname = node['name']
      [:virtualbox, :libvirt].each do |provider|
        nodeconfig.vm.provider provider do |p, override|
          p.cpus = node['cpus']
          p.memory = node['memory']
        end
      end
    end
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
