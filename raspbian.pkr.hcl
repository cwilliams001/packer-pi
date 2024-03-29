source "arm" "raspbian" {
  file_urls             = ["https://downloads.raspberrypi.com/raspios_oldstable_full_arm64/images/raspios_oldstable_full_arm64-2023-12-06/2023-12-05-raspios-bullseye-arm64-full.img.xz"]
  file_checksum_url     = "https://downloads.raspberrypi.com/raspios_oldstable_full_arm64/images/raspios_oldstable_full_arm64-2023-12-06/2023-12-05-raspios-bullseye-arm64-full.img.xz.sha256"
  file_checksum_type    = "sha256"
  file_target_extension = "xz"
  file_unarchive_cmd    = ["xz", "-d", "$ARCHIVE_PATH"]
  image_build_method    = "reuse"
  image_path            = "raspbian.img"
  image_size            = "16G"
  image_type            = "dos"

  image_partitions {
    filesystem   = "fat"
    start_sector = "8192"
    mountpoint   = "/boot"
    name         = "boot"
    size         = "256M"
    type         = "c"
  }

  image_partitions {
    name         = "root"
    type         = "83"
    start_sector = "532480"
    filesystem   = "ext4"
    size         = "0"
    mountpoint   = "/"
  }


  image_chroot_env             = ["PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"]
  qemu_binary_source_path      = "/usr/bin/qemu-aarch64-static"
  qemu_binary_destination_path = "/usr/bin/qemu-aarch64-static"

}


locals {
  formatted_timestamp = formatdate("YYYY-MM-DD-hh-mm-ss", timestamp())
}

# Cell Hat APN name
variable "apn_name" {
  type = string
}

build {
  sources = ["source.arm.raspbian"]

  provisioner "shell" {
    inline = [
      "mkdir -p /opt/source/logs"
    ]
  }

  # Shell provisioner to run the main provision script
  provisioner "shell" {
    script = "./setup-scripts/provision-pi.sh"
  }

  # File provisioner to download the log file created by provision-pi.sh during the build process
  provisioner "file" {
    source = "/opt/source/logs/provision-pi.log"
    destination = "provision-pi.log-${local.formatted_timestamp}"
    direction = "download"
  }

  # Remove the log file from the Raspberry Pi
  provisioner "shell" {
    inline = [
      "rm /opt/source/logs/provision-pi.log"
    ]
  }

  # Shell provisioner to create a directory and write the APN name into a file
  provisioner "shell" {
    inline = [
      "mkdir -p /opt/source",
      "echo '${var.apn_name}' > /opt/source/apn_name.txt"
    ]
  }

  # File provisioners to transfer various configuration files and scripts to the Raspberry Pi
  provisioner "file" {
    source      = "./wireguard-confs/peer1.conf"
    destination = "/etc/wireguard/wg0.conf"
  }

  provisioner "shell" {
    inline = [
      "chmod 600 /etc/wireguard/wg0.conf"
    ]
  }

  provisioner "file" {
    source      = "./setup-scripts/start-wireguard-delayed.sh"
    destination = "/opt/source/start-wireguard-delayed.sh"
  }

  provisioner "shell" {
    inline = [
      "chmod +x /opt/source/start-wireguard-delayed.sh"
    ]
  }

  provisioner "file" {
    source      = "./setup-scripts/cell-hat-setup.sh"
    destination = "/opt/source/cell-hat-setup.sh"
  }

  provisioner "shell" {
    inline = [
      "chmod +x /opt/source/cell-hat-setup.sh"
    ]
  }

  provisioner "file" {
    source      = "./setup-scripts/enable_gps"
    destination = "/sbin/enable_gps"
  }

  provisioner "shell" {
    inline = [
      "chmod +x /sbin/enable_gps"
    ]
  }

  provisioner "file" {
    source      = "./setup-scripts/minirc.dfl"
    destination = "/etc/minicom/minirc.dfl"
  }

  provisioner "shell" {
    inline = [
      "chmod 644 /etc/minicom/minirc.dfl"
    ]
  }

  provisioner "file" {
    source      = "./kismet-files/kismet_httpd.conf"
    destination = "/etc/kismet/kismet_httpd.conf"
  }

  provisioner "file" {
    source      = "./kismet-files/kismet.conf"
    destination = "/etc/kismet/kismet.conf"
  }

  provisioner "file" {
    source      = "./kismet-files/kismet_logging.conf"
    destination = "/etc/kismet/kismet_logging.conf"
  }

  provisioner "file" {
    source      = "./setup-scripts/ufw-setup.sh"
    destination = "/opt/source/ufw-setup.sh"
  }

  provisioner "shell" {
    inline = [
      "chmod +x /opt/source/ufw-setup.sh"
    ]
  }

  # Shell provisioner to run the post-provision script
  post-processor "shell-local" {
    inline = [
      "mkdir -p /build/logs",
      "sha256sum /build/raspbian.img >> /build/logs/temp-image-sha256.sum",
      "mv /build/provision-pi.log-* /build/logs/",
      "LATEST_LOG=$(ls -Art /build/packer-build-*.log | tail -n 1)",
      "sh /build/post-provision-scripts/append_log.sh \"$LATEST_LOG\"",
      "mv /build/packer-build-*.log /build/logs/"
    ]
  }
}



