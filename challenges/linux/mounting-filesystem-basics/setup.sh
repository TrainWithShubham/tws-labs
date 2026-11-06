#!/bin/bash
set -euo pipefail

mkdir -p "$HOME/mount-audit/disks" "$HOME/mount-audit/etc"

# 1. Provision pre-formatted virtual disk image
truncate -s 5M "$HOME/mount-audit/disks/data-disk.img"
mkfs.ext4 -F -L data-vol "$HOME/mount-audit/disks/data-disk.img" >/dev/null 2>&1

# 2. Ensure mount point does NOT exist initially
rm -rf "$HOME/mount-audit/mnt"

# 3. Provision defective fstab with placeholder UUID and bad options
cat << 'EOF' > "$HOME/mount-audit/etc/fstab"
# Simulated Node Filesystem Table
UUID=00000000-0000-0000-0000-000000000000 mount-audit/mnt/data ext4 defaults,badopt,noexec_typo 0 0
EOF
chmod 0644 "$HOME/mount-audit/etc/fstab"

rm -f "$HOME/mount-audit/.mount-audit.passed"

# 4. Verification tool
cat << 'VERIFY_EOF' > "$HOME/mount-audit/verify-mounts"
#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# 1. Verify mount directory exists with 0755
if [ ! -d "mnt/data" ]; then
  echo "FAIL: mnt/data directory does not exist." >&2
  exit 1
fi
mode=$(stat -c '%a' "mnt/data" 2>/dev/null || stat -f '%Lp' "mnt/data" 2>/dev/null)
if [ "$mode" != "755" ]; then
  echo "FAIL: mnt/data mode is $mode (expected 755)." >&2
  exit 1
fi

# 2. Verify fstab UUID matches data-disk.img
actual_uuid=$(blkid disks/data-disk.img | grep -o 'UUID="[^"]*"' | cut -d'"' -f2)
if [ -z "$actual_uuid" ]; then
  echo "FAIL: Cannot read UUID from disks/data-disk.img." >&2
  exit 1
fi

if ! grep -q "UUID=$actual_uuid" etc/fstab; then
  echo "FAIL: etc/fstab does not contain the correct disk UUID ($actual_uuid)." >&2
  exit 1
fi

# 3. Verify options and dump/pass
if ! grep -Eq "UUID=$actual_uuid[[:space:]]+mount-audit/mnt/data[[:space:]]+ext4[[:space:]]+defaults(,nofail)?[[:space:]]+0[[:space:]]+2" etc/fstab; then
  echo "FAIL: etc/fstab line must specify 'mount-audit/mnt/data ext4 defaults 0 2'." >&2
  exit 1
fi

cat << 'MARKER_EOF' > ".mount-audit.passed"
{
  "status": "PASSED",
  "verified_at": "2026-11-05T12:00:00Z",
  "audit": "mounting-filesystem-basics"
}
MARKER_EOF

echo "SUCCESS: Filesystem mount table verified successfully."
exit 0
VERIFY_EOF
chmod 0755 "$HOME/mount-audit/verify-mounts"
