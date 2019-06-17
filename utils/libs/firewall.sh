#!/bin/bash

setForward()
{
    local value=0

    [[ $1 != "" ]] && value=$1

    # Enable forward
    sudo echo $value > /proc/sys/net/ipv4/ip_forward
    sudo echo "net.ipv4.ip_forward=$value" > /etc/sysctl.conf
    sudo sysctl -p /etc/sysctl.conf
}

clean()
{
    local table=""

    for arg in "$@"
    do
        value=$(echo $arg | cut -f2 -d=)
        case $arg in
        -t=*|--table=*)
        table=" -t $value"
        ;;
        *)
        echo "INVALID ARGUMENT ($arg) IN $0"
        ;;
        esac
    done

    # Clean $1 table
    sudo iptables$table -F
    sudo iptables$table -X
}

cleanAll()
{
    # Clean filter table
    clean

    # Clean nat table
    clean -t=nat

    # Clean mangle table
    clean -t=mangle
}

reset()
{
    sudo iptables -P INPUT ACCEPT
    sudo iptables -P FORWARD ACCEPT
    sudo iptables -P OUTPUT ACCEPT
}

basicSecurity()
{
    # Add to filter table

    # Drop all INPUT packets (blocks all incoming packets, for packets destined to local sockets)
    sudo iptables -P INPUT DROP

    # Drop all FORWARD packets (blocks all routeds packets, for packets being routed through the box)
    sudo iptables -P FORWARD DROP

    # Accept all OUTPUT packets (frees all outgoing packets, for locally-generated packets)
    sudo iptables -P OUTPUT ACCEPT

    # Add exception for "lo" (loopback) in INPUT
    sudo iptables -A INPUT -i lo -j ACCEPT

    # Add exception for all interfaces in INPUT, only if the state is ESTABLISHED or RELATED
    sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # Add exception for all interfaces in FORWARD, only if the state is ESTABLISHED or RELATED
    sudo iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
}

antiDDoSAndPingOfDeath()
{
    local sec="1"

    for arg in "$@"
    do
        value=$(echo $arg | cut -f2 -d=)
        case $arg in
        -sec=*|--seconds=*)
        sec="$value"
        ;;
        *)
        echo "INVALID ARGUMENT ($arg) IN $0"
        ;;
        esac
    done

    # Add to filter table
    sudo iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit $sec/s -j ACCEPT
    sudo iptables -A INPUT -p icmp --icmp-type echo-reply -m limit --limit $sec/s -j DROP
}

allowPort()
{
    local dport=""
    local i=""
    local p=""
    local s=""

    for arg in "$@"
    do
        value=$(echo $arg | cut -f2 -d=)
        case $arg in
        -dport=*|--dport=*)
        dport=" --dport $value"
        ;;
        -i=*|--in=*)
        i=" -i $value"
        ;;
        -p=*|--protocol=*)
        p=" -p $value"
        ;;
        -s=*|--source=*)
        s=" -s $value"
        ;;
        *)
        echo "INVALID ARGUMENT ($arg) IN $0"
        ;;
        esac
    done

    [[ $dport == "" ]] && echo "PARAMETER -dport IS REQUIRED" && return

    # Add to filter table
    sudo iptables -A INPUT$i$s$p$dport -j ACCEPT
}

masquerade()
{
    local o=""
    local s=""

    for arg in "$@"
    do
        value=$(echo $arg | cut -f2 -d=)
        case $arg in
        -o=*|--out=*)
        o=" -o $value"
        ;;
        -s=*|--source=*)
        s=" -s $value"
        ;;
        *)
        echo "INVALID ARGUMENT ($arg) IN $0"
        ;;
        esac
    done

    [[ $o == "" ]] && echo "PARAMETER -o IS REQUIRED" && return

    # Add to nat table
    sudo iptables -t nat -A POSTROUTING$o$s -j MASQUERADE
}

redirectPort()
{
    local dport=""
    local toport=""
    local i=""
    local p=""
    local s=""

    for arg in "$@"
    do
        value=$(echo $arg | cut -f2 -d=)
        case $arg in
        -dport=*|--dport=*)
        dport=" --dport $value"
        ;;
        -toport=*|--to-port=*)
        toport=" --to-port $value"
        ;;
        -i=*|--in=*)
        i=" -i $value"
        ;;
        -p=*|--protocol=*)
        p=" -p $value"
        ;;
        -s=*|--source=*)
        s=" -s $value"
        ;;
        *)
        echo "INVALID ARGUMENT ($arg) IN $0"
        ;;
        esac
    done

    [[ $dport == "" || $toport == "" ]] && echo "PARAMETERS -dport and -toport ARE REQUIREDS" && return

    # Add to nat table
    sudo iptables -t nat -A PREROUTING$i$s$p$dport -j REDIRECT$toport
}

redirectDNAT()
{
    local dport=""
    local i=""
    local p=""
    local s=""
    local d=""
    local to=""

    for arg in "$@"
    do
        value=$(echo $arg | cut -f2 -d=)
        case $arg in
        -dport=*|--dport=*)
        dport=" --dport $value"
        ;;
        -i=*|--in=*)
        i=" -i $value"
        ;;
        -p=*|--protocol=*)
        p=" -p $value"
        ;;
        -s=*|--source=*)
        s=" -s $value"
        ;;
        -d=*|--destination=*)
        d=" -d $value"
        ;;
        -to=*|--to=*)
        to=" --to $value"
        ;;
        *)
        echo "INVALID ARGUMENT ($arg) IN $0"
        ;;
        esac
    done

    [[ $to == "" || ($i == "" && $s == "") ]] && echo "PARAMETERS -dport and -to ARE REQUIREDS" && return

    sudo iptables -A FORWARD$i$s$p$dport$d -j ACCEPT
    sudo iptables -t nat -A PREROUTING$i$s$p$dport -j DNAT$to
}