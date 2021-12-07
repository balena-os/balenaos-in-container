# balenaos-in-container connecting to bob

i'm trying to connect balenaos-in-container (bosic) to a bob instance deployed as bob fleet running on intel nuc. i want to have this setup to easily test my backend development, data migrations with real devices connected to the bob. connecting a bunch of device in parallel to bob.

in addition, this could run as a sidecar on the bob to simulate a device connected to bob (balenaos-in-container on balena on balena)

## setup

- developer host macosx
- bob
  - intel nuc provisioned to balena-on-balena fleet
  - domain name `https://<servicename>.5f57cbfa6e9525866b9883a4d88c2d47.bob.local/`
- developer host and nuc are connected to the same wifi network (they have fixed IPv4s, 192.168.0.5 and 192.168.0.4)
<details>
    <summary>Docker Version Version: 20.10.10 Details vvv</summary>

```
Client:
 Cloud integration: v1.0.20
 Version:           20.10.10
 API version:       1.41
 Go version:        go1.16.9
 Git commit:        b485636
 Built:             Mon Oct 25 07:43:15 2021
 OS/Arch:           darwin/amd64
 Context:           default
 Experimental:      true

Server: Docker Engine - Community
 Engine:
  Version:          20.10.10
  API version:      1.41 (minimum version 1.12)
  Go version:       go1.16.9
  Git commit:       e2f740d
  Built:            Mon Oct 25 07:41:30 2021
  OS/Arch:          linux/amd64
  Experimental:     true
 containerd:
  Version:          1.4.11
  GitCommit:        5b46e404f6b9f661a205e28d59c982d3634148f8
 runc:
  Version:          1.0.2
  GitCommit:        v1.0.2-0-g52b36a2
 docker-init:
  Version:          0.19.0
  GitCommit:        de40ad0
```
</details>

### alternative test environment multipass ubuntu vm
- installed docker.io
- installed docker-compose
- clone bosic repo
- added cloud config.json -> works
- added bob config.json --> does not work


## balenaos-in-container works with balena-cloud
i can run bosic with balena cloud and provision multiple device at once to a cloud fleet in my account.
latest version that i've tested with this is: 2.83.18-rev5 genericx86-64-ext running on macos.
i just download a config.json from the cloud dashboard for the given device type and add this config.json to the root folder of bosic repo.

- [x] balenos-in-container works with balena cloud


## what works with my bob instance
- manual resolving bob domain name to circumvent issue about bridged / nat networking of virtualization or docker. /etc/hosts file to resolve bob domain name e.g.: `https://api.5f57cbfa6e9525866b9883a4d88c2d47.bob.local`

1. balenaos 2.83.18-rev5 qemux86_64 
    - version with manual /etc/hosts entries in the qemu image and connect this qemu device to my bob
2. supervisor repo and supervisor in container test environment works

## balenaOS-in-container x bob combinations

1. i can provision and run a balenaos 2.83.18-rev5 genericx86-64-ext version with docker-compose `  extra_hosts:
    - "${bobhost}:${bobip}"` entries for resolving


## issues
### alternatives used resinsos baseiamges

- 2.58.6_rev1.dev-genericx86-64-ext 
    - does not connect even connect to cloud automatically 
- 2.54.2_rev1.dev-genericx86-64-ext --> does
    - runs Supervisor v11.12.4
    - connects to cloud automatically
    - does not connect to bob
        - 
        - added certificates manually with entry.sh command and added balenaRootCA base64 string as mapped compose env var
            ```
            # Include self-signed CAs, should they exist
            if [ -n "${BALENA_ROOT_CA}" ]; then
                if [ ! -e '/etc/ssl/certs/balenaRootCA.pem' ]; then
                    echo "${BALENA_ROOT_CA}" | base64 --decode > /etc/ssl/certs/balenaRootCA.crt

                    # Include the balenaRootCA in the system store for services like Docker
                    mkdir -p /usr/local/share/ca-certificates
                    echo "${BALENA_ROOT_CA}" | base64 --decode > /usr/local/share/ca-certificates/balenaRootCA.crt
                    update-ca-certificates
                fi
            fi
            ```
        - 
    - error message:
    ```
    Dec 07 20:32:23 649f988 resin-supervisor[2081]: [event]   Event: Device bootstrap {}
    Dec 07 20:32:23 649f988 resin-supervisor[2081]: [info]    New device detected. Provisioning...
    Dec 07 20:32:23 649f988 resin-supervisor[2081]: [event]   Event: Device bootstrap failed, retrying {"delay":30000,"error":{"message":""}}
    ```
### debug
```
OpenSSL> version
OpenSSL 1.1.1i  8 Dec 2020
```
```
bash-5.0# cat /etc/balena-supervisor/supervisor.conf 
# This file represents the last known version of the supervisor
SUPERVISOR_IMAGE=balena/amd64-supervisor
SUPERVISOR_TAG=v12.10.3
LED_FILE=/dev/null
```


```
bash-5.0# update-balena-supervisor
Getting image name and tag...
parse error: Invalid numeric literal at EOF at line 1, column 12
No supervisor configuration found from API or required variables not set. Using arguments for image and tag.
Set based on arguments image=balena/amd64-supervisor and tag=v12.10.3.
Getting image id...
Supervisor balena/amd64-supervisor:v12.10.3 already downloaded.
```


```
> db.all('SELECT * FROM apiSecret;', console.log);
Database { open: true, filename: '/data/database.sqlite', mode: 65542 }
> null [
  {
    id: 1,
    appId: 0,
    key: '2615455a24a046c79f8fc98272472a93',
    scopes: '[{"type":"global"}]',
    serviceName: null
  }
]
```


### other steps tried out
- disabling ipv6:
```
echo net.ipv6.conf.all.disable_ipv6=1 >/etc/sysctl.d/disableipv6.conf
echo net.ipv6.conf.eth0.disable_ipv6=1 >>/etc/sysctl.d/disableipv6.conf
echo net.ipv6.conf.default.disable_ipv6=1 >>/etc/sysctl.d/disableipv6.conf
```
- use foreign config.json
     copied config.json from qemu image that has been provisioned and used in bosic:
    - VPN connects from the bosic to the bob
    - API still does not connect 
        - => supervisor bootstrapping device to bob is failing
        - => thus vpn is failing (VPN is not the initial failure)
- delete supervisor state/database
    - deleted supervisor database (rm /mnt/data/resin-data/balena-supervisor/database.sqlite) and `update-balena-supervisor`
    - no change in behavior