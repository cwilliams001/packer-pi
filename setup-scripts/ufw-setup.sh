#!/bin/bash

# Install UFW
apt-get update
apt-get install -y ufw

# Enable UFW
ufw enable

# Apply UFW rules
ufw allow ssh
ufw allow 51820/udp
ufw allow 2501/tcp
ufw allow 3501/udp

# Reload UFW to apply changes
ufw reload

# Disable this script from running again on next boot
systemctl disable ufw-setup.service
