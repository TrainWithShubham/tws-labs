real_uuid=$(blkid mount-audit/disks/data-disk.img | grep -o 'UUID="[^"]*"' | cut -d'"' -f2)
echo "UUID=$real_uuid mount-audit/mnt/data ext4 bad_option 0 2" > mount-audit/etc/fstab
