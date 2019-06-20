#!/bin/bash

sudo ./utils/update.sh

sudo ./utils/nodejs_install.sh

sudo apt install -y openjdk-8-jdk php7.0-cli

date_now=$(date +%F_%H-%M-%S)

source ./utils/polyfills/walk.conf
config=$(jq '.' ./config/config.json)
json=$(jq ". | $walkconfig walkconfig($config)" ./config/deploy.json)

length=$(echo $json | jq -r '.applications | length')
for ((i=0; i<${length}; ++i));
do
    app=$(echo $json | jq ".applications[$i]")
    name=$(echo $app | jq -r '.name')
    description=$(echo $app | jq -r '.description')
    command=$(echo $app | jq -r '.command')
    deploy_directory=$(echo $app | jq -r '.deploy_directory')

    origin=$(echo $app | jq '.origin')
    origin_git=$(echo $origin | jq -r '.git')
    origin_zip=$(echo $origin | jq -r '.zip')
    origin_paste=$(echo $origin | jq -r '.paste')

    env_variables=$(echo $app | jq '.env_variables')
    after_services=$(echo $app | jq -r '.after_services | @sh' | sed "s/'//g")

    if [[ ! -d $deploy_directory ]]; then
        sudo mkdir -p $deploy_directory
        sudo chmod -R 755 $deploy_directory
    fi

    if [[ $origin_git != null && $origin_git != "" ]]; then
        if [[ -d $deploy_directory/.git ]]; then
            workspace=$PWD
            cd $deploy_directory
            git reset -q --hard HEAD
            git pull -q
            cd $workspace
        else
            if [[ "$(ls -A $deploy_directory)" ]]; then
                sudo rm -r $deploy_directory/*
            fi
            git clone -q $origin_git $deploy_directory
        fi
    elif [[ $origin_zip != null && $origin_zip != "" && -f $origin_zip ]]; then
        unzip -oq $origin_zip -d $deploy_directory
    elif [[ $origin_paste != null && $origin_paste != "" && -d $origin_paste ]]; then
        cp -R $origin_paste/* $deploy_directory
    fi

    app_service=/etc/systemd/system/$name.service

    sudo cp ./utils/systemd/example.service $app_service
    sudo chmod 755 $app_service

    sed -i "s/<description>/$description/g" $app_service
    sed -i "s/<name>/$name/g" $app_service
    #sed -i "s/<user>/$USER/g" $app_service
    deploy_directory=$(echo $deploy_directory | sed 's/\//\\\//g')
    sed -i "s/<directory>/$deploy_directory/g" $app_service

    [[ $after_services != null && $after_services != "" ]] && after_services=" $after_services" || after_services=""
    sed -i "s/<services>/$after_services/g" $app_service

    full_command=""
    for i in $(echo $env_variables | jq -r '. | keys_unsorted | @sh' | sed "s/'//g");
    do
        full_command="$full_command $i=$(echo $env_variables | jq -r ".$i" | sed 's/\//\\\//g')"
    done

    sed -i "s/<command>/$full_command $command/g" $app_service

    sudo systemctl enable $name.service
    # sudo systemctl start $name.service
done