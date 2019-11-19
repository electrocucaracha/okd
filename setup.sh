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

oc login -u system:admin

oc project default
if [[ "${QAT_ENABLED:-false}" == "true" ]]; then
    clear_img="openshift/origin-clearlinux-haproxy-router:v3.11.0"
    sudo docker build -t "$clear_img" router
    oc adm policy add-scc-to-user privileged -z router
    oc adm router --images="$clear_img"
else
    oc adm policy add-scc-to-user hostnetwork -z router
    oc adm router --extended-logging
fi

oc new-project sample-app
oc new-app -f nginx-openshift-sample-app.json

printf "Waiting for building the application..."
until oc get builds | grep Complete; do
    printf "."
    sleep 2
done

printf "Waiting for the creation of routes..."
until curl -vk https://localhost -H 'Host: www.example.com'  | grep "<h1>"; do
    printf "."
    sleep 2
done
