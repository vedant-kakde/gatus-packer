#!/bin/bash
set -e

# Remove unnecessary packages while keeping docker and essential tools
apt-get autoremove -y
apt-get clean

# Clear package lists
rm -rf /var/lib/apt/lists/*

# Clear audit logs
if [ -f /var/log/audit/audit.log ]; then
    cat /dev/null > /var/log/audit/audit.log
fi
if [ -f /var/log/wtmp ]; then
    cat /dev/null > /var/log/wtmp
fi
if [ -f /var/log/lastlog ]; then
    cat /dev/null > /var/log/lastlog
fi

# Clear SSH host keys (will be regenerated on first boot)
rm -f /etc/ssh/ssh_host_*

# Clear shell history
cat /dev/null > ~/.bash_history
history -c

# Remove temporary files
rm -rf /tmp/*
rm -rf /var/tmp/*

# Clear machine ID
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

# Clean cloud-init
cloud-init clean -l

# Remove setup script but keep the config
rm -f /tmp/setup.sh

echo "Cleanup completed successfully"
