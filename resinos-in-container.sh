#!/bin/bash

set -e

config_path=""
container_id="$RANDOM"
clean_volumes=no
docker_extra_args=""
detach=""

function help {
	cat << EOF
Run resinOS image in a docker container.
$0 <ARGUMENTS>

ARGUMENTS:
	-h, --help
		Print this message.
	--image
		Docker image to be used as resinOS.
		Mandatory argument.
	--id
		Use a specific id for the docker container and volumes. This allows for
		reusing volumes.
		Default: randomly generated.
	-c, --config
		The config.json path. This you can download from resin.io dashboard.
		Mandatory argument.
	-d, --detach
		Run the container in the background and print container ID (just like "docker run -d")
		Default: no.
	--extra-args
		Additional arguments for docker run (e.g. to add bind mounts)
	--clean-volumes
		If volumes are not planned to be reused, you can take advantage of this
		argument to clean up the system. Cannot be used together with -d.
		Default: no.
EOF
}

# realpath is not available on Mac OS, define it as a bash function if it's not found
if [ ! -f "/usr/bin/realpath" ] && [ ! -f "/bin/realpath" ]; then
    realpath() {
        [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
    }
fi

# Parse arguments
while [[ $# -ge 1 ]]; do
	i="$1"
	case $i in
		-h|--help)
			help
			exit 0
			;;
		--image)
			if [ -z "$2" ]; then
				log ERROR "\"$1\" argument needs a value."
			fi
			image="$2"
			shift
			;;
		--id)
			if [ -z "$2" ]; then
				log ERROR "\"$1\" argument needs a value."
			fi
			container_id="$2"
			shift
			;;
		-c|--config)
			config_json="$(realpath "$2")"
			if [ ! -f "$config_json" ]; then
				echo "ERROR: $config_path no such file."
				exit 1
			fi
			shift
			;;
		-d|--detach)
			detach="--detach"
			;;
		--extra-args)
			docker_extra_args="$2"
			shift
			;;
		--clean-volumes)
			clean_volumes=yes
			;;
		*)
			echo "ERROR: Unrecognized option $1."
			help
			exit 1
			;;
	esac
	shift
done

if [ -z "$image" ] || [ -z "$config_json" ]; then
	echo "ERROR: Required arguments not provided."
	help
	exit 1
fi

if ! docker info &> /dev/null; then
    echo "ERROR: Docker needs to be running on your host machine."
    exit 1
fi

# Get absolute path of the script location
# In this way we can reference any file relative to the script path easily
# Get the absolute script location
SCRIPTPATH="$(cd "$(dirname "$0")" ; pwd)"

for volume in boot state data; do
	if docker volume inspect "resin-${volume}-${container_id}" &> /dev/null; then
		echo "INFO: Reusing resin-${volume}-${container_id} docker volume..."
	else
		echo "INFO: Creating resin-${volume}-${container_id} docker volume..."
		docker volume create "resin-${volume}-${container_id}" &> /dev/null
	fi
done
resin_boot_volume="resin-boot-$container_id:/mnt/boot"
resin_state_volume="resin-state-$container_id:/mnt/state"
resin_data_volume="resin-data-$container_id:/mnt/data"

# Populate the boot volume with the config.json
docker run -i --rm -v \
	"$resin_boot_volume" -v "$config_json":/config.json \
	"$image" sh << EOF
if ! [ -f /mnt/boot/config.json ]; then
	cp /config.json /mnt/boot/config.json
else
	echo "INFO: Reusing already existing config.json in docker volume."
fi
EOF

echo "INFO: Running resinOS as container resinos-in-container-$container_id ..."
if docker run -ti --rm --privileged \
		-e "container=docker" \
		--stop-timeout=30 \
		--dns 127.0.0.2 \
		--name "resinos-in-container-$container_id" \
		--stop-signal SIGRTMIN+3 \
		-v "$SCRIPTPATH/conf/systemd-watchdog.conf:/etc/systemd/system.conf.d/watchdog.conf:ro" \
		-v "$resin_boot_volume" \
		-v "$resin_state_volume" \
		-v "$resin_data_volume" \
		$docker_extra_args \
		$detach \
		"$image" \
		/sbin/init; then
	if [ "$detach" != "" ]; then
		echo "INFO: resinOS container running as resinos-in-container-$container_id"
	else
		echo "ERROR: Running docker container."
	fi
else
	if [ "$detach" != "" ]; then
		echo "ERROR: Running docker container."
	else
		echo "INFO: ResinOS container stopped."
	fi
fi

if [ "$detach" = "" ] && [ "$clean_volumes" = "yes" ]; then
	echo "Cleaning volumes..."
	docker volume rm "resin-boot-$container_id" "resin-state-$container_id" "resin-data-$container_id" &> /dev/null
fi
