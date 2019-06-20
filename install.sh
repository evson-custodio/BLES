#!/bin/bash

sudo ./utils/update.sh

sudo apt install -y jq

date_now=$(date +%F_%H-%M-%S)

source ./utils/polyfills/walk.conf

config=$(jq '.' ./config/config.json)
json=$(jq ". | $walkconfig walkconfig($config)" ./config/install.json)

network=$(echo $json | jq -r '.network')
access_point=$(echo $json | jq -r '.access_point')
dhcp=$(echo $json | jq -r '.dhcp')
dns=$(echo $json | jq -r '.dns')
http=$(echo $json | jq -r '.http')
proxy=$(echo $json | jq -r '.proxy')
firewall=$(echo $json | jq -r '.firewall')
deploy=$(echo $json | jq -r '.deploy')

[[ $network == true ]] && sudo ./network.sh
[[ $access_point == true ]] && sudo ./access_point.sh
[[ $dhcp == true ]] && sudo ./dhcp.sh
[[ $dns == true ]] && sudo ./dns.sh
[[ $http == true ]] && sudo ./http.sh
[[ $proxy == true ]] && sudo ./proxy.sh
[[ $firewall == true ]] && sudo ./firewall.sh
[[ $deploy == true ]] && sudo ./deploy.sh

sudo cp ./config/install.json ./config/install.json.$date_now