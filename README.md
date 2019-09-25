![balenaOS in container](/images/balenaos-in-container.png)

# balenaOS in a docker container
This is a tool which enables running balenaOS docker images as a docker container.

## Prerequisites
Before running this tool make sure:
1. Docker daemon is running
2. Current user has privileges to run docker commands as this script doesn't elevate the docker commands (https://docs.docker.com/engine/installation/linux/linux-postinstall/).
3. Depending on what balenaOS image you are trying to boot, you might need aufs or overlayfs on your host.
4. The balenaOS image is compatible with the architecture where you are running the script. e.g. If you are running this script on your laptop (x86_64), you can run balenaOS images built for the NUC which are also x86_64.

## How to use
See the tool's help message: `./balenaos-in-container.sh --help`.

## Development
Want to contribute? Great! Throw pull requests at us.
