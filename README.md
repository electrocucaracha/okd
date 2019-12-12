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

The provisioning process starts updating the Kernel version using the
packages provided by the Extra Packages for Enterprise Linux (EPEL)
project. Once the Virtual Machine has automatically rebooted with the
new Kernel loaded the provisioning process will continue with the
setup of the OKD cluster through the usage of the
[cluster_up.sh](cluster_up.sh). After its execution, the
[setup.sh](setup.sh) bash script will take place creating components
required by the [Sample Application](nginx-openshift-sample-app.json),
the performance benchmarks will be performed on this Nginx App.
Finally, the [test.sh](test.sh) bash script will run [k6][4] workloads
to measure the Router's performance.

## Results

This section shows the results that was taken from the creation of two
Virtual Machines spawned in the same server. The following table
contains the configuration values used during their provisioning
process.

### Non-QAT VM Configuration values

| Environment variable |  Value      |
|:---------------------|:-----------:|
| OKD_VAGRANT_CPUS     | 44          |
| OKD_VAGRANT_MEMORY   | 24576       |
| OKD_ENABLE_QAT       | false       |

#### K6 output

```bash
          /\      |‾‾|  /‾‾/  /‾/   
     /\  /  \     |  |_/  /  / /    
    /  \/    \    |      |  /  ‾‾\  
   /          \   |  |‾\  \ | (_) | 
  / __________ \  |__|  \__\ \___/ .io

  execution: local--------------------------------------------------]   servertor
     output: -
     script: k6-config.js

    duration: 20s, iterations: -
         vus: 10,  max: 10

    init [----------------------------------------------------------] starting
    ✓ status was 200
    ✓ transaction time OK

    checks.....................: 100.00% ✓ 20948 ✗ 0   
    data_received..............: 422 MB  21 MB/s
    data_sent..................: 6.4 MB  318 kB/s
    http_req_blocked...........: avg=11.44ms  min=3.81ms   med=10.92ms  max=40.18ms p(90)=14.96ms  p(95)=19.08ms 
    http_req_connecting........: avg=276.87µs min=85.76µs  med=268.5µs  max=4.9ms   p(90)=329.6µs  p(95)=354.35µs
    http_req_duration..........: avg=7.33ms   min=2.11ms   med=6.61ms   max=29.1ms  p(90)=11.12ms  p(95)=14.05ms 
    http_req_receiving.........: avg=894.35µs min=224.34µs med=653.67µs max=11.4ms  p(90)=1.56ms   p(95)=2.22ms  
    http_req_sending...........: avg=100.45µs min=20.93µs  med=89.06µs  max=7.52ms  p(90)=129.08µs p(95)=147.94µs
    http_req_tls_handshaking...: avg=11.02ms  min=3.4ms    med=10.52ms  max=39.44ms p(90)=14.48ms  p(95)=18.62ms 
    http_req_waiting...........: avg=6.34ms   min=1.45ms   med=5.65ms   max=26.36ms p(90)=9.93ms   p(95)=12.39ms 
    http_reqs..................: 10474   523.697242/s
    iteration_duration.........: avg=19.03ms  min=8.17ms   med=17.58ms  max=52.19ms p(90)=26.15ms  p(95)=31.48ms 
    iterations.................: 10474   523.697242/s
    vus........................: 10      min=10  max=10
    vus_max....................: 10      min=10  max=10
```

### QAT VM configuration values

| Environment variable |  Value      |
|:---------------------|:-----------:|
| OKD_VAGRANT_CPUS     | 44          |
| OKD_VAGRANT_MEMORY   | 24576       |
| OKD_ENABLE_QAT       | true        |

#### K6 output

```bash
          /\      |‾‾|  /‾‾/  /‾/   
     /\  /  \     |  |_/  /  / /    
    /  \/    \    |      |  /  ‾‾\  
   /          \   |  |‾\  \ | (_) | 
  / __________ \  |__|  \__\ \___/ .io

  execution: local--------------------------------------------------]   servertor
     output: -
     script: k6-config.js

    duration: 20s, iterations: -
         vus: 10,  max: 10

    init [----------------------------------------------------------] starting
    ✓ status was 200
    ✓ transaction time OK

    checks.....................: 100.00% ✓ 29898 ✗ 0   
    data_received..............: 602 MB  30 MB/s
    data_sent..................: 8.6 MB  429 kB/s
    http_req_blocked...........: avg=8.82ms   min=3.33ms   med=8.59ms   max=39.8ms  p(90)=11.21ms  p(95)=12.12ms 
    http_req_connecting........: avg=605.48µs min=90.87µs  med=532.26µs max=14.67ms p(90)=909.4µs  p(95)=1.18ms  
    http_req_duration..........: avg=4.17ms   min=1.09ms   med=3.98ms   max=28.76ms p(90)=5.71ms   p(95)=6.42ms  
    http_req_receiving.........: avg=989.79µs min=163.34µs med=798.9µs  max=17.72ms p(90)=1.74ms   p(95)=2.2ms   
    http_req_sending...........: avg=122.85µs min=17.19µs  med=83.16µs  max=14.14ms p(90)=181.04µs p(95)=299.39µs
    http_req_tls_handshaking...: avg=8.05ms   min=2.82ms   med=7.84ms   max=39.05ms p(90)=10.31ms  p(95)=11.19ms 
    http_req_waiting...........: avg=3.06ms   min=683.97µs med=2.92ms   max=25.03ms p(90)=4.43ms   p(95)=5ms     
    http_reqs..................: 14949   747.443662/s
    iteration_duration.........: avg=13.3ms   min=5.24ms   med=13.07ms  max=49.68ms p(90)=16.31ms  p(95)=17.59ms 
    iterations.................: 14949   747.443662/s
    vus........................: 10      min=10  max=10
    vus_max....................: 10      min=10  max=10
```

As we can see the major improvements when the QuickAssit Technology is
used are on the `http_req_duration`, `http_req_tls_handshaking`,
`http_req_waiting` and `http_reqs` values. Those fast responses on the
Web Application can result in better user experience or increase the
capacity to support major number of workloads by server.

## License

Apache-2.0

[1]: https://www.okd.io/
[2]: https://www.vagrantup.com/
[3]: https://github.com/electrocucaracha/bootstrap-vagrant
[4]: https://k6.io/
