#!/bin/bash

set -e

config_path=""
container_id="$RANDOM"
clean_volumes=no

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
	--clean-volumes
		If volumes are not planned to be reused, you can take advantage of this
		argument to clean up the system.
		Default: no.
EOF
}

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
resin_boot_volume_path=$(docker volume inspect resin-boot-$container_id | jq -r '.[0].Mountpoint')

echo "INFO: Populating config.json in resin-boot-$container_id... This operation needs root access."
if sudo ls "$resin_boot_volume_path/config.json" &> /dev/null; then
	echo "INFO: Reusing already existing config.json in resin-boot-$container_id docker volume."
else
	sudo cp "$config_json" "$resin_boot_volume_path/config.json"
fi

echo "INFO: Running resinOS as container resinos-in-container-$container_id ..."
if docker run --rm --privileged \
		-e "container=docker" \
		--stop-timeout=20 \
		--dns 127.0.0.2 \
		--name "resinos-in-container-$container_id" \
		--stop-signal SIGRTMIN+3 \
		-v /lib/modules:/lib/modules:ro \
		-v "$resin_boot_volume" \
		-v "$resin_state_volume" \
		-v "$resin_data_volume" \
		"$image" \
		/sbin/init &> /dev/null; then
	echo "ERROR: Running docker container."
else
	echo "INFO: ResinOS container stopped."
fi

if [ "$clean_volumes" = "yes" ]; then
	echo "Cleaning volumes..."
	docker volume rm "resin-boot-$container_id" "resin-state-$container_id" "resin-data-$container_id" &> /dev/null
fi
