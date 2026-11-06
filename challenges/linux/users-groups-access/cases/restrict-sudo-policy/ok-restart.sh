sed -i 's|NOPASSWD: ALL|NOPASSWD: /usr/bin/systemctl restart app|' access/sudoers.d/deploy-agent
