![balenaOS in container](/images/balenaos-in-container.png)

# balenaOS in a docker container

This is a tool which enables running balenaOS docker images as a docker container.

## Prerequisites

Before running this tool make sure:

1. Docker daemon is running
2. Current user has privileges to run docker commands.
3. Depending on what balenaOS image you are trying to boot, you might need aufs or overlayfs on your host.
4. The balenaOS image is compatible with the architecture where you are running the script. e.g. If you are running this script on your laptop (x86_64), you can run balenaOS images built for the NUC which are also x86_64. [***](#running-other-architectures)

## How to use
```
$ docker-compose up
```

This assumes you have a `config.json` in the project directory. It can be downloaded from your balenaCloud dashboard. Once you have added an application click "Add a new device", click to expand the "Advanced" section and check "Download configuration file only" now click "Download configuration file".

You can find the latest balenaOS images on [dockerhub](https://hub.docker.com/r/resin/resinos/tags).

## Running other architectures

It's possible to run a container images that target other platforms than your host system by registering QEMU's user-mode emulation.
Check out https://github.com/dbhi/qus/#setup for how to set that up.

## Development

Want to contribute? Great! Throw pull requests at us.
