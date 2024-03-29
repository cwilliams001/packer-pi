
# Packer-Pi

## Overview
Packer-Pi is an automation tool for creating customized Raspberry Pi images. It utilizes Packer to streamline the setup process, integrating various configurations and scripts to prepare Raspberry Pi devices for specific uses.

## Key Components
- **Setup-Scripts Folder:** Contains essential scripts like `provision-pi.sh` for setting up services and configurations including GPSD, cell hat, WireGuard, UFW, and system hardening.
- **Config.pkrvars.hcl:** Defines variables, such as the APN for cell hat setup.
- **Wireguard-Confs Folder:** Place for WireGuard configuration files. Rename your file to `peer1.conf` for compatibility.
- **Kismet-files Folder:** Place for Kismet configuration files. That are copied to the Kismet configuration directory during the build process.
- **Raspbian.pkr.hcl:** Packer configuration script for building the Raspberry Pi image.

## Prerequisites
- Docker: Install Docker for image building (preferably `sudo apt install docker.io` on Ubuntu/Debian).

## Building the Image
1. Pull the Packer builder image:
   ```
   sudo docker pull mkaczanowski/packer-builder-arm:latest
   ```
2. Run the Packer build command (ensure you're in the directory with `config.pkrvars.hcl` and `raspbian.pkr.hcl`):
   ```
   sudo docker run --rm -it --privileged -v /dev:/dev -v ${PWD}:/build -e PACKER_LOG_PATH="packer-build-$(date +%Y-%m-%d_%H-%M-%S).log" mkaczanowski/packer-builder-arm:latest build -var-file=config.pkrvars.hcl raspbian.pkr.hcl
   ```
The second command in the building process of the Packer-Pi image serves several important functions:

1. **Running Docker Container in Privileged Mode:** `--privileged` grants the Docker container extended permissions, allowing it to access the host's devices. This is necessary for Packer to manipulate and create images directly from the host system.

2. **Mounting Volumes:** `-v /dev:/dev -v ${PWD}:/build` mounts the host's `/dev` directory and the current working directory (`${PWD}`) into the container. This allows the Docker container to access necessary devices and the files in your working directory (like `config.pkrvars.hcl` and `raspbian.pkr.hcl`).

3. **Tagging Build Logs:** `-e PACKER_LOG_PATH="packer-build-$(date +%Y-%m-%d_%H-%M-%S).log"` tags the build logs with a timestamp, and places the log in your build directory, allowing for tracking each build individually.

4. **Executing Packer Build:** The final part `mkaczanowski/packer-builder-arm:latest build -var-file=config.pkrvars.hcl raspbian.pkr.hcl` runs the Packer build process using the `mkaczanowski/packer-builder-arm` image. It specifies the variable file (`config.pkrvars.hcl`) and the Packer template file (`raspbian.pkr.hcl`) to use for building the Raspberry Pi image.


## Enhanced Logging and Build Monitoring

Packer-Pi now incorporates logging to provide detailed insights into the build process and system configurations:

- **Build Command Update**: The Docker run command now includes the `-e PACKER_LOG_PATH` environment variable, dynamically naming the build log file with a timestamp. This allows for tracking each build individually. 

- **Provisioning Log (provision-pi.log)**: The `provision-pi.sh` script, part of the setup process, generates a separate log file (`provision-pi.log`) that records the provisioning details. This file is downloaded post-build into the logs directory for review.

- **Cumulative Build Log**: The `append_log.sh` script in the `post-provision-scripts` folder merges the detailed Packer build logs with the SHA256 checksum of the built image into `cumulative-build-log.txt`. This file offers a comprehensive view of the entire build process, including system updates and configurations.

- **Accessing Logs**: Users can access individual provisioning logs for specific insights or refer to the cumulative log for an overarching view of the build history, including checksums for integrity verification.

This allows for a transparent and traceable build process, allowing users to monitor changes, identify potential issues, and maintain a historical record of Raspberry Pi image builds.

