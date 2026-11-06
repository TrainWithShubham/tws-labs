target_uuid=$(blkid disks-incident/devices/vol-data.img | grep -o 'UUID="[^"]*"' | cut -d'"' -f2)
sed -i "s/^VOLUME_UUID=.*/VOLUME_UUID=$target_uuid/" disks-incident/config/volume-registry.env
