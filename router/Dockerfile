FROM clearlinux:base as builder

ARG QAT_DRIVER_RELEASE="qat1.7.l.4.6.0-00025"
ARG QAT_ENGINE_VERSION="v0.5.42"

# add trusted CAs
RUN rm -rf /run/lock/clrtrust.lock && \
    clrtrust generate && \
    swupd bundle-add --skip-diskspace-check devpkg-systemd devpkg-openssl c-basic wget git diffutils go-basic && \
    git clone --depth 1 -b $QAT_ENGINE_VERSION https://github.com/intel/QAT_Engine && \
    git clone --depth 1 https://github.com/openshift/router /router && \
    wget https://01.org/sites/default/files/downloads/$QAT_DRIVER_RELEASE.tar.gz && \
    tar xf *.tar.gz

RUN sed -i -e 's/cmn_ko$//' -e 's/lac_kernel$//' quickassist/Makefile && \
    KERNEL_SOURCE_ROOT=/tmp ./configure && \
    make quickassist-all adf-ctl-all && \
    install -m 755 build/libqat_s.so /usr/lib/ && \
    install -m 755 build/libusdm_drv_s.so /usr/lib/ && \
    install -m 755 build/adf_ctl /usr/bin/ && \
    cd QAT_Engine && \
    ./autogen.sh && \
    ./configure \
    --with-qat_dir=/ \
    --with-openssl_dir=/usr \
    --with-openssl_install_dir=/usr/lib64 \
    --enable-upstream_driver \
    --enable-usdm \
    --with-qat_install_dir=/usr/lib \
    --enable-qat_skip_err_files_build \
    --enable-openssl_install_build_arch_path && \
    make && make install && \
    cd /router && make

FROM clearlinux:base

COPY --from=builder /usr/lib/libqat_s.so /usr/lib/
COPY --from=builder /usr/lib/libusdm_drv_s.so /usr/lib/
COPY --from=builder /usr/bin/adf_ctl /usr/bin
COPY --from=builder /usr/lib64/engines-1.1/qat.so /usr/lib64/engines-1.1/qat.so
COPY --from=builder /LICENSE.GPL /usr/share/package-licenses/libqat/LICENSE.GPL
COPY --from=builder /QAT_Engine/LICENSE /usr/share/package-licenses/QAT_Engine/LICENSE
COPY --from=builder /router/openshift-router /usr/bin/
COPY --from=builder /router/images/router/haproxy/reload-haproxy /var/lib/haproxy/
COPY ./conf/haproxy-config.template /var/lib/haproxy/conf/
RUN swupd bundle-add haproxy && \
    mkdir -p /var/lib/haproxy/router/{certs,cacerts,whitelists} && \
    mkdir -p /var/lib/haproxy/{conf/.tmp,run,bin,log} && \
    touch /var/lib/haproxy/conf/{{os_http_be,os_edge_reencrypt_be,os_tcp_be,os_sni_passthrough,os_route_http_redirect,cert_config,os_wildcard_domain}.map,haproxy.config} && \
    setcap 'cap_net_bind_service=ep' /usr/sbin/haproxy && \
    chown -R :0 /var/lib/haproxy && \
    chmod -R g+w /var/lib/haproxy
LABEL io.k8s.display-name="ClearLinux - OpenShift HAProxy Router" \
      io.k8s.description="This component offers ingress to an OpenShift cluster via Ingress and Route rules." \
      io.openshift.tags="openshift,router,haproxy"
USER 1001
EXPOSE 80 443
WORKDIR /var/lib/haproxy/conf
ENV TEMPLATE_FILE=/var/lib/haproxy/conf/haproxy-config.template \
    RELOAD_SCRIPT=/var/lib/haproxy/reload-haproxy
ENTRYPOINT ["/usr/bin/openshift-router"]
