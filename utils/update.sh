#!/bin/bash

sudo touch ./updated

if [[ $(cat ./updated) != $(date +%F) ]]; then

    # Update package list
    sudo apt update

    # Install updates
    sudo apt upgrade -y

    # Remove packages useless
    sudo apt autoremove -y

    sudo printf "$(date +%F)" > ./updated
fi