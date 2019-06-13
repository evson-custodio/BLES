#!/bin/bash

# Update System
sudo ./update.sh

# Install lsb-release package if not present
sudo apt install -y lsb-release

# System id (Ubuntu, Debian...)
id="$(lsb_release -s -i)"

# System Distribution (bionic, xenial, stretch, jessie...)
distro="$(lsb_release -s -c)"

# Add MongoDB key
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4

# Verify if is Ubuntu
if [[ "$id" == "Ubuntu" ]]; then
    # Verify is Xenial distribution
    if [[ "$distro" == "xenial" ]]; then
        # Add arm64 package
        arm=",arm64"
    fi

    # Add repository for Ubuntu
    echo "deb [ arch=amd64$arm ] https://repo.mongodb.org/apt/ubuntu $distro/mongodb-org/4.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.0.list
else
    # Add repository for Debian
    echo "deb http://repo.mongodb.org/apt/debian $distro/mongodb-org/4.0 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.0.list
fi

# Update package list
sudo apt update

# Install MongoDB
sudo apt install -y mongodb-org