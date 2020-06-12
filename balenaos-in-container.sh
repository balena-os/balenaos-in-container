#!/bin/bash

set -e

config_path=""
docker_prefix="balena-"
docker_postfix="$RANDOM"
clean_volumes=no
docker_extra_args=""
detach=""
no_tty="-ti"

function help {
	cat << EOF
Run balenaOS image in a docker container.
$0 <ARGUMENTS>

ARGUMENTS:
	-h, --help
		Print this message.
	--image <image>
		Docker image to be used as balenaOS.
		Mandatory argument.
	--prefix <prefix>
		Use a specific prefix for the docker container and volumes. This allows for
		reusing volumes.
		Default: "balena-"
	--id <id>
		Use a specific id for the docker container and volumes. This allows for
		reusing volumes.
		Default: randomly generated.
	-c, --config <config>
		The config.json path. This you can download from balena.io dashboard.
	-d, --detach
		Run the container in the background and print container ID (just like "docker run -d")
		Default: no.
	--extra-args <arguments>
		Additional arguments for docker run (e.g. to add bind mounts)
	--clean-volumes
		If volumes are not planned to be reused, you can take advantage of this
		argument to clean up the system. Cannot be used together with -d.
		Default: no.
	--no-tty
		Don't allocate a pseudo-TTY and don't keep STDIN open (docker run without "-it").
		Default: no.
	--tc
		Runs docker-tc and passes labels to the container that allow shaping the container network.
		See https://github.com/lukaszlach/docker-tc#usage for possible values.
		NOTE: This accepts a space-separated list of labels, each gets prefixed with "com.docker-tc."
		The "com.docker-tc.enable=1" label is applied automatically.

EOF
}

# realpath is not available on Mac OS, define it as a bash function if it's not found
command -v realpath >/dev/null 2>&1 || {
    realpath() {
        [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
    }
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
		--prefix)
			if [ -z "$2" ]; then
				log ERROR "\"$1\" argument needs a value."
			fi
			docker_prefix="$2"
			shift
			;;
		--id)
			if [ -z "$2" ]; then
				log ERROR "\"$1\" argument needs a value."
			fi
			docker_postfix="$2"
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
		--no-tty)
			no_tty=""
			;;
		--tc)
			if [ -z "$2" ]; then
				log ERROR "\"$1\" argument needs a value."
			fi
			tc_extra_args="--label com.docker-tc.enabled=1"
			for rule in $2; do
			    tc_extra_args="${tc_extra_args} --label com.docker-tc.${rule}"
			done
			shift
			;;
		*)
			echo "ERROR: Unrecognized option $1."
			help
			exit 1
			;;
	esac
	shift
done

if [ -z "$image" ]; then
	echo "ERROR: --image required but not provided."
	exit 1
fi

if ! docker info &> /dev/null; then
    echo "ERROR: Docker needs to be running on your host machine."
    exit 1
fi


if [ -n "$tc_extra_args" ]; then
    # create a separate network for the container
    # this is required for docker-tc to work
    netname="balena-container-${docker_postfix}-net"

    echo "INFO: Creating ${netname} container network..."
    docker network create "${netname}" >/dev/null || true
    trap_remove_network () { echo "INFO: Removing ${netname} container network..."; docker network rm "${netname}"; }
    docker_extra_args="${docker_extra_args} --network ${netname}"

    echo "INFO: Running docker-tc container..."
    docker run -d --rm \
	--name=docker-tc \
	--network=host \
	--cap-add=NET_ADMIN \
	--mount="type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock" \
	--mount="type=tmpfs,target=/var/docker-tc" \
	lukaszlach/docker-tc || true
    trap_stop_dockertc () { echo "INFO: Stopping docker-tc container..."; docker stop -t 5 docker-tc >/dev/null || yes; }

    docker_extra_args="${docker_extra_args} ${tc_extra_args}"
    trap '{ trap_remove_network; trap_stop_dockertc; }' EXIT ERR
fi

# Get absolute path of the script location
# In this way we can reference any file relative to the script path easily
# Get the absolute script location
SCRIPTPATH="$(cd "$(dirname "$0")" ; pwd)"

balena_boot_volume="${docker_prefix}boot-${docker_postfix}"
balena_state_volume="${docker_prefix}state-${docker_postfix}"
balena_data_volume="${docker_prefix}data-${docker_postfix}"
for volume in ${balena_boot_volume} ${balena_state_volume} ${balena_data_volume}; do
	if docker volume inspect "${volume}" &> /dev/null; then
		echo "INFO: Reusing ${volume} docker volume..."
	else
		echo "INFO: Creating ${volume} docker volume..."
		docker volume create --label "io.balena.balenaos-in-container=${volume}" "${volume}" &> /dev/null
		if [[ "${volume}" == "${balena_boot_volume}" ]]; then
			# Populate the boot volume with the config.json on creation
			if [ -z "$config_json" ]; then
			    config_json_mount="type=tmpfs"
			else
			    config_json_mount="type=bind,src=${config_json}"
			fi
			docker run -i --rm \
				--mount type=volume,src="${volume}",target=/mnt/boot \
				--mount "$config_json_mount",target=/config.json \
				"$image" sh << EOF
if ! [ -f /mnt/boot/config.json ]; then
	if [ -f /config.json ]; then
	    cp /config.json /mnt/boot/config.json
	else
	    echo "{}" > /mnt/boot/config.json
	fi
else
	echo "INFO: Reusing already existing config.json in docker volume."
fi
EOF
		fi
	fi
done

container_name="${docker_prefix}container-${docker_postfix}"
echo "INFO: Running balenaOS as container ${container_name} ..."
#shellcheck disable=SC2086
if docker run $no_tty --rm \
		-e "container=docker" \
		--stop-timeout=30 \
		--dns 127.0.0.2 \
		--name "${container_name}" \
		--stop-signal SIGRTMIN+3 \
		-v /lib/modules:/lib/modules:ro \
		-v "$SCRIPTPATH/conf/systemd-watchdog.conf:/etc/systemd/system.conf.d/watchdog.conf:ro" \
		-v "$SCRIPTPATH/aufs2overlay.sh:/aufs2overlay" \
		-v "${balena_boot_volume}:/mnt/boot" \
		-v "${balena_state_volume}:/mnt/state" \
		-v "${balena_data_volume}:/mnt/data" \
		--mount type=tmpfs,target=/run \
		--mount type=tmpfs,target=/sys/fs/cgroup \
		--cap-add NET_ADMIN \
		--cap-add SYS_ADMIN \
		--cap-add SYS_RESOURCE \
		--security-opt 'apparmor:unconfined' \
		--security-opt 'seccomp:unconfined' \
		--sysctl 'net.ipv4.ip_forward=1' \
		$docker_extra_args \
		$detach \
		"$image" \
		sh -c '/aufs2overlay;exec /sbin/init'; then
	if [ "$detach" != "" ]; then
		echo "INFO: balenaOS container running as ${container_name}"
	else
		echo "ERROR: Running docker container."
	fi
else
	if [ "$detach" != "" ]; then
		echo "ERROR: Running docker container."
	else
		echo "INFO: balenaOS container stopped."
	fi
fi

if [ "$detach" = "" ] && [ "$clean_volumes" = "yes" ]; then
	echo "Cleaning volumes..."
	docker volume rm "${balena_boot_volume}" "${balena_state_volume}" "${balena_data_volume}" &> /dev/null
fi
