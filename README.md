![resinOS in container](https://github.com/resin-os/resinos-in-container/raw/master/images/resinos-in-container.png)

# ResinOS in a docker container
This is a tool which enables running resinOS docker images as a docker container.

## Prerequisites
Before running this tool make sure:
1. Docker daemon is running
2. Current user has privileges to run docker commands as this script doesn't elevate the docker commands (https://docs.docker.com/engine/installation/linux/linux-postinstall/).
3. Depending on what resinOS image you are trying to boot, you might need aufs or overlayfs on your host.
4. The resinOS image is compatible with the architecture where you are running the script. e.g. If you are running this script on your laptop (x86_64), you can run resinOS images built for the NUC which are also x86_64.

## How to use
See the tool's help message: `./resinos-in-container.sh --help`.

## Development
Want to contribute? Great! Throw pull requests at us.
