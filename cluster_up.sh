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

# install_docker() - Download and install docker-engine
function install_docker {
    if command -v docker; then
        return
    fi
    sudo mkdir -p /etc/docker
    echo "{ \"insecure-registries\" : [ \"172.30.0.0/16\" ] }" | sudo tee /etc/docker/daemon.json

    export KRD_DEBUG="${OKD_DEBUG:-false}"
    KRD_ACTIONS=(install_docker)
    if [ "${OKD_SOURCE:-tarball}" == "source" ]; then
        KRD_ACTIONS+=(install_go)
    fi
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
    local okd_tarball="openshift-origin-client-tools-${OKD_VERSION}-0cbc58b-linux-64bit.tar.gz"
    wget "https://github.com/openshift/origin/releases/download/${OKD_VERSION}/${okd_tarball}"
    tar -C /tmp -xzf "$okd_tarball"
    rm "$okd_tarball"
    sudo mv "/tmp/${okd_tarball%.tar.gz}/"{oc,kubectl} /usr/bin
}

# build_oc() - Create binaries using the source code
function build_oc {
    if command -v oc; then
        return
    fi

    export PATH="$PATH:/usr/local/go/bin"
    git clone --depth 1 https://github.com/openshift/origin -b "${OKD_VERSION}" /tmp/origin
    pushd /tmp/origin
    make
    sudo mv _output/local/bin/linux/amd64/* /usr/bin
    popd
}

echo "Update repos and install dependencies..."
COMMON_DISTRO_PKGS=(firewalld wget)
if [ "${OKD_SOURCE:-tarball}" == "source" ]; then
    COMMON_DISTRO_PKGS+=(git jq make gcc zip mercurial bc rsync file createrepo openssl bsdtar)
fi
# shellcheck disable=SC1091
source /etc/os-release || source /usr/lib/os-release
case ${ID,,} in
    *suse)
    INSTALLER_CMD="sudo -H -E zypper -q install -y --no-recommends ${COMMON_DISTRO_PKGS[*]}"
    sudo zypper -n ref
    ;;

    ubuntu|debian)
    INSTALLER_CMD="sudo -H -E apt-get -y -q=3 install ${COMMON_DISTRO_PKGS[*]}"
    if [ "${OKD_SOURCE:-tarball}" == "source" ]; then
        INSTALLER_CMD+=" libkrb5-dev"
    fi
    sudo apt-get update
    ;;

    rhel|centos|fedora)
    PKG_MANAGER=$(command -v dnf || command -v yum)
    INSTALLER_CMD="sudo -H -E ${PKG_MANAGER} -q -y install ${COMMON_DISTRO_PKGS[*]}"
    if [ "${OKD_SOURCE:-tarball}" == "source" ]; then
        INSTALLER_CMD+=" krb5-devel bind-utils tito gpgme gpgme-devel libassuan libassuan-devel"
    fi
    sudo "$PKG_MANAGER" updateinfo
    ;;
esac
${INSTALLER_CMD}
sudo sudo systemctl enable firewalld
sudo sudo systemctl start firewalld

install_docker
enable_containers
if [ "${OKD_SOURCE:-tarball}" == "source" ]; then
    build_oc
else
    download_oc
fi

oc_cmd="sudo /usr/bin/oc cluster up"
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
