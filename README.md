# QAT enablement on OKD

[![Build Status](https://travis-ci.org/electrocucaracha/okd.png)](https://travis-ci.org/electrocucaracha/okd)

This project collects the instructions to enable the Intel®
QuickAssist Technology (QAT) on [Origin community Distribution of
Kubernetes][1]. This technology improves performance offloading the
encryption/decryption and compression/decompression operations thereby
reserving processor cycles for application and control processing.

## Virtual Machines

This project uses [Vagrant tool][2] for provisioning Virtual Machines
automatically. The *setup.sh* script of the
[bootstrap-vagrant project][3] contains the Linux instructions to
install dependencies and plugins required for its usage. This script
supports two Virtualization technologies (Libvirt and VirtualBox).

    $ curl -fsSL http://bit.ly/initVagrant | PROVIDER=libvirt bash

Once Vagrant is installed, it's possible to provision an All-in-One
OKD cluster using the following instructions:

    $ vagrant up

The **OKD_ENABLE_QAT** environment variable enables the instructions
for installing QAT drivers and plugin during the provisioning process.

    $ OKD_ENABLE_QAT=true vagrant up

## License

Apache-2.0

[1]: https://www.okd.io/
[2]: https://www.vagrantup.com/
[3]: https://github.com/electrocucaracha/bootstrap-vagrant
