# QAT enablement on OKD

[![Build Status](https://travis-ci.org/electrocucaracha/okd.png)](https://travis-ci.org/electrocucaracha/okd)

This project collects the instructions to enable the Intel®
QuickAssist Technology (QAT) on [Origin community Distribution of
Kubernetes][1]. This technology improves performance by offloading the
encryption/decryption and compression/decompression operations thereby
reserving processor cycles for application and control processing.

This integration improves the response time of the OpenShift Router
component which is an ingress point that routes external traffic to
Kubernetes Service resources.

## Virtual Machines

This project uses [Vagrant tool][2] for provisioning Virtual Machines
automatically. The *setup.sh* script of the
[bootstrap-vagrant project][3] contains the Linux instructions to
install dependencies and plugins required for its usage. The following
instruction installs Vagrant and Libvirt as Vagrant provider.

    $ curl -fsSL http://bit.ly/initVagrant | PROVIDER=libvirt bash

Once Vagrant is installed, it's possible to provision an All-in-One
OKD cluster and measure its performance through the following
instruction:

    $ vagrant up

The [test.sh](test.sh) bash script executes [k6][4] workloads to
measure the Router's performance. It's possible to deploy an Origin
Cluster with QuickAssist Technology using the **OKD_ENABLE_QAT**
environment variable. This variable will execute the instructions for
installing QAT drivers and plugin during the provisioning process.

    $ OKD_ENABLE_QAT=true vagrant up

## License

Apache-2.0

[1]: https://www.okd.io/
[4]: https://www.vagrantup.com/
[3]: https://github.com/electrocucaracha/bootstrap-vagrant
[4]: https://k6.io/
