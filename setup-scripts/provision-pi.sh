#!/bin/bash

LOG_DIR="/opt/source/logs"
LOG_FILE="$LOG_DIR/provision-pi.log"

mkdir -p $LOG_DIR
touch $LOG_FILE

# Function to append output to the log file
log() {
    echo "[$(date --rfc-3339=seconds)]: $*" | tee -a "$LOG_FILE"
}

# Starting provisioning process
log "------------------Starting provisioning...--------------------"

# Set frontend to non-interactive to avoid prompts during package installations
export DEBIAN_FRONTEND=noninteractive

# Enable SSH
log "------------------Enabling SSH...------------------"
touch /boot/ssh 2>&1 | tee -a "$LOG_FILE"

# Disable Bluetooth
log "------------------Disabling Bluetooth...------------------"
echo "dtoverlay=disable-bt" >> /boot/config.txt 2>&1 | tee -a "$LOG_FILE"

# Create new user
log "------------------Creating new user...------------------"
useradd -m -s /bin/bash ots
echo "ots:\$6\$eWm4YyeNVc.LZTFK\$I4iZNZNKTLB9SUpLqDBMjVI5mumKD7bJL59mgIsXGjtkPkvhRSE1gdWiIGVjEz3Yl05IYK8yLcalHTXmt3ET10" | chpasswd -e 2>&1 | tee -a "$LOG_FILE"
usermod -aG sudo ots 2>&1 | tee -a "$LOG_FILE"

# Remove the first boot wizard user
log "------------------Removing first boot wizard user...------------------"
userdel -r rpi-first-boot-wizard 2>&1 | tee -a "$LOG_FILE"

# Enable zswap with default settings
log "------------------Enabling zswap...------------------"
sed -i -e 's/$/ zswap.enabled=1/' /boot/cmdline.txt 2>&1 | tee -a "$LOG_FILE"

# Force automatic rootfs expansion on first boot
log "------------------Enabling automatic rootfs expansion on first boot...------------------"
wget -O /etc/init.d/resize2fs_once https://raw.githubusercontent.com/RPi-Distro/pi-gen/master/stage2/01-sys-tweaks/files/resize2fs_once 2>&1 | tee -a "$LOG_FILE"
chmod +x /etc/init.d/resize2fs_once 2>&1 | tee -a "$LOG_FILE"
systemctl enable resize2fs_once 2>&1 | tee -a "$LOG_FILE"

# Skip initial setup wizard
log "------------------Skipping initial setup wizard...------------------"
echo "pi ALL=NOPASSWD: /usr/sbin/raspi-config, /sbin/shutdown" > /etc/sudoers.d/piwiz 2>&1 | tee -a "$LOG_FILE"
rm /etc/xdg/autostart/piwiz.desktop 2>&1 | tee -a "$LOG_FILE"

# Set up locale, keyboard layout, and timezone
log "------------------Setting up locale, keyboard layout, and timezone...------------------"
raspi-config nonint do_change_locale en_US.UTF-8 2>&1 | tee -a "$LOG_FILE"
raspi-config nonint do_configure_keyboard us 2>&1 | tee -a "$LOG_FILE"
raspi-config nonint do_change_timezone America/New_York 2>&1 | tee -a "$LOG_FILE"

# Update the System
log "------------------Updating the system...------------------"
apt-get update 2>&1 | tee -a "$LOG_FILE"
apt-get upgrade -y 2>&1 | tee -a "$LOG_FILE"
apt-get autoremove -y 2>&1 | tee -a "$LOG_FILE"
apt-get clean 2>&1 | tee -a "$LOG_FILE"

# Install Applications
log "------------------Installing applications...------------------"
apt-get install fail2ban minicom wireguard wireguard-tools build-essential libssl-dev libncurses5-dev libpcap-dev libsqlite3-dev libpcre3-dev libnl-3-dev libnl-genl-3-dev libnl-route-3-dev ethtool curl wget gnupg2 sqlite3 git python3-pip tshark traceroute tcptraceroute vim proxychains aircrack-ng hcxtools macchanger nmap tcpdump wavemon -y 2>&1 | tee -a "$LOG_FILE"

