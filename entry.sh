#!/bin/sh

# switch storage driver to overlay2
units="/lib/systemd/system/balena.service"
if [ -f /etc/systemd/system/balena.service.d/balena.conf ]; then
	units="${units} /etc/systemd/system/balena.service.d/balena.conf"
fi
for unit in $units; do
	sed -i "s/-s aufs/-s overlay2/g" "${unit}"
done

# copy device-type.json into the place the supervisor looks for it
[ ! -f /mnt/boot/device-type.json ] && cp /resin-boot/device-type.json /mnt/boot/
# copy config.json into boot partition
[ ! -f /mnt/boot/config.json ] && cp /var/local/config.json /mnt/boot/

# Include self-signed CAs, should they exist
if [ -n "${BALENA_ROOT_CA}" ]; then
	if [ ! -e '/etc/ssl/certs/balenaRootCA.pem' ]; then
		echo "${BALENA_ROOT_CA}" | base64 --decode > /etc/ssl/certs/balenaRootCA.pem

		# Include the balenaRootCA in the system store for services like Docker
		mkdir -p /usr/local/share/ca-certificates
		cp /etc/ssl/certs/balenaRootCA.pem /usr/local/share/ca-certificates/balenaRootCA.crt
		update-ca-certificates
	fi
fi

echo net.ipv6.conf.all.disable_ipv6=1 >/etc/sysctl.d/disableipv6.conf
echo net.ipv6.conf.eth0.disable_ipv6=1 >>/etc/sysctl.d/disableipv6.conf
echo net.ipv6.conf.default.disable_ipv6=1 >>/etc/sysctl.d/disableipv6.conf


exec /sbin/init
