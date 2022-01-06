# balenaOS in container for .local BoB usage
Issue about running balenaOS in container and connect to .local bob e.g.: 55ccb57ae329e48ecf6b9ec7d42651a7.bob.local

I wanted to use balenaOS in container for testing on my local bob. I wanted to be able to scale up multiple device easily without the need for a virtual machine setup.

The repository: https://github.com/balena-os/balenaos-in-container is working out of the box for remotely hosted balena instances, like production or staging.

When I tried the setup with my local BoB instance it failed to connect.
First I setup a static (/etc/hosts) name resolution which worked from shell level. In the supervisor itself I faced the issue that the supervisor isn't able to resolve the .local domain name of the BoB.

Then I started to understand what happens in the supervisor and the supervisor has a hard coded switch internally that is not using the os / node runtime DNSlookup functionality but overwrites the DNSlookup method to implement a nodejs level mDNS resolution. It's basically executing the mDNS broadcast in nodejs.

Starting to work on a fix I setup myself with the supervisor Docker-in-Docker development setup to test the implementations. This setup didn't fail to connect to my .local BoB instance.

The difference between the supervisor DinD and the balenaOSinContainer setup is the resinOS version.

Finally I found out, that the resinOS 2.48.0_rev3-intel-nuc image works with .local bob and static name resolution. The 2.68... version used prior was failing to resolve the domain names.

It's failing already in resinOS version 2.50, thus the linux Kernel 4 to 5 update isn't the root cause. Moreover, the latest supervisor code is working in the old resinOS 2.48 as this is used for the development and debugging.


## The final setup for 2.48.0 is
- pass the static bob ip and TLD names via docker-compose extra_hosts
- copy the local bob self signed certificate into the image at build time
- docker-compose up --scale os=N
- N many devices are provisioned to BoB.


### Question:
- What could be the difference between 2.48.0 and younger releases
- When you do some debugging I'd like to look over your shoulders. I'm interested in debugging it, but need to focus on API work now. 
- Does it make sense to make it work with latest (e.g. 2.8x...) versions?
- What could be the drawback for me using 2.48 instead of 2.8?

Actually, I don't know where / how to push this. Or if it's currently worth pushing.


# Debugging outputs - Don't know if needed.
## resinos 2.50.1_rev1-intel-nuc
Docker version 18.09.10-dev, build 7cb464a406748016f2df0c31a9851d20456a3d31
bash-4.4# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: tunl0@NONE: <NOARP> mtu 1480 qdisc noop qlen 1000
    link/ipip 0.0.0.0 brd 0.0.0.0
3: ip6tnl0@NONE: <NOARP> mtu 1452 qdisc noop qlen 1000
    link/tunnel6 00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00 brd 00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00
4: resin-dns: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue qlen 1000
    link/ether 3e:d8:69:ca:bf:94 brd ff:ff:ff:ff:ff:ff
    inet 10.114.102.1/24 scope global resin-dns
       valid_lft forever preferred_lft forever
5: balena0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue 
    link/ether 02:42:9b:3b:4f:1d brd ff:ff:ff:ff:ff:ff
    inet 10.114.101.1/24 brd 10.114.101.255 scope global balena0
       valid_lft forever preferred_lft forever
6: supervisor0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue 
    link/ether 02:42:07:15:d5:42 brd ff:ff:ff:ff:ff:ff
    inet 10.114.104.1/25 brd 10.114.104.127 scope global supervisor0
       valid_lft forever preferred_lft forever
1927: eth0@if1928: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue 
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.2/16 brd 172.17.255.255 scope global eth0
       valid_lft forever preferred_lft forever
bash-4.4# route
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
default         _gateway        0.0.0.0         UG    0      0        0 eth0
10.114.101.0    *               255.255.255.0   U     0      0        0 balena0
10.114.102.0    *               255.255.255.0   U     0      0        0 resin-dns
10.114.104.0    *               255.255.255.128 U     0      0        0 supervisor0
172.17.0.0      *               255.255.0.0     U     0      0        0 eth0

bash-4.4# balena network ls
NETWORK ID          NAME                DRIVER              SCOPE
63689a30d6e8        bridge              bridge              local
144c6b7ad31a        host                host                local
e9c6e27265c4        none                null                local
e8f483b901e2        supervisor0         bridge              local

