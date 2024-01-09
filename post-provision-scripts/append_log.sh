#!/bin/bash

# Adds the current build timestamp to the cumulative log file
echo "Build Timestamp: $(date)" >> /build/logs/cumulative-build-log.txt

# Adds a section header for the SHA256 checksum in the log file
echo "SHA256 Checksum:" >> /build/logs/cumulative-build-log.txt

# Appends the contents of the SHA256 checksum file to the cumulative log file
cat /build/logs/temp-image-sha256.sum >> /build/logs/cumulative-build-log.txt

# Adds a section header for the build log in the cumulative log file
echo "Build Log:" >> /build/logs/cumulative-build-log.txt

# Appends the contents of the current build's log file (passed as an argument) to the cumulative log file
cat "$1" >> /build/logs/cumulative-build-log.txt

# Adds a separator line for readability and to denote the end of the current build's log entry
echo '--------------------####################################################---------------------' >> /build/logs/cumulative-build-log.txt

