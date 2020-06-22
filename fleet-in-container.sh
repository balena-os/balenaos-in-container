#!/bin/bash

set -e

application=""
docker_extra_args=""
image=""
fleet_count="3"
only_create=no

function help {
	cat << EOF
Run a balenaOS fleet in docker containers.
$0 <ARGUMENTS>

ARGUMENTS:
	-h, --help
		Print this message.
	--application <app>
		Balena application for this fleet.
		Mandatory argument.
	--image <image>
		Docker image to be used as balenaOS.
		Mandatory argument.
	-n --count <number of containers>
		Number of containers to run in this fleet.
		Default: 3
	--only-create
		Skip actually bringing up the containers.
		Default: no
	--extra-args <arguments>
		Additional arguments for docker run (e.g. to add bind mounts)

We look looks for a directory named fleet_<app> under the current working directory.
Every <uuid>.config.json found will create a corresponding container.
Should the directory not exist, <n> configs will be generated for you.

If a Dockerfile is found in the fleet directory, it will built
and the image used for all containers.

If a directory named "data" is found in the fleet directory, it is mounted
under /mnt/data/fleet in all containers.

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
		-n|--count)
			if [ -z "$2" ]; then
				log ERROR "\"$1\" argument needs a value."
			fi
			fleet_count="$2"
			shift
			;;
		-a|--application)
			if [ -z "$2" ]; then
				log ERROR "\"$1\" argument needs a value."
			fi
			application="$2"
			shift
			;;
		--only-create)
			only_create=yes
			;;
		--extra-args)
			docker_extra_args="$2"
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

if [ -z "$image" ] || [ -z "$application" ]; then
	echo "ERROR: Required arguments not provided."
	help
	exit 1
fi

function detect_balenaos_version {
    ./balenaos-in-container.sh --image "${image}" --id versioncheck --unmanaged -d >/dev/null 2>&1
    sleep 4s
    docker exec -it balena-container-versioncheck cat /etc/os-release | grep '^VERSION_ID' | sed 's/VERSION_ID="\(.*\)"/\1/'
    docker kill balena-container-versioncheck >/dev/null 2>&1
}

fleet_dir="$(realpath "fleet_${application}")"
if [ ! -d "$fleet_dir" ]; then
    echo "INFO: Creating fleet at ${fleet_dir}..."
    mkdir -p "${fleet_dir}"

    echo "INFO: Detecting balenaOS version of ${image}..."
    image_version="$(detect_balenaos_version)"

    idx=0
    while [[ ${idx} -lt ${fleet_count} ]]; do
	idx=$((idx+1))
	device_uuid="$(hexdump -n 32 -e '"%0x"' /dev/urandom | head -c 32)"
	balena device register "${application}" --uuid "${device_uuid}"
	balena config generate --app "${application}" --version "${image_version}" --device "${device_uuid}" --network ethernet --appUpdatePollInterval 10 --output "${fleet_dir}/${device_uuid}.config.json"
    done
fi

if [ "$only_create" = "yes" ]; then
    exit 0
fi

echo "INFO: Bringing up fleet at ${fleet_dir}..."

# allow hotfixing the image the fleet uses
if [ -f "${fleet_dir}/Dockerfile" ]; then
    docker build -t "${image}.fleet" "${fleet_dir}"
    image="${image}.fleet"
fi

if [ -d "${fleet_dir}/data" ]; then
    docker_extra_args="${docker_extra_args} --mount=type=bind,src=${fleet_dir}/data,target=/mnt/data/fleet"
fi

fleet_label="io.balena.balenaos-in-container.fleet=${application}"
function fleet_up {
    echo "INFO: Bringing up fleet (${fleet_dir})..."
    for cfg in ${fleet_dir}/*.config.json; do
	"$(dirname "$0")/balenaos-in-container.sh" --prefix "${application}-" --image "${image}" --config "${cfg}" --extra-args "--label=${fleet_label} ${docker_extra_args}" --detach
    done
}
fleet_up

fleet_containers="$(docker container ls --filter label="${fleet_label}" --format '{{.ID}}')"

function fleet_down {
    echo "INFO: Bringing down fleet..."
    for cid in ${fleet_containers}; do
	docker stop -t 3 "${cid}" || { echo "ERROR: Failed to stop ${cid}"; true; }
    done
    echo "INFO: Cleaning up docker volumes..."
    docker volume prune --force --filter 'label=io.balena.balenaos-in-container' >/dev/null
}

trap '{ printf "\n"; fleet_down; exit 0; }' INT
docker container wait ${fleet_containers}
