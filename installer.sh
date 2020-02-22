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
if [ "${OKD_DEBUG:-false}" == "true" ]; then
    set -o xtrace
fi

# build_installer() - Function that create the installer binary using the source code
function build_installer {
    mkdir -p ~/go/{bin,src}
    curl -fsSL https://raw.githubusercontent.com/golang/dep/master/install.sh | sh

    git clone --depth 1 https://github.com/openshift/installer ~/go/src/github.com/openshift/installer
    pushd ~/go/src/github.com/openshift/installer/ || exit
    ./hack/build.sh
    sudo mv ./bin/openshift-install /usr/bin
    popd
}

# download_installer() - Function that pulls the installer binary
function download_installer {
    local okd_tarball="openshift-install-linux-${OKD_VERSION#*v}.tar.gz"
    wget "https://mirror.openshift.com/pub/openshift-${OKD_VERSION%%.*}/clients/ocp/${OKD_VERSION#*v}/$okd_tarball"
    tar -C /tmp -xzf "$okd_tarball"
    rm "$okd_tarball"
    sudo mv /tmp/openshift-install /usr/bin
    sudo mv terraform /usr/local/bin
    rm "$okd_tarball"
    mkdir -p ~/.terraform.d/plugins
}

function install_matchbox {
    local version="v0.8.0"
    local tarball="matchbox-${version}-linux-amd64.tar.gz"

    wget "https://github.com/poseidon/matchbox/releases/download/$version/$tarball"
    sudo tar -C /tmp -xzf "$tarball"
    rm "$tarball"
    sudo mv "/tmp/${tarball%.tar.gz}/contrib/systemd/matchbox-local.service" /etc/systemd/system/matchbox.service
    sudo mv "/tmp/${tarball%.tar.gz}/matchbox" /usr/local/bin

    sudo useradd -U matchbox
    sudo mkdir -p /var/lib/matchbox/assets
    sudo chown -R matchbox: /var/lib/matchbox
    sudo chown -R matchbox: /usr/local/bin/matchbox

    sudo systemctl enable matchbox.service
    sudo systemctl start matchbox.service
}

function _install_terraform {
    local version="0.11.3"
    local tarball="terraform_${version}_linux_amd64.zip"

    wget "https://releases.hashicorp.com/terraform/$version/$tarball"
    unzip "$tarball"
    sudo mv terraform /usr/local/bin
    rm "$tarball"
    mkdir -p ~/.terraform.d/plugins
}

function install_terraform_matchbox_provider {
    local version="v0.2.3"
    local prefix="terraform-provider-matchbox"
    local tarball="${prefix}-${version}-linux-amd64.tar.gz"

    _install_terraform
    wget "https://github.com/poseidon/$prefix/releases/download/$version/$tarball"
    sudo tar -C /tmp -xzf "$tarball"
    rm "$tarball"
    sudo mv "/tmp/${tarball%.tar.gz}/$prefix" ~/.terraform.d/plugins/"${prefix}_${version}"
}

echo "Update repos and install dependencies..."
okd_pkgs="wget unzip golang"
if [ "${OKD_SOURCE:-tarball}" == "source" ]; then
    okd_pkgs+=" gcc-c++ golang"
fi

echo "Update repos and install dependencies..."
# NOTE: This shorten link is pointing to the cURL Package manager project(https://github.com/electrocucaracha/pkg-mgr)
export PKG_UDPATE=true
export PKG=$okd_pkgs
export PKG_GOLANG_VERSION=1.12.7
curl -fsSL http://bit.ly/install_pkg | bash

install_terraform_matchbox_provider
install_matchbox
if [ "${OKD_SOURCE:-tarball}" == "source" ]; then
    build_installer
else
    download_installer
fi

mkdir ~/bare-metal
cp install-config.yaml ~/bare-metal/install-config.yaml
/usr/bin/openshift-install --dir ~/bare-metal/ create ignition-configs
/usr/bin/openshift-install create cluster