bash-4.4# balena network inspect bridge
[
    {
        "Name": "bridge",
        "Id": "63689a30d6e839559da91d4d86d9dca548ff413b663fe8a22c1b8044a6ed8c88",
        "Created": "2022-01-03T12:36:19.709269704Z",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "10.114.101.1/24",
                    "IPRange": "10.114.101.0/25",
                    "Gateway": "10.114.101.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {},
        "Options": {
            "com.docker.network.bridge.default_bridge": "true",
            "com.docker.network.bridge.enable_icc": "true",
            "com.docker.network.bridge.enable_ip_masquerade": "true",
            "com.docker.network.bridge.host_binding_ipv4": "0.0.0.0",
            "com.docker.network.bridge.name": "balena0",
            "com.docker.network.driver.mtu": "1500"
        },
        "Labels": {}
    }
]

bash-4.4# balena network inspect host  
[
    {
        "Name": "host",
        "Id": "144c6b7ad31ae81ea5bd88fcdd211aeb20566b1dea789572abb00e97f87bcbc1",
        "Created": "2022-01-03T12:36:19.691539164Z",
        "Scope": "local",
        "Driver": "host",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": []
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {
            "5e34dd8be9721ee402f90d7c7c1db48fa1f87957c2ac1894092d2227fc255eaf": {
                "Name": "resin_supervisor",
                "EndpointID": "36405959bdd8ec18b5118c4a582d6fb96126bf60fd460cec59f55ba442232756",
                "MacAddress": "",
                "IPv4Address": "",
                "IPv6Address": ""
            }
        },
        "Options": {},
        "Labels": {}
    }
]

bash-4.4# balena network inspect supervisor0 
[
    {
        "Name": "supervisor0",
        "Id": "e8f483b901e262b214001db87bbb350f075fe6e8483d0b750f6294726112298a",
        "Created": "2022-01-03T12:36:47.231678256Z",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "10.114.104.0/25",
                    "Gateway": "10.114.104.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {},
        "Options": {
            "com.docker.network.bridge.name": "supervisor0"
        },
        "Labels": {}
    }
]


in 2.50.0 self signed certificate not allowed?


## resinos 2.48.0_rev3-intel-nuc

Docker version 18.09.10-dev, build 7cb464a406748016f2df0c31a9851d20456a3d31

bash-4.4# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: tunl0@NONE: <NOARP> mtu 1480 qdisc noop qlen 1000
    link/ipip 0.0.0.0 brd 0.0.0.0
3: ip6tnl0@NONE: <NOARP> mtu 1452 qdisc noop qlen 1000
    link/tunnel6 00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00 brd 00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00
4: resin-dns: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue qlen 1000
    link/ether e2:b6:79:8f:16:22 brd ff:ff:ff:ff:ff:ff
    inet 10.114.102.1/24 scope global resin-dns
       valid_lft forever preferred_lft forever
5: balena0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue 
    link/ether 02:42:b6:85:45:97 brd ff:ff:ff:ff:ff:ff
    inet 10.114.101.1/24 brd 10.114.101.255 scope global balena0
       valid_lft forever preferred_lft forever
6: supervisor0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue 
    link/ether 02:42:2a:b7:0f:68 brd ff:ff:ff:ff:ff:ff
    inet 10.114.104.1/25 brd 10.114.104.127 scope global supervisor0
       valid_lft forever preferred_lft forever
7: br-13c07266eaab: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue 
    link/ether 02:42:4f:a5:56:23 brd ff:ff:ff:ff:ff:ff
    inet 172.18.0.1/16 brd 172.18.255.255 scope global br-13c07266eaab
       valid_lft forever preferred_lft forever
8: resin-vpn: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast qlen 100
    link/[65534] 
    inet 100.64.0.5 peer 100.64.0.1/32 scope global resin-vpn
       valid_lft forever preferred_lft forever
1929: eth0@if1930: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue 
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.2/16 brd 172.17.255.255 scope global eth0
       valid_lft forever preferred_lft forever
bash-4.4# route
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
default         _gateway        0.0.0.0         UG    0      0        0 eth0
10.114.101.0    *               255.255.255.0   U     0      0        0 balena0
10.114.102.0    *               255.255.255.0   U     0      0        0 resin-dns
10.114.104.0    *               255.255.255.128 U     0      0        0 supervisor0
100.64.0.1      *               255.255.255.255 UH    0      0        0 resin-vpn
172.17.0.0      *               255.255.0.0     U     0      0        0 eth0
172.18.0.0      *               255.255.0.0     U     0      0        0 br-13c07266eaab

bash-4.4# balena network ls 
NETWORK ID          NAME                DRIVER              SCOPE
13c07266eaab        3_default           bridge              local
8fb0d0f1bc1a        bridge              bridge              local
81b76bf972f3        host                host                local
322831c43278        none                null                local
33746b5e0e7c        supervisor0         bridge              local


