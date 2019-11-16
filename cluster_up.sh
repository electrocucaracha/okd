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

    git clone --depth 1 -b v3.11.0 https://github.com/electrocucaracha/origin /tmp/origin
    pushd /tmp/origin
    PATH="$PATH:/usr/local/go/bin" make
    sudo mv _output/local/bin/linux/amd64/* /usr/bin
    popd
}

okd_pkgs="docker firewalld wget krb5-devel bind-utils tito gpgme"
okd_pkgs+=" gpgme-devel libassuan libassuan-devel git jq make gcc zip"
okd_pkgs+=" mercurial bc rsync file createrepo openssl bsdtar golang"

echo "Update repos and install dependencies..."
# NOTE: This shorten link is pointing to the cURL Package manager project(https://github.com/electrocucaracha/pkg-mgr)
export PKG_UDPATE=true
export PKG=$okd_pkgs
export PKG_GOLANG_VERSION=1.12.7
export PKG_DOCKER_INSECURE_REGISTRIES=172.30.0.0/16
curl -fsSL http://bit.ly/pkgInstall | bash

enable_containers
build_oc

sudo systemctl restart docker
printf "Waiting for docker service..."
until sudo docker info; do
    printf "."
    sleep 2
done

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

mkdir -p ~/.kube
sudo cp /root/.kube/config ~/.kube/
sudo chown "$USER" ~/.kube/config
