#!/bin/bash

sudo ./utils/update.sh

sudo apt install -y lsb-release

date_now=$(date +%F_%H-%M-%S)

source ./utils/walk.conf
source ./utils/bar.sh

config=$(jq '.' ./config/config.json)
json=$(jq ". | $walkconfig walkconfig($config)" ./config/network.json)
hostname_old=$(cat /etc/hostname)
hostname_new=$(echo $json | jq -r '.hostname')
t3="   "
t7="$t3 $t3"
t11="$t3 $t7"

sudo cp /etc/hostname /etc/hostname.$date_now
sudo cp /etc/hosts /etc/hosts.$date_now

sudo hostname $hostname_new
sudo sed -i "s/$hostname_old/$hostname_new/g" /etc/hostname
sudo sed -i "s/$hostname_old/$hostname_new/g" /etc/hosts

# System Distribution (bionic, xenial, stretch, jessie...)
distro=$(lsb_release -s -c)

if [[ $distro == bionic ]]; then
    fnetplan=/etc/netplan/50-cloud-init.yaml
    fnetplan_old=/etc/netplan/50-cloud-init.yaml.$date_now

    if [[ -f $fnetplan ]]; then
        sudo cp $fnetplan $fnetplan_old
    fi

    sudo printf "network:\n$t3 version: 2\n$t3 ethernets:\n" > $fnetplan

    length=$(echo $json | jq '.interfaces | length')

    for ((i=0; i<${length}; ++i));
    do
        interface=$(echo $json | jq ".interfaces[$i]")
        name=$(echo $interface | jq -r '.name')
        inet=$(echo $interface | jq -r '.inet')
        address=$(echo $interface | jq -r '.address')
        netmask=$(echo $interface | jq -r '.netmask')
        gateway=$(echo $interface | jq -r '.gateway')
        domain_name=$(echo $interface | jq -r '.domain_name')
        domain_name_servers=$(echo $interface | jq -r '.domain_name_servers | @sh' | sed "s/'//g" | sed 's/ /, /g')
        macaddress=$(ip addr | grep -EA1 "^[0-9]+: $name" | sed -nr '/^\s*link\//s~.* ([0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}) .*~\1~p')

        if [[ $name != lo ]]; then
            sudo printf "$t7 $name:\n" >> $fnetplan

            [[ $address != null && $netmask != null ]] && netmaskBar && sudo printf "$t11 addresses: [$address/$bar]\n" >> $fnetplan

            [[ $gateway != null ]] && sudo printf "$t11 gateway4: $gateway\n" >> $fnetplan

            [[ $inet == dhcp ]] && inet=true || inet=false
            sudo printf "$t11 dhcp4: $inet\n" >> $fnetplan

            if [[ $domain_name != null || $domain_name_servers != null ]]; then
                sudo printf "$t11 nameservers:\n" >> $fnetplan

                [[ $domain_name != null ]] && sudo printf "$t11 $t3 search: [$domain_name]\n" >> $fnetplan
                [[ $domain_name_servers != null ]] && sudo printf "$t11 $t3 addresses: [$domain_name_servers]\n" >> $fnetplan
            fi

            [[ $macaddress != "" ]] && sudo printf "$t11 match:\n$t11 $t3 macaddress: $macaddress\n" >> $fnetplan

            sudo printf "$t11 set-name: $name\n" >> $fnetplan
        fi
    done

    sudo netplan apply
else
    finterfaces=/etc/network/interfaces
    finterfaces_old=/etc/network/interfaces.$date_now

    if [[ -f $finterfaces ]]; then
        sudo mv $finterfaces $finterfaces_old
    fi

    length=$(echo $json | jq '.interfaces | length')

    for ((i=0; i<${length}; ++i));
    do
        interface=$(echo $json | jq ".interfaces[$i]")
        name=$(echo $interface | jq -r '.name')
        inet=$(echo $interface | jq -r '.inet')

        sudo printf "\nauto $name\niface $name inet $inet\n" >> $finterfaces

        for j in $(echo $interface | jq -r '. | keys_unsorted | map(select(. != "name" and . != "inet")) | @sh' | sed "s/'//g");
        do
            value=$(echo $interface | jq -r ".$j | @sh"  | sed "s/'//g")

            case $j in
            gateway)
            [[ $value != null ]] && sudo printf "$t3 $j $value\n" >> $finterfaces
            ;;
            domain_name)
            sudo printf "$t3 dns-domain $value\n$t3 dns-search $value\n" >> $finterfaces
            ;;
            domain_name_servers)
            sudo printf "$t3 dns-nameservers $value\n" >> $finterfaces
            ;;
            *)
            sudo printf "$t3 $j $value\n" >> $finterfaces
            ;;
            esac
        done
    done

    sudo service networking reload
fi