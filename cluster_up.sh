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

    pushd "$(mktemp -d)"
    wget "https://github.com/openshift/origin/releases/download/${OKD_VERSION}/${okd_tarball}"
    tar -xzf "$okd_tarball"
    sudo mv "${okd_tarball%.tar.gz}/"{oc,kubectl} /usr/bin
    popd
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

okd_pkgs="docker firewalld wget krb5-devel bind-utils tito gpgme gpgme-devel libassuan libassuan-devel"
if [ "${OKD_SOURCE:-tarball}" == "source" ]; then
    okd_pkgs+=" git jq make gcc zip mercurial bc rsync file createrepo openssl bsdtar"
fi

echo "Update repos and install dependencies..."
curl -fsSL http://bit.ly/pkgInstall | PKG_UDPATE=true PKG=$okd_pkgs bash
echo "{ \"insecure-registries\" : [ \"172.30.0.0/16\" ] }" | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker
sudo sudo systemctl --now enable firewalld

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
