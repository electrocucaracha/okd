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
    export KRD_DEBUG="${OKD_DEBUG:-false}"
    KRD_ACTIONS+=(install_go)
    KRD_ACTIONS_DECLARE=$(declare -p KRD_ACTIONS)
    export KRD_ACTIONS_DECLARE
    curl -fsSL https://raw.githubusercontent.com/electrocucaracha/krd/master/aio.sh | bash
    export PATH="$PATH:/usr/local/go/bin"
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
}

echo "Update repos and install dependencies..."
COMMON_DISTRO_PKGS=(wget)
if [ "${OKD_SOURCE:-tarball}" == "source" ]; then
    COMMON_DISTRO_PKGS=(git)
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
    sudo apt-get update
    ;;

    rhel|centos|fedora)
    PKG_MANAGER=$(command -v dnf || command -v yum)
    INSTALLER_CMD="sudo -H -E ${PKG_MANAGER} -q -y install ${COMMON_DISTRO_PKGS[*]}"
    if [ "${OKD_SOURCE:-tarball}" == "source" ]; then
        INSTALLER_CMD+=" gcc-c++"
    fi
    sudo "$PKG_MANAGER" updateinfo
    ;;
esac
${INSTALLER_CMD}

if [ "${OKD_SOURCE:-tarball}" == "source" ]; then
    build_installer
else
    download_installer
fi

exit
mkdir ~/bare-metal
cat <<EOL > ~/bare-metal/install-config.yaml
apiVersion: v1
## The base domain of the cluster. All DNS records will be sub-domains of this base and will also include the cluster name.
baseDomain: example.com
compute:
- name: worker
  replicas: 1
controlPlane:
  name: master
  replicas: 1
metadata:
  ## The name for the cluster
  name: test
platform:
  none: {}
## The pull secret that provides components in the cluster access to images for OpenShift components.
pullSecret: ''
## The default SSH key that will be programmed for \`core\` user.
sshKey: ''
EOL
/usr/bin/openshift-install --dir ~/bare-metal/ create ignition-configs
/usr/bin/openshift-install create cluster
