#!/bin/bash

sudo ./utils/update.sh

sudo apt install -y bind9 bind9utils bind9-doc dnsutils

base=/etc/bind
date_now=$(date +%F_%H-%M-%S)

named_options=$base/named.conf.options
named_local=$base/named.conf.local

named_options_old=$base/named.conf.options.$date_now
named_local_old=$base/named.conf.local.$date_now

if [[ -f $named_options ]]; then
    sudo cp $named_options $named_options_old
fi

if [[ -f $named_local ]]; then
    sudo mv $named_local $named_local_old
fi

source ./utils/polyfills/walk.conf
source ./utils/bar.sh

config=$(jq '.' ./config/config.json)
json=$(jq ". | $walkconfig walkconfig($config)" ./config/dns.json)

serial=$(date +%y%m%d%H%M)
domain_name_servers=$(echo $json | jq -r '.domain_name_servers | length')

sudo printf "
options {
  directory \"/var/cache/bind\";
" > $named_options

[[ $domain_name_servers > 0 ]] && sudo printf "\n  forwarders {\n" >> $named_options

for ((i=0; i<${domain_name_servers}; ++i));
do
    sudo printf "    $(echo $json | jq -r ".domain_name_servers[$i]");\n" >> $named_options
done

[[ $domain_name_servers > 0 ]] && sudo printf "  };\n" >> $named_options

sudo printf "
  recursion yes;

  dnssec-validation auto;

  auth-nxdomain no;
  listen-on-v6 { any; };
};\n" >> $named_options

length=$(echo $json | jq -r '.zones | length')
for ((j=0; j<${length}; ++j));
do
    zone=$(echo $json | jq ".zones[$j]")
    network=$(echo $zone | jq -r '.network')
    netmask=$(echo $zone | jq -r '.netmask')
    domain_name=$(echo $zone | jq -r '.domain_name')

    netmaskBar
    f1=$(echo $network | cut -f1 -d.)
    f2=$(echo $network | cut -f2 -d.)
    f3=$(echo $network | cut -f3 -d.)

    db=$base/db.$domain_name
    rev=$base/rev.$domain_name

    if [[ -f $db ]]; then
        sudo cp $db $db.$date_now
    fi

    if [[ -f $rev ]]; then
        sudo cp $rev $rev.$date_now
    fi

    rev_zone=$f1.in-addr.arpa
    [[ $bar > 15 ]] && rev_zone=$f2.$rev_zone
    [[ $bar > 23 ]] && rev_zone=$f3.$rev_zone

    sudo printf "\nzone \"$domain_name\" {\n\ttype master;\n\tfile \"$db\";\n};\n\nzone \"$rev_zone\" {\n\ttype master;\n\tfile \"$rev\";\n};\n" >> $named_local

    first_hostname=$(echo $zone | jq -r ".hosts[0].hostname")
    sudo printf "\$TTL\t604800\n@\tIN\tSOA\t$first_hostname.$domain_name. root.$domain_name. (\n\t\t\t$serial   ; Serial\n\t\t\t8H   ; Refresh\n\t\t\t4H   ; Retry\n\t\t\t4W   ; Expire\n\t\t\t1D ) ; Minimum\n;\n@\tIN\tNS\t$first_hostname.$domain_name.\n" > $db
    cat $db > $rev

    hostsLength=$(echo $zone | jq -r '.hosts | length')
    for ((k=0; k<${hostsLength}; ++k));
    do
        host=$(echo $zone | jq ".hosts[$k]")
        hostname=$(echo $host | jq -r '.hostname')
        address=$(echo $host | jq -r '.address')

        f2=$(echo $address | cut -f2 -d.)
        f3=$(echo $address | cut -f3 -d.)
        f4=$(echo $address | cut -f4 -d.)

        rev_address=$f4
        [[ $bar < 24 ]] && rev_address=$f3.$rev_address
        [[ $bar < 16 ]] && rev_address=$f2.$rev_address

        sudo printf "$rev_address\tIN\tPTR\t$hostname.\n" >> $rev
        sudo printf "$hostname\tIN\tA\t$address\n" >> $db

        aliasesLength=$(echo $host | jq -r '.aliases | length')
        for ((l=0; l<${aliasesLength}; ++l));
        do
            sudo printf "$(echo $host | jq -r ".aliases[$l]")\tIN\tCNAME\t$hostname\n" >> $db
        done
    done

    sudo named-checkzone $domain_name $db
    sudo named-checkzone $rev_zone $rev
done

sudo named-checkconf $named_options
sudo named-checkconf $named_local

sudo service bind9 restart