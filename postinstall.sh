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

# install_docker() - Download and install docker-engine
function install_docker {
    if command -v docker; then
        return
    fi
    sudo mkdir -p /etc/docker
    echo "{ \"insecure-registries\" : [ \"172.30.0.0/16\" ] }" | sudo tee /etc/docker/daemon.json

    KRD_ACTIONS=("install_docker")
    KRD_ACTIONS_DECLARE=$(declare -p KRD_ACTIONS)
    export KRD_ACTIONS_DECLARE
    curl -fsSL https://raw.githubusercontent.com/electrocucaracha/krd/master/aio.sh | bash
}

# enable_containers() - Ensure that your firewall allows containers access to the OpenShift master API (8443/tcp) and DNS (53/udp) endpoints.
function enable_containers {
    sudo firewall-cmd --permanent --new-zone dockerc
    sudo firewall-cmd --permanent --zone dockerc --add-source 172.17.0.0/16
    sudo firewall-cmd --permanent --zone dockerc --add-port 8443/tcp
    sudo firewall-cmd --permanent --zone dockerc --add-port 53/udp
    sudo firewall-cmd --permanent --zone dockerc --add-port 8053/udp
    sudo firewall-cmd --reload
}

# download_oc() - Download the Linux oc binary
function download_oc {
    local okd_version="v3.11.0"
    local okd_tarball="openshift-origin-client-tools-${okd_version}-0cbc58b-linux-64bit.tar.gz"
    wget "https://github.com/openshift/origin/releases/download/${okd_version}/${okd_tarball}"
    tar -C /tmp -xzf "$okd_tarball"
    rm "$okd_tarball"
    sudo mv "/tmp/${okd_tarball%.tar.gz}/"{oc,kubectl} /usr/bin
}

echo "Update repos and install dependencies..."
# shellcheck disable=SC1091
source /etc/os-release || source /usr/lib/os-release
case ${ID,,} in
    *suse)
    INSTALLER_CMD="sudo -H -E zypper -q install -y --no-recommends"
    sudo zypper -n ref
    ;;

    ubuntu|debian)
    INSTALLER_CMD="sudo -H -E apt-get -y -q=3 install"
    sudo apt-get update
    ;;

    rhel|centos|fedora)
    PKG_MANAGER=$(command -v dnf || command -v yum)
    INSTALLER_CMD="sudo -H -E ${PKG_MANAGER} -q -y install"
    sudo "$PKG_MANAGER" updateinfo
    ;;
esac
${INSTALLER_CMD} firewalld wget git
sudo sudo systemctl enable firewalld
sudo sudo systemctl start firewalld

install_docker
enable_containers
download_oc

oc_cmd="sudo oc cluster up"
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
