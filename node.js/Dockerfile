FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update package lists, upgrade installed packages to patch OS vulnerabilities, and clean cache
RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get autoremove -y --purge && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Keep remaining application setup below
