#!/usr/bin/env bash

ensure-dir /www/nginx/logs/
ensure-dir /www/nginx/cache/

if [ ! -d /srv/src/0sjob ]; then
    git clone git.superjob.local:/base/git/superjob.git/ /srv/src/0sjob || exiterr $? "unable to checkout THE PROJECT"
    BACK_DIR=`pwd`
    cd /srv/src/0sjob

    git submodule update --init --recursive

    php bin/create-dirs.php --domain=0sjob.ru
    php bin/mkvhosts.php --name=0sjob --apache_ver=2.4 --port=81
    php bin/nginx-mkvhosts.php

    cd $BACK_DIR
fi