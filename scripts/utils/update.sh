#!/bin/bash

# Update package list
sudo apt update

# Install updates
sudo apt upgrade -y

# Remove packages useless
sudo apt autoremove -y