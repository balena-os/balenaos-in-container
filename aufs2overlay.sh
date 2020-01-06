sed -i "s/-s aufs/-s overlay2/g" /lib/systemd/system/balena.service; \
if [ -f /etc/systemd/system/balena.service.d/balena.conf ]; then \
    sed -i "s/-s aufs/-s overlay2/g" /etc/systemd/system/balena.service.d/balena.conf; \
else \
    echo "No drop-in found. Most probably you don't run a development image."; \
fi
