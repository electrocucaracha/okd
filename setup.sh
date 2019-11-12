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

pushd router
sudo docker build -t openshift/origin-clearlinux-haproxy-router .
popd

oc login -u system:admin

# Create Non-QAT sample app
oc new-project non-qat --display-name="OpenShift 3 non-QAT Sample" \
    --description="This is an example project to demonstrate non-QAT router"
oc adm policy add-scc-to-user hostnetwork -z router
oc adm router non-qat-router --replicas=0 --ports='80:5080,443:5443' \
    --stats-port=51937 --host-network=false
oc set env dc/non-qat-router ROUTER_SERVICE_HTTP_PORT=5080 \
    ROUTER_SERVICE_HTTPS_PORT=5443
oc scale dc/non-qat-router --replicas=1
oc new-app non-qat-application.json

# Create QAT sample app
oc new-project qat --display-name="OpenShift 3 QAT Sample" \
    --description="This is an example project to demonstrate QAT router"
oc adm policy add-scc-to-user hostnetwork -z router
oc adm router qat-router --replicas=0 --ports='80:6080,443:6443' \
    --images=openshift/origin-clearlinux-haproxy-router:latest \
    --stats-port=61937 --host-network=false
oc set env dc/qat-router ROUTER_SERVICE_HTTP_PORT=6080 \
    ROUTER_SERVICE_HTTPS_PORT=6443
oc scale dc/qat-router --replicas=1
oc new-app qat-application.json
