#!/usr/bin/env bash
PROJECT_DIR="/vagrant"

CURRENT_DIR=$(pwd)

checkout-project() {
    installed checkout-project
    if [ "$?" -gt 0 ]; then

        installed checkout-project ok
    fi
}
config-php7-fpm() {
  copy ${PROJECT_DIR}/vagrant/php.ini /etc/php/7.0/fpm/php.ini
  copy ${PROJECT_DIR}/vagrant/fpm.conf /etc/php/7.0/fpm/pool.d/www.conf
}

config-php7-cli() {
  copy ${PROJECT_DIR}/vagrant/php.ini /etc/php/7.0/cli/php.ini
}

config-php7-apache() {
  copy ${PROJECT_DIR}/vagrant/php.ini /etc/php/7.0/apache2/php.ini
}

install-php7-module() {
    module=$1
    package=php7-$module
    back_dir=`pwd`
    installed $package

    if [ "$?" -gt 0 ]; then
        ensure-dir /tmp/build
        rm -rf /tmp/build/*
        cd /tmp/build

        install-php7-module-$module || exiterr $? "unable to install $package"

        echo "extension=$module.so" > /etc/php/7.0/mods-available/${module}.ini
        phpenmod $module
        cd $back_dir
        rm -rf /tmp/build/
        installed $package ok
    fi
}

install-php7-module-blitz() {
    module=blitz

    git clone https://github.com/alexeyrybak/blitz.git blitz || exiterr $? "unable to download $module"
    cd $module
    git checkout origin/php7
    phpize && ./configure && make || exiterr $? "unable to build $module"
    make install || exiterr $? "unable to install $module"
}

install-php7-module-igbinary() {
    module=igbinary

    git clone https://github.com/igbinary/igbinary7.git $module || exiterr $? "unable to download $module"
    cd $module
    phpize && ./configure && make || exiterr $? "unable to build $module"
    make install || exiterr $? "unable to install $module"
}

install-php7-module-mysqllexer() {
    module=mysqllexer

    git clone git.superjob.ru:/base/git/mysqllexer.git $module || exiterr $? "unable to download $module"
    cd $module
    phpize && ./configure && make || exiterr $? "unable to build $module"
    make install || exiterr $? "unable to install $module"
}

