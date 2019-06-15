#!/bin/bash

sudo ./utils/update.sh

sudo apt install -y iw hostapd

date_now=$(date +%F_%H-%M-%S)

hostapd_conf=/etc/hostapd/hostapd.conf
hostapd_default=/etc/default/hostapd

hostapd_conf_old=/etc/hostapd/hostapd.conf.$date_now
hostapd_default_old=/etc/default/hostapd.$date_now

if [[ -f $hostapd_conf ]]; then
    sudo cp $hostapd_conf $hostapd_conf_old
fi

if [[ -f $hostapd_default ]]; then
    sudo cp $hostapd_default $hostapd_default_old
fi

source ./utils/polyfills/walk.conf
config=$(jq '.' ./config/config.json)
json=$(jq ". | $walkconfig walkconfig($config)" ./config/access_point.json)

country_code=$(echo $json | jq -r '.country_code')
mode_ac=$(echo $json | jq -r '.mode_ac')
points=$(echo $json | jq -r '.points')

sudo iw reg set $country_code

sudo printf "DAEMON_CONF=\"$hostapd_conf\"\n" > $hostapd_default

sudo printf "
country_code=$country_code

interface=$(echo $points | jq -r ".[0].interface")
driver=nl80211

macaddr_acl=0

logger_syslog=0
logger_syslog_level=4
logger_stdout=-1
logger_stdout_level=0
" > $hostapd_conf

if [[ $mode_ac == true ]]; then

sudo printf "
hw_mode=a
wmm_enabled=1

ieee80211n=1
require_ht=1
ht_capab=[MAX-AMSDU-3839][HT40+][SHORT-GI-20][SHORT-GI-40][DSSS_CCK-40]

ieee80211ac=1
require_vht=1
ieee80211d=0
ieee80211h=0
vht_capab=[MAX-AMSDU-3839][SHORT-GI-80]
vht_oper_chwidth=1
channel=36
vht_oper_centr_freq_seg0_idx=42
" >> $hostapd_conf

else

sudo printf "
hw_mode=g
wmm_enabled=1

ieee80211n=1

channel=6
ignore_broadcast_ssid=0
" >> $hostapd_conf

fi

pointsLength=$(echo $points | jq '. | length')
for ((i=0; i<${pointsLength}; ++i));
do
    interface=$(echo $points | jq -r ".[$i].interface")
    ssid=$(echo $points | jq -r ".[$i].ssid")
    password=$(echo $points | jq -r ".[$i].password")

    [[ i != 0 ]] && sudo printf "\nbss=$interface\n" >> $hostapd_conf
    sudo printf "ssid=$ssid\n" >> $hostapd_conf
    [[ $password != null ]] && sudo printf "auth_algs=1\nwpa=2\nwpa_key_mgmt=WPA-PSK\nwpa_passphrase=$password\nwpa_pairwise=TKIP\nrsn_pairwise=CCMP\n" >> $hostapd_conf
done

sudo cp ./config/access_point.json ./config/access_point.json.$date_now

sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl restart hostapd