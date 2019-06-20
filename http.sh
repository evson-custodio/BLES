#!/bin/bash

sudo ./utils/update.sh

sudo apt install -y nginx unzip jq

nginx_root=/etc/nginx
date_now=$(date +%F_%H-%M-%S)

nginx_conf=$nginx_root/nginx.conf
nginx_conf_old=$nginx_root/nginx.conf.$date_now

sites_available=$nginx_root/sites-available
sites_enabled=$nginx_root/sites-enabled

if [[ -f $nginx_conf ]]; then
    sudo cp $nginx_conf $nginx_conf_old
fi

sudo cp -R ./utils/nginx/* $nginx_root
source ./utils/polyfills/walk.conf

config=$(jq '.' ./config/config.json)
json=$(jq ". | $walkconfig walkconfig($config)" ./config/http.json)

serverLength=$(echo $json | jq -r '.servers | length')
for ((i=0; i<${serverLength}; ++i));
do
    server=$(echo $json | jq ".servers[$i]")
    enabled=$(echo $server | jq -r '.enabled')
    app=$(echo $server | jq -r '.type')
    server_name=$(echo $server | jq -r '.server_name')
    document_root=$(echo $server | jq -r '.document_root')

    reverse_proxy=$(echo $server | jq '.reverse_proxy')
    path=$(echo $reverse_proxy | jq -r '.path')
    address=$(echo $reverse_proxy | jq -r '.address')
    port=$(echo $reverse_proxy | jq -r '.port')

    origin=$(echo $server | jq '.origin')
    origin_git=$(echo $origin | jq -r '.git')
    origin_zip=$(echo $origin | jq -r '.zip')
    origin_paste=$(echo $origin | jq -r '.paste')

    [[ $document_root == null || $document_root == "" || $document_root == "/" ]] && document_root=""
    document_root=$(echo $document_root | sed 's/\//\\\//g')

    [[ $path == null || $path == "" ]] && path="/"
    path=$(echo $path | sed 's/\//\\\//g')

    [[ $address == null || $address == "" ]] && address=127.0.0.1
    [[ $port == null || $port == "" ]] && port=3000

    server_block=$sites_available/$server_name.conf

    if [[ -f $server_block ]]; then
        sudo cp $server_block $server_block.conf.$date_now
    fi

    sudo cp $nginx_root/templates/$app.conf $server_block

    if [[ $app == frontend ]]; then
        if [[ $reverse_proxy != null ]]; then
            reverse_proxy_template="\n\t# reverse proxy\n\tlocation <path> {\n\t\tproxy_pass http:\/\/<address>:<port>;\n\t\tinclude nginxconfig.io\/proxy.conf;\n\t}"
            sed -i "s/<reverse_proxy>/$reverse_proxy_template/g" $server_block

            [[ $path == "\/" ]] && path="\/api"
        else
            sed -i '/<reverse_proxy>/d' $server_block
        fi
    fi

    sed -i "s/example.com/$server_name/g" $server_block
    sed -i "s/<document_root>/$document_root/g" $server_block
    sed -i "s/<path>/$path/g" $server_block
    sed -i "s/<address>/$address/g" $server_block
    sed -i "s/<port>/$port/g" $server_block

    if [[ $enabled == false ]]; then
        if [[ -L $sites_enabled/$server_name.conf ]]; then
            sudo unlink $sites_enabled/$server_name.conf
        fi
    elif [[ ! -L $sites_enabled/$server_name.conf ]]; then
        sudo ln -s $server_block $sites_enabled/
    fi

    web_root=/var/www/$server_name

    if [[ ! -d $web_root ]]; then
        sudo mkdir -p $web_root
        sudo chown -R $USER:$USER $web_root
        sudo chmod -R 755 $web_root
    fi

    if [[ $origin_git != null && $origin_git != "" ]]; then
        if [[ -d $web_root/.git ]]; then
            workspace=$PWD
            cd $web_root
            git reset -q --hard HEAD
            git pull -q
            cd $workspace
        else
            if [[ "$(ls -A $web_root)" ]]; then
                sudo rm -r $web_root/*
            fi
            git clone -q $origin_git $web_root
        fi
    elif [[ $origin_zip != null && $origin_zip != "" && -f $origin_zip ]]; then
        unzip -oq $origin_zip -d $web_root
    elif [[ $origin_paste != null && $origin_paste != "" && -d $origin_paste ]]; then
        cp -R $origin_paste/* $web_root
    fi
done

[[ -L $sites_enabled/default ]] && sudo unlink $sites_enabled/default

sudo nginx -t

sudo cp ./config/http.json ./config/http.json.$date_now

sudo systemctl enable nginx
sudo systemctl restart nginx