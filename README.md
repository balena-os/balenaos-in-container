![balenaOS in container](/images/balenaos-in-container.png)

# balenaOS in a docker container
This is a tool which enables running balenaOS docker images as a docker container.

##### NOTE: This solution is experimental and under active development. New users please refer to the [balena docs](https://www.balena.io/docs/learn/welcome/introduction/).

## Prerequisites
Before running this tool make sure:
1. Docker daemon is running
2. Current user has privileges to run docker commands as this script doesn't elevate the docker commands (https://docs.docker.com/engine/installation/linux/linux-postinstall/).
3. Depending on what balenaOS image you are trying to boot, you might need aufs or overlayfs on your host.
4. The balenaOS image is compatible with the architecture where you are running the script. e.g. If you are running this script on your laptop (x86_64), you can run balenaOS images built for the NUC which are also x86_64.

## How to use
See the tool's help message for all arguments: `./balenaos-in-container.sh --help`.

Mandatory arguments:

`--image <image>` must be a docker image. Does not support raw `.img` images. See https://hub.docker.com/r/resin/resinos/tags. Intel NUC is the most likely to work out of the box at this stage. Must be `dev` edition.

`-c, --config <config>` can be downloaded from your balenaCloud dashboard. Once you have added an application click "Add a new device", click to expand the "Advanced" section and check "Download configuration file only" now click "Download configuration file".

## Example

### Linux / MacOS
`$ ./balenaos-in-container.sh -image resin/resinos:2.46.0_rev1.dev-intel-nuc  -id test  -c "$PWD\config.json" -detach`

### Windows
`PS> .\balenaos-in-container.ps1 -image resin/resinos:2.46.0_rev1.dev-intel-nuc  -id test  -c "$PWD\config.json" -detach`

## Development
Want to contribute? Great! Throw pull requests at us.
