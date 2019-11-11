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

# _vercmp() - Function that compares two versions
function _vercmp {
    local v1=$1
    local op=$2
    local v2=$3
    local result

    # sort the two numbers with sort's "-V" argument.  Based on if v2
    # swapped places with v1, we can determine ordering.
    result=$(echo -e "$v1\n$v2" | sort -V | head -1)

    case $op in
        "==")
            [ "$v1" = "$v2" ]
            return
            ;;
        ">")
            [ "$v1" != "$v2" ] && [ "$result" = "$v2" ]
            return
            ;;
        "<")
            [ "$v1" != "$v2" ] && [ "$result" = "$v1" ]
            return
            ;;
        ">=")
            [ "$result" = "$v2" ]
            return
            ;;
        "<=")
            [ "$result" = "$v1" ]
            return
            ;;
        *)
            die $LINENO "unrecognised op: $op"
            ;;
    esac
}

# install_qat_driver() - Function that install Intel QuickAssist Technology drivers
function install_qat_driver {
    local qat_driver_version="1.7.l.4.6.0-00025" # Jul 23, 2019 https://01.org/intel-quick-assist-technology/downloads
    local qat_driver_tarball="qat${qat_driver_version}.tar.gz"
    if systemctl is-active --quiet qat_service; then
        return
    fi

    if ! command -v wget; then
        curl -fsSL http://bit.ly/pkgInstall | PKG=wget bash
    fi

    if [ ! -d /tmp/qat ]; then
        wget -O $qat_driver_tarball "https://01.org/sites/default/files/downloads/${qat_driver_tarball}"
        sudo mkdir -p /tmp/qat
        sudo tar -C /tmp/qat -xzf "$qat_driver_tarball"
        rm "$qat_driver_tarball"
    fi

    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
        opensuse*)
            sudo -H -E zypper -q install -y -t pattern devel_C_C++
            sudo -H -E zypper -q install -y --no-recommends pciutils libudev-devel openssl-devel gcc-c++ kernel-source kernel-syms
            echo "WARN: The Intel QuickAssist Technology drivers don't have full support in ${ID,,} yet."
            return
        ;;
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

    pushd /tmp/qat
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

    sudo systemctl --now enable qat_service
}

install_qat_driver
if _vercmp "${OKD_VERSION#*v}" '<=' "4.1.0"; then
    ./cluster_up.sh
else
    ./installer.sh
fi