# Install Kismet
log "------------------Installing Kismet...------------------"
wget -O - https://www.kismetwireless.net/repos/kismet-release.gpg.key --quiet | gpg --dearmor | tee /usr/share/keyrings/kismet-archive-keyring.gpg >/dev/null 2>&1 | tee -a "$LOG_FILE"
echo 'deb [signed-by=/usr/share/keyrings/kismet-archive-keyring.gpg] https://www.kismetwireless.net/repos/apt/release/bullseye bullseye main' | tee /etc/apt/sources.list.d/kismet.list >/dev/null 2>&1 | tee -a "$LOG_FILE"
apt-get update 2>&1 | tee -a "$LOG_FILE"
apt-get install kismet -y 2>&1 | tee -a "$LOG_FILE"

# Install GPSD
log "------------------Installing GPSD...------------------"
apt-get install gpsd gpsd-clients -y 2>&1 | tee -a "$LOG_FILE"

# Configure GPSD
log "------------------Configuring GPSD...------------------"
bash -c 'cat << EOF > /etc/default/gpsd
START_DAEMON="true"
DEVICES="/dev/ttyUSB1"
GPSD_OPTIONS="-b -s 115200"
EOF' 2>&1 | tee -a "$LOG_FILE"

# Systemd service files and other configurations
log "------------------Configuring Systemd services and other settings...------------------"

# Create systemd service file for cell-hat-setup
log "------------------Creating systemd service file for cell-hat-setup...------------------"
cat << EOF > /etc/systemd/system/cell-hat-setup.service
[Unit]
Description=Cell Hat Setup
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash /opt/source/cell-hat-setup.sh
RemainAfterExit=yes
ExecStartPost=/bin/systemctl disable cell-hat-setup.service

[Install]
WantedBy=multi-user.target
EOF
log "Cell Hat Setup service file created."

# Enable the service so it runs on next boot
log "Enabling cell-hat-setup service..."
systemctl enable cell-hat-setup.service 2>&1 | tee -a "$LOG_FILE"

# Create Systemd Service for GPS
log "------------------Creating systemd service file for GPS...------------------"
cat << EOF > /etc/systemd/system/enable_gps.service
[Unit]
Description=Enable GPS Service
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/enable_gps
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
log "GPS service file created."

# Enable the GPS service so it runs on next boot
log "Enabling GPS service..."
systemctl enable enable_gps.service 2>&1 | tee -a "$LOG_FILE"

# Enable IP Forwarding
log "------------------Enabling IP Forwarding...------------------"
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf 2>&1 | tee -a "$LOG_FILE"
sysctl -p 2>&1 | tee -a "$LOG_FILE"

# Replace direct WireGuard start with delayed start script
log "------------------Replacing direct WireGuard start with delayed start script...------------------"
cat << EOF > /etc/systemd/system/start-wireguard-delayed.service
[Unit]
Description=Start WireGuard with Delay
After=network.target

[Service]
Type=simple
ExecStart=/opt/source/start-wireguard-delayed.sh

[Install]
WantedBy=multi-user.target
EOF
log "WireGuard delayed start script service file created."

# Enable the new service to run on boot
log "Enabling WireGuard delayed start service..."
systemctl enable start-wireguard-delayed.service 2>&1 | tee -a "$LOG_FILE"

# Create systemd service file for UFW setup
log "------------------Creating systemd service file for UFW setup...------------------"
cat << EOF > /etc/systemd/system/ufw-setup.service
[Unit]
Description=UFW Setup
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash /opt/source/ufw-setup.sh

[Install]
WantedBy=multi-user.target
EOF
log "UFW setup service file created."

# Enable the service to run on next boot
log "Enabling UFW setup service..."
systemctl enable ufw-setup.service 2>&1 | tee -a "$LOG_FILE"


# SSH Hardening
log "------------------SSH Hardening...------------------"
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config 2>&1 | tee -a "$LOG_FILE"
systemctl restart sshd 2>&1 | tee -a "$LOG_FILE"

# System cleanup
log "------------------System cleanup...------------------"
apt-get autoremove -y 2>&1 | tee -a "$LOG_FILE"
apt-get clean 2>&1 | tee -a "$LOG_FILE"

log "------------------Provisioning complete.------------------"


