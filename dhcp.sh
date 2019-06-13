#!/bin/bash

sudo ./utils/update.sh

sudo apt install -y isc-dhcp-server

date_now=$(date +%F_%H-%M-%S)

fdhcp=/etc/dhcp/dhcpd.conf
fdefault=/etc/default/isc-dhcp-server

fdhcp_old=/etc/dhcp/dhcpd.conf.$date_now
fdefault_old=/etc/default/isc-dhcp-server.$date_now

if [[ -f $fdhcpd ]]; then
    sudo cp $fdhcpd $fdhcpd_old
fi

if [[ -f $fdefault ]]; then
    sudo cp $fdefault $fdefault_old
fi

source ./utils/polyfills/walk.conf
config=$(jq '.' ./config/config.json)
json=$(jq ". | $walkconfig walkconfig($config)" ./config/dhcp.json)

writePaths() {
    start_range=$(echo $obj | jq -r '.start_range')
    end_range=$(echo $obj | jq -r '.end_range')

    [[ $start_range != null && $end_range != null ]] && sudo printf "$tn range $start_range $end_range;\n" >> $fdhcpd

    for i in $(echo $obj | jq -r '. | keys_unsorted | map(select(. != "interface" and . != "subnets" and . != "pools" and . != "hosts" and . != "network" and . != "start_range" and . != "end_range")) | @sh' | sed "s/'//g");
    do
        value=$(echo $obj | jq -r ".$i | @sh"  | sed "s/'//g")
        case $i in
        netmask)
        [[ $value != null ]] && sudo printf "$tn option subnet-mask $value;\n" >> $fdhcpd
        ;;
        broadcast)
        [[ $value != null ]] && sudo printf "$tn option broadcast-address $value;\n" >> $fdhcpd
        ;;
        gateway)
        [[ $value != null ]] && sudo printf "$tn option routers $value;\n" >> $fdhcpd
        ;;
        domain_name)
        [[ $value != null ]] && sudo printf "$tn option domain-name \"$value\";\n" >> $fdhcpd
        ;;
        domain_name_servers)
        [[ $value != null ]] && sudo printf "$tn option domain-name-servers $(echo $value | sed 's/ /, /g');\n" >> $fdhcpd
        ;;
        deny_other_hosts)
        [[ $value == true ]] && sudo printf "$tn deny unknown-clients;\n" >> $fdhcpd
        ;;
        lease_time)
        [[ $value != null ]] && sudo printf "$tn default-lease-time $value;\n$tn max-lease-time $value;\n" >> $fdhcpd
        ;;
        *)
        sudo printf "$tn $i $value;\n" >> $fdhcpd
        ;;
        esac
    done
}

writeHosts() {
    length=$(echo $obj | jq -r '.hosts | length')
    for ((j=0; j<${length}; ++j));
    do
        host=$(echo $obj | jq ".hosts[$j]")
        hostname=$(echo $host | jq -r '.hostname')
        assign_hostname=$(echo $host | jq -r '.assign_hostname')
        mac=$(echo $host | jq -r '.mac')
        address=$(echo $host | jq -r '.address')
        lease_time=$(echo $host | jq -r '.lease_time')

        [[ $hostname == null ]] && hostname=""
        sudo printf "\n$tn host $hostname {\n" >> $fdhcpd

        [[ $assign_hostname == true ]] && sudo printf "$tn   option host-name \"$hostname\";\n" >> $fdhcpd
        [[ $mac != null ]] && sudo printf "$tn   hardware ethernet $mac;\n" >> $fdhcpd
        [[ $address != null ]] && sudo printf "$tn   fixed-address $address;\n" >> $fdhcpd
        [[ $lease_time != null ]] && sudo printf "$tn   max-lease-time $lease_time;\n" >> $fdhcpd

        sudo printf "$tn }\n" >> $fdhcpd
    done
}

writePools() {
    length=$(echo $obj | jq -r '.pools | length')
    for ((k=0; k<${length}; ++k));
    do
        pool=$(echo $obj | jq ".pools[$k]")

        sudo printf "\n$tn pool {\n" >> $fdhcpd

        poolObj=$obj
        poolTn=$tn

        obj=$pool
        tn="$tn  "
        writePaths
        writeHosts

        obj=$poolObj
        tn=$poolTn

        sudo printf "$tn }\n" >> $fdhcpd
    done
}

writeSubnets() {
    length=$(echo $obj | jq -r '.subnets | length')
    for ((l=0; l<${length}; ++l));
    do
        subnet=$(echo $obj | jq ".subnets[$l]")
        network=$(echo $subnet | jq -r '.network')
        netmask=$(echo $subnet | jq -r '.netmask')

        sudo printf "\n$tn subnet $network netmask $netmask {\n" >> $fdhcpd

        subnetObj=$obj
        subnetTn=$tn

        obj=$subnet
        tn="$tn  "
        writePaths
        writeHosts
        writePools

        obj=$subnetObj
        tn=$subnetTn

        sudo printf "$tn }\n" >> $fdhcpd
    done
}

sudo printf "DHCPD_CONF=/etc/dhcp/dhcpd.conf\nDHCPD_PID=/var/run/dhcpd.pid\nINTERFACESv4=$(echo $json | jq '.interface')" > $fdefault

sudo printf "
ddns-update-style none;
deny declines;
deny bootp;
authoritative;

shared-network bles {
" > $fdhcpd

obj=$(echo $json | jq '.')
tn=" "
writePaths
writeHosts
writeSubnets

sudo printf "}\n" >> $fdhcpd

dhcpd -t

sudo service isc-dhcp-server restart