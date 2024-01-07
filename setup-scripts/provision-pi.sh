#!/bin/bash

# Set frontend to non-interactive to avoid prompts during package installations
export DEBIAN_FRONTEND=noninteractive

# enable SSH
touch /boot/ssh

# Disable Bluetooth
echo "dtoverlay=disable-bt" >> /boot/config.txt

# Create new user (replace 'newuser' and 'your-password-hash' with your desired username and password hash)
# Generate a hash for a password using the following command "openssl passwd -6 your-password-here"
# Use "\" to escape the "$" in the password hash
useradd -m -s /bin/bash ots
echo "ots:\$6\$eWm4YyeNVc.LZTFK\$I4iZNZNKTLB9SUpLqDBMjVI5mumKD7bJL59mgIsXGjtkPkvhRSE1gdWiIGVjEz3Yl05IYK8yLcalHTXmt3ET10" | chpasswd -e
usermod -aG sudo ots

# Remove the first boot wizard user
userdel -r rpi-first-boot-wizard

# enable zswap with default settings
sed -i -e 's/$/ zswap.enabled=1/' /boot/cmdline.txt

# force automatic rootfs expansion on first boot:
# https://forums.raspberrypi.com/viewtopic.php?t=174434#p1117084
wget -O /etc/init.d/resize2fs_once https://raw.githubusercontent.com/RPi-Distro/pi-gen/master/stage2/01-sys-tweaks/files/resize2fs_once
chmod +x /etc/init.d/resize2fs_once
systemctl enable resize2fs_once

# Skip initial setup wizard
echo "pi ALL=NOPASSWD: /usr/sbin/raspi-config, /sbin/shutdown" > /etc/sudoers.d/piwiz
rm /etc/xdg/autostart/piwiz.desktop

# Set up locale, keyboard layout, and timezone
raspi-config nonint do_change_locale en_US.UTF-8
raspi-config nonint do_configure_keyboard us
raspi-config nonint do_change_timezone America/New_York

# Update the System
apt update && apt upgrade -y
apt autoremove -y && apt clean

# Install Applications
apt install fail2ban minicom wireguard wireguard-tools build-essential libssl-dev libncurses5-dev libpcap-dev libsqlite3-dev libpcre3-dev libnl-3-dev libnl-genl-3-dev libnl-route-3-dev ethtool curl wget gnupg2 sqlite3 git python3-pip tshark traceroute tcptraceroute vim proxychains aircrack-ng hcxtools macchanger nmap tcpdump wavemon -y

# Install Kismet
wget -O - https://www.kismetwireless.net/repos/kismet-release.gpg.key --quiet | gpg --dearmor | sudo tee /usr/share/keyrings/kismet-archive-keyring.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/kismet-archive-keyring.gpg] https://www.kismetwireless.net/repos/apt/release/bullseye bullseye main' | sudo tee /etc/apt/sources.list.d/kismet.list >/dev/null
apt update 
apt install kismet -y


#Install GPSD
apt install gpsd gpsd-clients -y

# Configure GPSD
# Note: Replace '/dev/ttyUSB1' with your actual GPS device path if different
bash -c 'cat << EOF > /etc/default/gpsd
START_DAEMON="true"
DEVICES="/dev/ttyUSB1"
GPSD_OPTIONS="-b -s 115200"
EOF'

# Restart GPSD to apply changes
sudo systemctl restart gpsd

# Create systemd service file for cell-hat-setup

echo "[Unit]
Description=Cell Hat Setup
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash /opt/source/cell-hat-setup.sh
RemainAfterExit=yes
ExecStartPost=/bin/systemctl disable cell-hat-setup.service

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/cell-hat-setup.service

# Enable the service so it runs on next boot
systemctl enable cell-hat-setup.service


# Create Systemd Service for GPS
echo "[Unit]
Description=Enable GPS Service
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/enable_gps
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/enable_gps.service

# Enable the GPS service so it runs on next boot
systemctl enable enable_gps.service

# Enable IP Forwarding
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p

# Replace direct WireGuard start with delayed start script
echo "[Unit]
Description=Start WireGuard with Delay
After=network.target

[Service]
Type=simple
ExecStart=/opt/source/start-wireguard-delayed.sh

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/start-wireguard-delayed.service

# Enable the new service to run on boot
systemctl enable start-wireguard-delayed.service

# Create systemd service for UFW setup
echo "[Unit]
Description=UFW Setup
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash /opt/source/ufw-setup.sh

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/ufw-setup.service

# Enable the service to run on next boot
systemctl enable ufw-setup.service

# SSH Hardening
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart sshd

# System cleanup
apt autoremove -y && apt clean

