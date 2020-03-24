#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2019
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o nounset
set -o pipefail
set -o errexit
if [ "${DEBUG:-false}" == "true" ]; then
    set -o xtrace
fi

function install_qat_plugin {
    local qat_plugin_version="0.15.0"
    local qat_plugin_tarball="v${qat_plugin_version}.tar.gz"

    pushd "$(mktemp -d)"
    wget "https://github.com/intel/intel-device-plugins-for-kubernetes/archive/$qat_plugin_tarball"
    tar xzf "$qat_plugin_tarball"
    pushd intel-device-plugins-for-kubernetes-$qat_plugin_version
    sudo docker build --build-arg TAGS_KERNELDRV=kerneldrv --pull -t intel/intel-qat-plugin:local -f ./build/docker/intel-qat-plugin.Dockerfile .
    popd
    popd

    oc login -u system:admin
    oc create serviceaccount -n kube-system qat-svc-account
    oc adm policy add-scc-to-user privileged -n kube-system -z qat-svc-account
    oc apply -f qat_plugin.yaml -n kube-system
}

function install_qat_driver {
    local qat_driver_version="1.7.l.4.6.0-00025" # Jul 23, 2019 https://01.org/intel-quick-assist-technology/downloads
    local qat_driver_tarball="qat${qat_driver_version}.tar.gz"

    if systemctl is-active --quiet qat_service; then
        return
    fi

    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        ubuntu|debian)
            sudo -H -E apt-get -y -q=3 install build-essential "linux-headers-$(uname -r)" pciutils libudev-dev pkg-config
        ;;
        rhel|centos|fedora)
            PKG_MANAGER=$(command -v dnf || command -v yum)
            sudo "${PKG_MANAGER}" groups mark install "Development Tools"
            sudo "${PKG_MANAGER}" groups install -y "Development Tools"
            sudo -H -E "${PKG_MANAGER}" -q -y install "kernel-devel-$(uname -r)" pciutils libudev-devel gcc openssl-devel yum-plugin-fastestmirror
        ;;
        clear-linux-os)
            sudo -H -E swupd bundle-add --quiet linux-lts2018-dev make c-basic dev-utils devpkg-systemd
        ;;
    esac

    for mod in $(lsmod | grep "^intel_qat" | awk '{print $4}'); do
        sudo rmmod "$mod"
    done
    if lsmod | grep "^intel_qat"; then
        sudo rmmod intel_qat
    fi

    sudo tee /lib/modprobe.d/quickassist-blacklist.conf  << EOF
### Blacklist in-kernel QAT drivers to avoid kernel boot problems.
# Lewisburg QAT PF
blacklist qat_c62x
# Common QAT driver
blacklist intel_qat
EOF

    pushd "$(mktemp -d)"
    wget "https://01.org/sites/default/files/downloads/${qat_driver_tarball}"
    tar xzf "$qat_driver_tarball"
    sudo ./configure
    for action in clean uninstall install; do
        sudo make $action
    done
    popd

    if [[ "${ID,,}" == *clear-linux-os* ]]; then
        sudo tee /etc/systemd/system/qat_service.service << EOF
[Unit]
Description=Intel QuickAssist Technology service
[Service]
Type=forking
Restart=no
TimeoutSec=5min
IgnoreSIGPIPE=no
KillMode=process
GuessMainPID=no
RemainAfterExit=yes
ExecStart=/etc/init.d/qat_service start
ExecStop=/etc/init.d/qat_service stop
[Install]
WantedBy=multi-user.target
EOF
    fi
    for conf in $(sudo /usr/local/bin/adf_ctl status | grep up | awk '{print $4 substr($1, 4)}' | tr -d ','); do
        sudo tee --append "/etc/$conf.conf" << EOF
[SHIM]
NumberCyInstances = 1
NumberDcInstances = 0
NumProcesses = 24
LimitDevAccess = 0
# Crypto - User instance #0
Cy0Name = "UserCY0"
Cy0IsPolled = 1
# List of core affinities
Cy0CoreAffinity = 0
EOF
    done

    sudo /usr/local/bin/adf_ctl restart
    sudo systemctl --now enable qat_service
    sudo systemctl start qat_service
}

# enable_containers() - Ensure that your firewall allows containers access to the OpenShift master API (8443/tcp) and DNS (53/udp) endpoints.
function enable_containers {
    sudo sudo systemctl --now enable firewalld
    sudo firewall-cmd --permanent --new-zone dockerc
    sudo firewall-cmd --permanent --zone dockerc --add-source 172.17.0.0/16
    sudo firewall-cmd --permanent --zone dockerc --add-port 8443/tcp
    sudo firewall-cmd --permanent --zone dockerc --add-port 53/udp
    sudo firewall-cmd --permanent --zone dockerc --add-port 8053/udp
    sudo firewall-cmd --reload
}

# build_oc() - Create binaries using the source code
function build_oc {
    if command -v oc; then
        return
    fi

    git clone --depth 1 -b v3.11.0 https://github.com/openshift/origin /tmp/origin
    cp openshift_router.patch /tmp/origin
    pushd /tmp/origin
    if [[ "${QAT_ENABLED:-false}" == "true" ]]; then
        git apply openshift_router.patch
    fi
    PATH="$PATH:/usr/local/go/bin" make
    sudo mv _output/local/bin/linux/amd64/* /usr/bin
    popd
}

okd_pkgs="docker firewalld wget krb5-devel bind-utils tito gpgme"
okd_pkgs+=" gpgme-devel libassuan libassuan-devel git jq make gcc zip"
okd_pkgs+=" mercurial bc rsync file createrepo openssl bsdtar go-lang"

echo "Update repos and install dependencies..."
# NOTE: This shorten link is pointing to the cURL Package manager project(https://github.com/electrocucaracha/pkg-mgr)
export PKG_UDPATE=true
export PKG=$okd_pkgs
export PKG_GOLANG_VERSION=1.12.7
export PKG_DOCKER_INSECURE_REGISTRIES=172.30.0.0/16
curl -fsSL http://bit.ly/install_pkg | bash

enable_containers
build_oc

sudo systemctl restart docker
printf "Waiting for docker service..."
until sudo docker info; do
    printf "."
    sleep 2
done

oc_cmd="sudo /usr/bin/oc cluster up --enable=centos-imagestreams,registry,sample-templates,persistent-volumes,web-console"
if [ -n "${HTTP_PROXY:-}" ]; then
    oc_cmd+=" --http-proxy $HTTP_PROXY"
fi
if [ -n "${HTTPS_PROXY:-}" ]; then
    oc_cmd+=" --https-proxy $HTTPS_PROXY"
fi
if [ -n "${NO_PROXY:-}" ]; then
    oc_cmd+=" --no-proxy $NO_PROXY"
fi
${oc_cmd}

mkdir -p ~/.kube
sudo cp /root/.kube/config ~/.kube/
sudo chown "$USER" ~/.kube/config
if [[ "${QAT_ENABLED:-false}" == "true" ]]; then
    install_qat_driver
    install_qat_plugin
fi
