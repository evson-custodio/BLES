#!/bin/bash

date_now=$(date +%F_%H-%M-%S)

source ./utils/polyfills/walk.conf
source ./utils/libs/firewall.sh

config=$(jq '.' ./config/config.json)
json=$(jq ". | $walkconfig walkconfig($config)" ./config/firewall.json)

# Continue...

# Save rule
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"

# Enable /etc/rc.local
sudo ./utils/enable_rc.local.sh

# Add restore iptables rule in initialization
sudo sed -i 's/exit 0/iptables-restore < \/etc\/iptables.ipv4.nat\n\nexit 0/g' /etc/rc.local

sudo cp ./config/firewall.json ./config/firewall.json.$date_now