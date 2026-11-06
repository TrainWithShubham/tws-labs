real_uuid=$(blkid mount-audit/disks/data-disk.img | grep -o 'UUID="[^"]*"' | cut -d'"' -f2)
sed -i "s/UUID=[a-f0-9-]*/UUID=$real_uuid/" mount-audit/etc/fstab
