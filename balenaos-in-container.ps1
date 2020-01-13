<#
.SYNOPSIS

Run balenaOS image in a docker container.

.DESCRIPTION

Run balenaOS image in a docker container.

.PARAMETER image
Docker image to be used as balenaOS.
Mandatory argument.

.PARAMETER prefix
Use a specific prefix for the docker container and volumes. This allows for reusing volumes.
Default: "balena-"

.PARAMETER id
Use a specific id for the docker container and volumes. This allows for reusing volumes.
Default: randomly generated.

.PARAMETER config
The config.json path. This you can download from balena.io dashboard.
Mandatory argument.
Alias: -c

.PARAMETER detach
Run the container in the background and print container ID (just like "docker run -d")
Default: no.
Alias: -d

.PARAMETER extra_args
Additional arguments for docker run (e.g. to add bind mounts)

.PARAMETER clean_volumes
If volumes are not planned to be reused, you can take advantage of this argument to clean up the system. Cannot be used together with -d.
Default: no.

.PARAMETER no-tty
Don't allocate a pseudo-TTY and don't keep STDIN open (docker run without "-it").
Default: no.

.EXAMPLE

PS> .\balenaos-in-container.ps1 -image resin/resinos:2.46.0_rev1.dev-intel-nuc  -id test  -c "$PWD\config.json" -detach

#>
param ([Parameter(Mandatory,HelpMessage="Docker image to be used as balenaOS. Mandatory Argument")][string]$image,[switch]$no_tty, [Parameter(Mandatory,HelpMessage="The config.json path. This you can download from balena.io dashboard.
Mandatory argument.")][Alias('c')][string]$config_path,[string]$prefix,[string]$id, [switch]$clean_volumes,[switch][Alias('d')]$detach, [string]$extra_args)

#check if config file exists
if(![System.IO.File]::Exists($config_path)){
    echo "ERROR: No such file: ${config_path}"
    exit 1
}

if(!$id){
    $docker_postfix = Get-Random
}else{
    $docker_postfix = $id
}

if($prefix){
    $docker_prefix = $prefix
}else{
    $docker_prefix = "balena-"
}

if($detach){
    $detachVal = "--detach"
}else{
    $detachVal = ""
}

if($no_tty){
    $no_ttyVal = ""
}else{
    $no_ttyVal = "-ti"
}

#check if docker is running 
docker info 2>&1>$null

if ($LastExitCode -ne 0)
{
    echo "ERROR: Docker needs to be running on your host machine."
    exit 1
}

# Create volumes
$balena_boot_volume="${docker_prefix}boot-${docker_postfix}"
$balena_state_volume="${docker_prefix}state-${docker_postfix}"
$balena_data_volume="${docker_prefix}data-${docker_postfix}"

foreach ( $volume in $balena_boot_volume,$balena_state_volume, $balena_data_volume ){
    docker volume inspect $volume 2>&1>$null
    if ($LastExitCode -eq 0){
        echo "INFO: Reusing ${volume} docker volume..."
    }else{
        echo "INFO: Creating ${volume} docker volume..."
        docker volume create $volume 2>&1>$null
        if ($volume -eq $balena_boot_volume){
            # Populate the boot volume with the config.json on creation
            docker run -i --rm -v ${config_path}:/config.json -v ${volume}:/mnt/boot $image sh -c "if ! [ -f /mnt/boot/config.json ]; then cp /config.json /mnt/boot/config.json; else echo 'INFO: Reusing already existing config.json in docker volume.'; fi" 
        }
    }
}

$container_name="${docker_prefix}container-${docker_postfix}"
echo "INFO: Running balenaOS as container ${container_name} ..."

docker run $no_ttyVal --rm --privileged `
       --stop-timeout=30 `
       -e "container=docker" `
       --name ${container_name} `
       --stop-signal SIGRTMIN+3 `
       -v /lib/modules:/lib/modules:ro `
       -v "${PSScriptRoot}/conf/systemd-watchdog.conf:/etc/systemd/system.conf.d/watchdog.conf:ro" `
       -v "${PSScriptRoot}/aufs2overlay.sh:/aufs2overlay" `
       -v "${balena_boot_volume}:/mnt/boot" `
       -v "${balena_state_volume}:/mnt/state" `
       -v "${balena_data_volume}:/mnt/data" `
       $extra_args `
       ${detachVal} `
       ${image} `
       sh -c '/aufs2overlay;exec /sbin/init' 


if ($LastExitCode -eq 0){
    if ($detach -ne ""){
        echo "INFO: balenaOS container running as ${container_name}"
    }
}
elseif ($LastExitCode -eq 130 -or $LastExitCode -eq 137) {
    echo "INFO: balenaOS container stopped."
}
else{
    echo "ERROR: Running docker container."
}

if (!$detach -and $clean_volumes){
	echo "Cleaning volumes..."
    docker volume rm "${balena_boot_volume}" "${balena_state_volume}" "${balena_data_volume}" 2>&1>$null
}
