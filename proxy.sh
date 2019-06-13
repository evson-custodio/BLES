#!/bin/bash

sudo ./utils/update.sh

sudo apt install -y squid3 apache2-utils

base=/etc/squid
date_now=$(date +%F_%H-%M-%S)

squid_conf=$base/squid.conf
squid_conf_old=$base/squid.conf.$date_now

auth_users=$base/auth_users
auth_users_old=$base/auth_users.$date_now

fblocked_sites=$base/blocked_sites
fblocked_sites_old=$base/blocked_sites.$date_now

fblocked_words=$base/blocked_words
fblocked_words_old=$base/blocked_words.$date_now

if [[ -f $squid_conf ]]; then
    sudo cp $squid_conf $squid_conf_old
fi

sudo cp ./utils/squid/squid.conf $squid_conf

source ./utils/polyfills/walk.conf
source ./utils/bar.sh

config=$(jq '.' ./config/config.json)
json=$(jq ". | $walkconfig walkconfig($config)" ./config/proxy.json)

hostname=$(echo $json | jq -r '.hostname')
blocked_sites=$(echo $json | jq -r '.blocked_sites | @sh' | sed "s/'//g")
blocked_words=$(echo $json | jq -r '.blocked_words | @sh' | sed "s/'//g")

auth=$(echo $json | jq '.auth')
auth_enabled=$(echo $auth | jq -r '.enabled')
auth_message=$(echo $auth | jq -r '.message')
auth_credential_ttl=$(echo $auth | jq -r '.credential_ttl')

sed -i "s/<hostname>/$hostname/g" $squid_conf

if [[ $blocked_sites != null && $blocked_sites != "" ]]; then
    if [[ -f $fblocked_sites ]]; then
        sudo mv $fblocked_sites $fblocked_sites_old
    fi

    for j in $blocked_sites;
    do
        sudo printf "$j\n" >> $fblocked_sites
    done
fi

if [[ $blocked_words != null && $blocked_words != "" ]]; then
    if [[ -f $fblocked_words ]]; then
        sudo mv $fblocked_words $fblocked_words_old
    fi

    for j in $blocked_words;
    do
        sudo printf "$j\n" >> $fblocked_words
    done
fi

if [[ $auth_enabled == true ]]; then
    sed -i "s/<intercept>//g" $squid_conf

    auth_output="auth_param basic program \/usr\/lib\/squid3\/basic_ncsa_auth \/etc\/squid\/auth_users\nauth_param basic children 5 startup=5 idle=1"

    [[ $auth_message != null && $auth_message != "" ]] && auth_output="$auth_output\nauth_param basic realm $auth_message"
    [[ $auth_credential_ttl != null && $auth_credential_ttl != "" ]] && auth_output="$auth_output\nauth_param basic credentialsttl $auth_credential_ttl hours"

    sed -i "s/<auth>/$auth_output/g" $squid_conf
    sed -i "s/<auth_users>/acl auth_users proxy_auth REQUIRED/g" $squid_conf

    usersLength=$(echo $auth | jq -r '.users | length')

    if [[ $usersLength > 0 ]]; then
        if [[ -f $auth_users ]]; then
            sudo cp $auth_users $auth_users_old
        else
            sudo touch $auth_users
        fi

        for ((j=0; j<${usersLength}; ++j));
        do
            sudo htpasswd -b $auth_users $(echo $auth | jq ".users[$j].username") $(echo $auth | jq ".users[$j].password")
        done
    fi
else
    sed -i "s/<intercept>/ intercept/g" $squid_conf
    sed -i "s/<auth>//g" $squid_conf
    sed -i "s/<auth_users>//g" $squid_conf
fi

subnets_acl=""
subnets_rules=""
subnetsLength=$(echo $json | jq -r '.subnets | length')
for ((j=0; j<${subnetsLength}; ++j));
do
    subnet=$(echo $json | jq ".subnets[$j]")
    deny=$(echo $subnet | jq -r '.deny')
    network=$(echo $subnet | jq -r '.network')
    netmask=$(echo $subnet | jq -r '.netmask')
    name="subnet$j"
    netmaskBar

    [[ $deny == true ]] && deny="deny" || deny="allow"

    subnets_acl="$subnets_acl\nacl $name src $network\/$bar"
    subnets_rules="$subnets_rules\nhttp_access $deny $name"
done

sed -i "s/<subnets_acl>/$subnets_acl/g" $squid_conf
sed -i "s/<subnets_rules>/$subnets_rules/g" $squid_conf

sudo squid3 -z
sudo squid3 -k reconfigure