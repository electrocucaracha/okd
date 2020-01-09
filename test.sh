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

if ! command -v k6; then
    sudo wget -O /etc/yum.repos.d/bintray-loadimpact-rpm.repo https://bintray.com/loadimpact/rpm/rpm
    sudo yum install -y k6
fi
if ! command -v jq; then
    curl -fsSL http://bit.ly/pkgInstall | PKG_UDPATE=true PKG=jq bash
fi

rm -f ~/*.txt
for counter in $(sudo find /sys/kernel/debug -name fw_counters); do
    sudo cat "$counter" | tee --append ~/before.txt
done
k6 run k6-config.js | tee ~/k6_results.txt
for counter in $(sudo find /sys/kernel/debug -name fw_counters); do
    sudo cat "$counter" | tee --append ~/after.txt
done

if [ -f ~/before.txt ] && [ -f ~/after.txt ]; then
    diff ~/before.txt ~/after.txt
fi
