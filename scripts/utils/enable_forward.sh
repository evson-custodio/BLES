#!/bin/bash

# Enable forward
sudo echo 1 > /proc/sys/net/ipv4/ip_forward
sudo echo "net.ipv4.ip_forward=1" > /etc/sysctl.conf
sudo sysctl -p /etc/sysctl.conf

# Create iptables rule masquerade
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Save rule
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"

# Enable /etc/rc.local
sudo ./enable_rc.local.sh

# Add restore iptables rule in initialization
sudo sed -i 's/exit 0/iptables-restore < \/etc\/iptables.ipv4.nat\n\nexit 0/g' /etc/rc.local