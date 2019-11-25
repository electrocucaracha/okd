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

pullSecret_content = ENV['OPENSHIFT_PULL_SECRET'] || ""
# install-config.yaml file creation
File.open(File.dirname(__FILE__) + "/install-config.yaml", "w") do |install_config_file|
  install_config_file.puts("apiVersion: v1")
  install_config_file.puts("baseDomain: example.com") # The base domain of the cluster. All DNS records must be sub-domains of this base and include the cluster name.
  masters=0
  workers=0
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

$no_proxy = ENV['NO_PROXY'] || ENV['no_proxy'] || "127.0.0.1,localhost"
# NOTE: This range is based on vagrant-libvirt network definition CIDR 192.168.121.0/24
(1..254).each do |i|
  $no_proxy += ",192.168.121.#{i}"
end
$no_proxy += ",10.0.2.15,172.30.1.1"
$socks_proxy = ENV['socks_proxy'] || ENV['SOCKS_PROXY'] || ""
$is_qat_enabled = ENV['OKD_ENABLE_QAT'] || "false"

Vagrant.configure("2") do |config|
  config.vm.provider :libvirt
  config.vm.provider :virtualbox

  config.vm.box = "centos/7"
  config.vm.box_version = "1901.01"
  # Upgrade Kernel version
  config.vm.provision 'shell', privileged: false, inline: <<-SHELL
    PKG_MANAGER=$(command -v dnf || command -v yum)
    INSTALLER_CMD="sudo -H -E ${PKG_MANAGER} -q -y install"
    if ! sudo "$PKG_MANAGER" repolist | grep "epel/"; then
        $INSTALLER_CMD epel-release
    fi
    sudo "$PKG_MANAGER" updateinfo
    $INSTALLER_CMD kernel
    sudo grub2-set-default 0
    sudo grub2-mkconfig -o "$(sudo readlink -f /etc/grub2.cfg)"
  SHELL
  config.vm.provision :reload
  config.vm.provision 'shell', privileged: false do |sh|
    sh.env = {
      'DEBUG': "true",
      'SOCKS_PROXY': "#{$socks_proxy}",
      'QAT_ENABLED': "#{$is_qat_enabled}"
    }
    sh.inline = <<-SHELL
      cd /vagrant/
      if [[ "${OPENSHIFT_DEPLOYMENT_TYPE:-okd}" == "okd" ]]; then
          ./cluster_up.sh | tee ~/cluster_up.log
      else
          ./installer.sh | tee ~/installer.log
      fi
      ./setup.sh | tee ~/setup.log
      ./test.sh | tee ~/test.log
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
      p.cpus = ENV['OKD_VAGRANT_CPUS'] || 8
      p.memory = ENV['OKD_VAGRANT_MEMORY'] || 32768
    end
  end
  config.vm.provider 'libvirt' do |v, override|
    v.nested = true
    v.cpu_mode = 'host-passthrough'
    v.management_network_address = "192.168.121.0/24"
    v.random_hostname = true

    if $is_qat_enabled == "true"
      # Intel Corporation QuickAssist Technology
      qat_devices = `for i in 0434 0435 37c8 6f54 19e2; do lspci -d 8086:$i -m; done|awk '{print $1}'`
      qat_devices.split("\n").each do |dev|
        bus=dev.split(':')[0]
        slot=dev.split(':')[1].split('.')[0]
        function=dev.split(':')[1].split('.')[1]
        v.pci :bus => "0x#{bus}", :slot => "0x#{slot}", :function => "0x#{function}"
      end
   end
  end
end
