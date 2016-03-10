#!/bin/bash
script_dir="$(dirname "$0")"
if [ -f ./vagrant.sh ]; then
    . ./vagrant.sh
    . ./php7.sh
else
    . /vagrant/vagrant/vagrant.sh
    . /vagrant/vagrant/php7.sh
fi

ensure-dir /var/vagrant

update-apt

install software-properties-common # changed in 14.04
install libpcre3-dev
install libcurl3-openssl-dev

add-repository ppa:nginx/stable
add-php7-repository
#apt-get update

install pkg-config
install git-core
install curl
install nginx
install apache2

install libapache2-mod-php7.0
install php7.0-fpm
install php7.0-cli
install php7.0-dev
install php7.0-mysql
install php7.0-curl
install php7.0-gd
install php7.0-json
install php7.0-mbstring
install php7.0-mcrypt
install php7.0-opcache
install php7.0-xml
install php-memcached
install php-imagick
install php-amqp
#install php7.0-xhprof
install php-xdebug

install libmagickwand-dev
install imagemagick
install build-essential

install-mysql
install-composer

install-php7-module blitz
install-php7-module igbinary
#install-php7-module mysqllexer

config-bash
config-hosts
config-locale
config-php7-fpm
config-php7-cli
config-php7-apache
config-apache
config-nginx-cert
config-nginx
#config-mysql

composer-require "phpunit/phpunit=4.8.*"
composer-require "phpunit/dbunit=1.2.*"
composer-require "phpunit/phpunit-selenium=*"
composer-require "phpunit/php-invoker=*"

service php7.0-fpm restart
service apache2 restart
service nginx restart

chown -R vagrant /vagrant


# init scripts here
cd /vagrant
#sudo -u vagrant ./install
cd -
#sudo -u vagrant ./update


exit 0