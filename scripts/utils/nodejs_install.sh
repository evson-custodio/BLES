#!/bin/bash

# Update System
sudo ./update.sh

# Install lsb-release package if not present
sudo apt install -y lsb-release

# System Distribution (bionic, xenial, stretch, jessie...)
distro="$(lsb_release -s -c)"

# Nodejs Version
version=node_10.x

# Add NodeSource key
curl -sSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | sudo apt-key add -

# Add repository
echo "deb https://deb.nodesource.com/$version $distro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
echo "deb-src https://deb.nodesource.com/$version $distro main" | sudo tee -a /etc/apt/sources.list.d/nodesource.list

# Update package list
sudo apt update

# Install Nodejs and Build Tools (gcc, g++, make...)
sudo apt install -y nodejs build-essential