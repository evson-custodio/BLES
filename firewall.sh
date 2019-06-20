#!/bin/bash

sudo touch ./updated

if [[ $(cat ./updated) != $(date +%F) ]]; then
    sudo ./utils/update.sh

    sudo apt install -y jq

    sudo printf "$(date +%F)" > ./updated
fi

date_now=$(date +%F_%H-%M-%S)

# Enable /etc/rc.local
sudo ./utils/enable_rc.local.sh

rc_local=/etc/rc.local
header="#!\/bin\/bash"
restore="iptables-restore < \/etc\/iptables.ipv4.nat"
get_restore=$(grep -i "$restore" $rc_local)

source ./utils/polyfills/walk.conf
source ./utils/libs/firewall.sh

config=$(jq '.' ./config/config.json)
json=$(jq ". | $walkconfig walkconfig($config)" ./config/firewall.json)

enabled=$(echo $json | jq -r '.enabled')
basic_security=$(echo $json | jq -r '.basic_security')
ping_limit_seconds=$(echo $json | jq -r '.ping_limit_seconds')

if [[ $enabled == true ]]; then
    setForward 1
    cleanAll
    reset

    [[ $basic_security == true ]] && basicSecurity
    [[ $ping_limit_seconds != null ]] && antiDDoSAndPingOfDeath -sec=$ping_limit_seconds

    length=$(echo $json | jq -r '.allow_ports | length')
    for ((i=0; i<${length}; ++i));
    do
        allow=$(echo $json | jq ".allow_ports[$i]")
        port=$(echo $allow | jq -r '.port')
        input_interface=$(echo $allow | jq -r '.input_interface')
        address=$(echo $allow | jq -r '.address')
        netmask=$(echo $allow | jq -r '.netmask')
        protocol=$(echo $allow | jq -r '.protocol')

        [[ $port != null ]] && port="-dport=$port" || port=""
        [[ $input_interface != null ]] && input_interface="-i=$input_interface" || input_interface=""
        [[ $protocol != null ]] && protocol="-p=$protocol" || protocol=""
        if [[ $address != null ]]; then
            address="-s=$address"
            if [[ $netmask != null ]]; then
                address="$address/$netmask"
            fi
        else
            address=""
        fi

        allowPort $port $input_interface $address $protocol
    done

    length=$(echo $json | jq -r '.masquerade | length')
    for ((i=0; i<${length}; ++i));
    do
        masq=$(echo $json | jq ".masquerade[$i]")
        output_interface=$(echo $masq | jq -r '.output_interface')
        address=$(echo $masq | jq -r '.address')
        netmask=$(echo $masq | jq -r '.netmask')

        [[ $output_interface != null ]] && output_interface="-o=$output_interface" || input_interface=""
        if [[ $address != null ]]; then
            address="-s=$address"
            if [[ $netmask != null ]]; then
                address="$address/$netmask"
            fi
        else
            address=""
        fi

        masquerade $output_interface $address
    done

    length=$(echo $json | jq -r '.redirect_ports | length')
    for ((i=0; i<${length}; ++i));
    do
        redirect_ports=$(echo $json | jq ".redirect_ports[$i]")
        port=$(echo $redirect_ports | jq -r '.port')
        to_port=$(echo $redirect_ports | jq -r '.to_port')
        input_interface=$(echo $redirect_ports | jq -r '.input_interface')
        address=$(echo $redirect_ports | jq -r '.address')
        netmask=$(echo $redirect_ports | jq -r '.netmask')
        protocol=$(echo $redirect_ports | jq -r '.protocol')

        [[ $port != null ]] && port="-dport=$port" || port=""
        [[ $to_port != null ]] && to_port="-toport=$to_port" || to_port=""
        [[ $input_interface != null ]] && input_interface="-i=$input_interface" || input_interface=""
        [[ $protocol != null ]] && protocol="-p=$protocol" || protocol=""
        if [[ $address != null ]]; then
            address="-s=$address"
            if [[ $netmask != null ]]; then
                address="$address/$netmask"
            fi
        else
            address=""
        fi

        redirectPort $port $to_port $input_interface $address $protocol
    done

    length=$(echo $json | jq -r '.redirect_destination | length')
    for ((i=0; i<${length}; ++i));
    do
        redirect_destination=$(echo $json | jq ".redirect_destination[$i]")
        input_interface=$(echo $redirect_destination | jq -r '.input_interface')
        protocol=$(echo $redirect_destination | jq -r '.protocol')

        s_address=$(echo $redirect_destination | jq -r '.source.address')
        s_netmask=$(echo $redirect_destination | jq -r '.source.netmask')

        d_address=$(echo $redirect_destination | jq -r '.destination.address')
        d_netmask=$(echo $redirect_destination | jq -r '.destination.netmask')
        d_port=$(echo $redirect_destination | jq -r '.destination.port')

        to_address=$(echo $redirect_destination | jq -r '.to_destination.address')
        to_port=$(echo $redirect_destination | jq -r '.to_destination.port')

        [[ $input_interface != null ]] && input_interface="-i=$input_interface" || input_interface=""
        [[ $protocol != null ]] && protocol="-p=$protocol" || protocol=""

        if [[ $s_address != null ]]; then
            s_address="-s=$s_address"
            if [[ $s_netmask != null ]]; then
                s_address="$s_address/$s_netmask"
            fi
        else
            s_address=""
        fi

        [[ $d_port != null ]] && d_port="-dport=$d_port" || d_port=""
        if [[ $d_address != null ]]; then
            d_address="-d=$d_address"
            if [[ $d_netmask != null ]]; then
                d_address="$d_address/$d_netmask"
            fi
        else
            d_address=""
        fi

        [[ $to_address != null ]] && to_address="-to=$to_address" || to_address=""
        [[ $to_port != null ]] && to_address="$to_address:$to_port"

        redirectDNAT $input_interface $s_address $protocol $d_port $d_address $to_address
    done

    # Save rule
    sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"

    if [[ $get_restore == "" ]]; then
        # Add restore iptables rule in initialization
        sudo sed -i "s/$header/$header\n\n$restore/g" $rc_local
    fi
else
    setForward 0
    cleanAll
    reset

    if [[ $get_restore != "" ]]; then
        # Remove restore iptables rule in initialization
        sudo sed -i "/$restore/d" $rc_local
    fi
fi

sudo cp ./config/firewall.json ./config/firewall.json.$date_now