bash-4.4# balena network inspect 3_default 
[
    {
        "Name": "3_default",
        "Id": "13c07266eaabf0e5a4e271b0b3c778cb8425b0423f91fcb93a4321dfaa291225",
        "Created": "2022-01-03T12:40:27.389794497Z",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": {},
            "Config": [
                {
                    "Subnet": "172.18.0.0/16",
                    "Gateway": "172.18.0.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {},
        "Options": {},
        "Labels": {
            "io.balena.supervised": "true"
        }
    }
]

bash-4.4# balena network inspect bridge   
[
    {
        "Name": "bridge",
        "Id": "8fb0d0f1bc1a3183c28e5c8b7d77f054fd772a20391df5b9e81aed8f869094cc",
        "Created": "2022-01-03T12:40:08.5579164Z",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "10.114.101.1/24",
                    "IPRange": "10.114.101.0/25",
                    "Gateway": "10.114.101.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {},
        "Options": {
            "com.docker.network.bridge.default_bridge": "true",
            "com.docker.network.bridge.enable_icc": "true",
            "com.docker.network.bridge.enable_ip_masquerade": "true",
            "com.docker.network.bridge.host_binding_ipv4": "0.0.0.0",
            "com.docker.network.bridge.name": "balena0",
            "com.docker.network.driver.mtu": "1500"
        },
        "Labels": {}
    }
]

bash-4.4# balena network inspect host  
[
    {
        "Name": "host",
        "Id": "81b76bf972f30d517f5566d497fe1afc257174f65fb42a73a59d93c3590f5a8b",
        "Created": "2022-01-03T12:40:08.542418109Z",
        "Scope": "local",
        "Driver": "host",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": []
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {
            "4c2e9960cacb0cc06b63f8db562891df89433017e3118186ade0ff54587c7070": {
                "Name": "resin_supervisor",
                "EndpointID": "0044d14876c67437dcbc28a6763b634f902bda130caef04e96f8045ca041c2cd",
                "MacAddress": "",
                "IPv4Address": "",
                "IPv6Address": ""
            }
        },
        "Options": {},
        "Labels": {}
    }
]

bash-4.4# balena network inspect supervisor0
[
    {
        "Name": "supervisor0",
        "Id": "33746b5e0e7ca5f583447531a65ce26b726e8c826b7021afe26331f0d8f0bdc3",
        "Created": "2022-01-03T12:40:26.771212243Z",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "10.114.104.0/25",
                    "Gateway": "10.114.104.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {},
        "Options": {
            "com.docker.network.bridge.name": "supervisor0"
        },
        "Labels": {}
    }
]





<!-- ## resinos 2.68.1_rev1-intel-nuc

bash-5.0# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: tunl0@NONE: <NOARP> mtu 1480 qdisc noop qlen 1000
    link/ipip 0.0.0.0 brd 0.0.0.0
3: ip6tnl0@NONE: <NOARP> mtu 1452 qdisc noop qlen 1000
    link/tunnel6 00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00 brd 00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00
4: resin-dns: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue qlen 1000
    link/ether ea:6d:92:8b:de:eb brd ff:ff:ff:ff:ff:ff
    inet 10.114.102.1/24 scope global resin-dns
       valid_lft forever preferred_lft forever
5: balena0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue 
    link/ether 02:42:b1:70:54:ba brd ff:ff:ff:ff:ff:ff
    inet 10.114.101.1/24 brd 10.114.101.255 scope global balena0
       valid_lft forever preferred_lft forever
6: supervisor0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue 
    link/ether 02:42:c7:62:5a:06 brd ff:ff:ff:ff:ff:ff
    inet 10.114.104.1/25 brd 10.114.104.127 scope global supervisor0
       valid_lft forever preferred_lft forever
1917: eth0@if1918: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue 
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.2/16 brd 172.17.255.255 scope global eth0
       valid_lft forever preferred_lft forever

       

bash-5.0# balena network ls
NETWORK ID          NAME                DRIVER              SCOPE
52c90637856f        bridge              bridge              local
1724e9ffc933        host                host                local
3958bb16490c        none                null                local
31a2d7facd27        supervisor0         bridge              local


bash-5.0# balena network inspect host
[
    {
        "Name": "host",
        "Id": "1724e9ffc93333a65cae3e4de63a45f960a0d4266c7df3dbce1bb772d7732d3a",
        "Created": "2022-01-03T12:21:52.642410581Z",
        "Scope": "local",
        "Driver": "host",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": []
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {
            "2298734b9477d4aaf4a210e483386e2e93f60f00d6c68c8a93dce640d84ea5c2": {
                "Name": "resin_supervisor",
                "EndpointID": "66e2643d8c471c85f505478663bc9577451f3aaee9a8e6d9b58359cb0f8a7dc3",
                "MacAddress": "",
                "IPv4Address": "",
                "IPv6Address": ""
            }
        },
        "Options": {},
        "Labels": {}
    }
]

bash-5.0# balena inspect supervisor0
[
    {
        "Name": "supervisor0",
        "Id": "31a2d7facd27621bee556a4f622e5bb5913a9749d24290e1a5e731ddb4da1e84",
        "Created": "2022-01-03T12:22:13.568616465Z",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "10.114.104.0/25",
                    "Gateway": "10.114.104.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {},
        "Options": {
            "com.docker.network.bridge.name": "supervisor0"
        },
        "Labels": {}
    }
] -->



## error with resibn 2.48.0 generic

```
Jan 03 14:32:41 5979075 openvpn[2518]: Mon Jan  3 14:32:41 2022 WARNING: file '/var/volatile/vpn-auth' is group or others accessible
Jan 03 14:32:41 5979075 openvpn[2518]: Mon Jan  3 14:32:41 2022 OpenVPN 2.4.7 x86_64-poky-linux-gnu [SSL (OpenSSL)] [LZO] [LZ4] [EPOLL] [MH/PKTINFO] [AEAD] built on Apr 15 2020
Jan 03 14:32:41 5979075 openvpn[2518]: Mon Jan  3 14:32:41 2022 library versions: OpenSSL 1.1.1b  26 Feb 2019, LZO 2.10
Jan 03 14:32:41 5979075 openvpn[2518]: Mon Jan  3 14:32:41 2022 NOTE: the current --script-security setting may allow this configuration to call user-defined scripts
Jan 03 14:32:41 5979075 openvpn[2518]: Mon Jan  3 14:32:41 2022 TCP/UDP: Preserving recently used remote address: [AF_INET]192.168.0.5:443
Jan 03 14:32:41 5979075 openvpn[2518]: Mon Jan  3 14:32:41 2022 Socket Buffers: R=[131072->131072] S=[16384->16384]
Jan 03 14:32:41 5979075 openvpn[2518]: Mon Jan  3 14:32:41 2022 Attempting to establish TCP connection with [AF_INET]192.168.0.5:443 [nonblock]
Jan 03 14:32:42 5979075 openvpn[2518]: Mon Jan  3 14:32:42 2022 TCP connection established with [AF_INET]192.168.0.5:443
Jan 03 14:32:42 5979075 openvpn[2518]: Mon Jan  3 14:32:42 2022 TCP_CLIENT link local: (not bound)
Jan 03 14:32:42 5979075 openvpn[2518]: Mon Jan  3 14:32:42 2022 TCP_CLIENT link remote: [AF_INET]192.168.0.5:443
Jan 03 14:32:42 5979075 openvpn[2518]: Mon Jan  3 14:32:42 2022 NOTE: UID/GID downgrade will be delayed because of --client, --pull, or --up-delay
Jan 03 14:32:42 5979075 openvpn[2518]: Mon Jan  3 14:32:42 2022 TLS: Initial packet from [AF_INET]192.168.0.5:443, sid=0851b344 2c7675ed
Jan 03 14:32:42 5979075 openvpn[2518]: Mon Jan  3 14:32:42 2022 WARNING: this configuration may cache passwords in memory -- use the auth-nocache option to prevent this
Jan 03 14:32:42 5979075 openvpn[2518]: Mon Jan  3 14:32:42 2022 VERIFY OK: depth=2, C=US, ST=Washington, L=Seattle, O=balena, OU=balenaCloud, CN=balena Root CA 0
Jan 03 14:32:42 5979075 openvpn[2518]: Mon Jan  3 14:32:42 2022 VERIFY OK: depth=1, C=US, ST=Washington, L=Seattle, O=balena, OU=balenaCloud, CN=balena Server CA 0
Jan 03 14:32:42 5979075 openvpn[2518]: Mon Jan  3 14:32:42 2022 VERIFY KU OK
Jan 03 14:32:42 5979075 openvpn[2518]: Mon Jan  3 14:32:42 2022 Validating certificate extended key usage
Jan 03 14:32:42 5979075 openvpn[2518]: Mon Jan  3 14:32:42 2022 ++ Certificate has EKU (str) TLS Web Server Authentication, expects TLS Web Server Authentication
Jan 03 14:32:42 5979075 openvpn[2518]: Mon Jan  3 14:32:42 2022 VERIFY EKU OK
Jan 03 14:32:42 5979075 openvpn[2518]: Mon Jan  3 14:32:42 2022 VERIFY OK: depth=0, C=US, ST=Washington, L=Seattle, O=balena, OU=balenaCloud, CN=vpn.55ccb57ae329e48ecf6b9ec7d42651a7.bob.local
Jan 03 14:32:42 5979075 openvpn[2518]: Mon Jan  3 14:32:42 2022 WARNING: 'cipher' is present in local config but missing in remote config, local='cipher BF-CBC'
Jan 03 14:32:42 5979075 openvpn[2518]: Mon Jan  3 14:32:42 2022 Control Channel: TLSv1.3, cipher TLSv1.3 TLS_AES_256_GCM_SHA384, 256 bit EC, curve: prime256v1
Jan 03 14:32:42 5979075 openvpn[2518]: Mon Jan  3 14:32:42 2022 [vpn.55ccb57ae329e48ecf6b9ec7d42651a7.bob.local] Peer Connection Initiated with [AF_INET]192.168.0.5:443
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 SENT CONTROL [vpn.55ccb57ae329e48ecf6b9ec7d42651a7.bob.local]: 'PUSH_REQUEST' (status=1)
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 PUSH: Received control message: 'PUSH_REPLY,sndbuf 0,rcvbuf 0,route 100.64.0.1,ping 10,ping-restart 60,socket-flags TCP_NODELAY,ifconfig 100.64.0.6 100.64.0.1,peer-id 0,cipher AES-128-GCM'
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 OPTIONS IMPORT: timers and/or timeouts modified
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 OPTIONS IMPORT: --sndbuf/--rcvbuf options modified
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 Socket Buffers: R=[131072->131072] S=[87040->87040]
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 OPTIONS IMPORT: --socket-flags option modified
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 Socket flags: TCP_NODELAY=1 succeeded
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 OPTIONS IMPORT: --ifconfig/up options modified
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 OPTIONS IMPORT: route options modified
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 OPTIONS IMPORT: peer-id set
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 OPTIONS IMPORT: adjusting link_mtu to 1627
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 OPTIONS IMPORT: data channel crypto options modified
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 Data Channel: using negotiated cipher 'AES-128-GCM'
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 Outgoing Data Channel: Cipher 'AES-128-GCM' initialized with 128 bit key
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 Incoming Data Channel: Cipher 'AES-128-GCM' initialized with 128 bit key
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 ROUTE_GATEWAY 172.17.0.1/255.255.0.0 IFACE=eth0 HWADDR=02:42:ac:11:00:02
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 TUN/TAP device resin-vpn opened
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 TUN/TAP TX queue length set to 100
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 /sbin/ip link set dev resin-vpn up mtu 1500
Jan 03 14:32:44 5979075 NetworkManager[225]: <info>  [1641220364.0933] manager: (resin-vpn): new Tun device (/org/freedesktop/NetworkManager/Devices/9)
Jan 03 14:32:44 5979075 systemd-udevd[2519]: link_config: autonegotiation is unset or enabled, the speed and duplex are not writable.
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 /sbin/ip addr add dev resin-vpn local 100.64.0.6 peer 100.64.0.1
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 /etc/openvpn-misc/upscript.sh resin-vpn 1500 1555 100.64.0.6 100.64.0.1 init
Jan 03 14:32:44 5979075 openvpn[2518]: resin-ntp-config: Found config.json in /mnt/boot/config.json .
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 /sbin/ip route add 100.64.0.1/32 via 100.64.0.1
Jan 03 14:32:44 5979075 openvpn[2518]: ip: RTNETLINK answers: File exists
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 ERROR: Linux route add command failed: external program exited with error status: 2
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 GID set to openvpn
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 UID set to openvpn
Jan 03 14:32:44 5979075 openvpn[2518]: Mon Jan  3 14:32:44 2022 Initialization Sequence Completed
Jan 03 14:32:44 5979075 chronyd[154]: 2022-01-03T14:32:44Z Selected source 176.9.166.35
Jan 03 14:32:44 5979075 chronyd[154]: 2022-01-03T14:32:44Z System clock wrong by -1.707730 seconds, adjustment started
Jan 03 14:32:43 5979075 chronyd[154]: 2022-01-03T14:32:43Z System clock was stepped by -1.707730 seconds
Jan 03 14:32:45 5979075 chronyd[154]: 2022-01-03T14:32:45Z Selected source 116.202.64.148
Jan 03 14:32:46 5979075 42a852c4bb12[236]: [info]    Internet Connectivity: OK
Jan 03 14:32:46 5979075 resin-supervisor[873]: [info]    Internet Connectivity: OK
```