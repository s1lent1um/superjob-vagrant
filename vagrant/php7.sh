#!/usr/bin/env bash
PROJECT_DIR="/vagrant"

CURRENT_DIR=$(pwd)


config-php7-fpm() {
  copy ${PROJECT_DIR}/vagrant/php.ini /etc/php/7.0/fpm/php.ini
  copy ${PROJECT_DIR}/vagrant/fpm.conf /etc/php/7.0/fpm/pool.d/www.conf
}

config-php7-cli() {
  copy ${PROJECT_DIR}/vagrant/php.ini /etc/php/7.0/cli/php.ini
}

install-php7-module() {
    module=$1
    module=php7-$module
    back_dir=`pwd`
    installed $module

    if [ "$?" -gt 0 ]; then
        ensure-dir tmpbuild
        rm -rf tmpbuild/*
        cd tmpbuild

        `install-php7-module-$module` || exiterr $? "unable to install $module"

        echo "extension=$module.so" > /etc/php/7.0/mods-available/${module}.ini
        phpenmod $module
        cd $back_dir
        rm -rf tmpbuild/
        installed $module ok
    fi
}

install-php7-module-blitz() {
    module=blitz

    wget https://github.com/alexeyrybak/blitz/archive/0.9.1.tar.gz -O blitz.tar.gz || exiterr $? "unable to download $module"
    tar -zxf blitz.tar.gz || exiterr $? "unable to unpack $module"
    cd blitz-*/
    ./configure && make || exiterr $? "unable to build $module"
    make install || exiterr $? "unable to install $module"
}

