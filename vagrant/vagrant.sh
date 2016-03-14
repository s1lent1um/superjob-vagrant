#!/bin/bash
PROJECT_DIR="/vagrant"

CURRENT_DIR=$(pwd)

ssh-copy() {
  chmod 600 ~vagrant/.ssh/id_rsa && chown -R vagrant:vagrant ~vagrant/.ssh/
  cp -r ~vagrant/.ssh/ ~/ && chown -R root:root ~/.ssh/
}

exiterr() {
  if [ "$1" -gt 0 ]; then
    if [ ! -z "$2" ]; then
      echo $2
    fi
    exit $1
  fi
}

ensure-dir() {
    if [ ! -d $1 ]; then
       mkdir -p $1
       exiterr $? "Failed to create directory $1"
    fi
}

ensure-rm() {
    if [ -f $1 ]; then
       rm -r $1
       exiterr $? "Failed to remove $1"
    fi
}

copy() {
    cp $1 $2
    exiterr $? "Failed to copy $1 into $2"
}

installed() {
  if [ -z "$2" ]; then
    if [ -f /var/vagrant/installed-$1 ]; then
      return 0
    fi
    return 1
  fi

  touch /var/vagrant/installed-$1
}

install() {
    installed $1
    if [ "$?" -gt 0 ]; then
        apt-get install -q -y $1 || exiterr $? "$1 installation fault"
        installed $1 ok
    fi
}

configured() {
    if [ -z "$2" ]; then
      if [ -f /var/vagrant/configured-$1 ]; then
        return 0
      fi
      return 1
    fi

    touch /var/vagrant/configured-$1
}

update-apt() {
  # TODO: ttl
  configured apt-update
  if [ "$?" -gt 0 ]; then
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --force-yes -fuy upgrade
    exiterr $? "Failed to update apt"
    configured apt-update ok
  fi
}


install-mysql() {
  installed mysql
  if [ "$?" -gt 0 ]; then
    echo 'mysql-server mysql-server/root_password password 123' | debconf-set-selections
    echo 'mysql-server mysql-server/root_password_again password 123' | debconf-set-selections
    DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server mysql-client || exiterr $? "Unable to install mysql"
    mysql -p123 -uroot -e "UPDATE mysql.user SET Password=PASSWORD('') WHERE User='root'; GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY ''; FLUSH PRIVILEGES;" || exiterr $? "Unable to configure mysql"
    installed mysql ok
  fi
}


install-composer() {
    installed php-composer
    if [ "$?" -gt 0 ]; then
        curl -sS https://getcomposer.org/installer | php
        mv composer.phar /usr/local/bin/composer
        token=`cat ${PROJECT_DIR}/token | awk '{print $1;}'`
        su vagrant -c "composer config -g github-oauth.github.com ${token}"
        composer-require "fxp/composer-asset-plugin:~1.1"
        installed php-composer ok
    fi
}

composer-require() {
    su vagrant -c "composer global require \"$1\" --no-interaction --no-progress"
}

add-php55-repository() {
  configured php55
  if [ "$?" -gt 0 ]; then
    add-apt-repository -y ppa:ondrej/php5
    exiterr $? "Failed to add the php5 repository"
    configured php55 ok
  fi
}

add-php56-repository() {
  configured php56
  if [ "$?" -gt 0 ]; then
    add-apt-repository -y ppa:ondrej/php5-5.6
    exiterr $? "Failed to add the php5 repository"
    configured php56 ok
  fi
}

add-php7-repository() {
  configured php7
  if [ "$?" -gt 0 ]; then
    add-apt-repository -y ppa:ondrej/php
    exiterr $? "Failed to add the php7 repository"
    configured php7 ok
  fi
}

add-repository() {
  alias=`echo $1 | sed 's/[\/:]/-/g'`
  configured $alias
  if [ "$?" -gt 0 ]; then
    add-apt-repository -y $1
    exiterr $? "Failed to add the $1 repository"
    configured $alias ok
  fi
}


config-hosts() {
  copy ${PROJECT_DIR}/vagrant/hosts /etc/hosts
}

config-bash() {
  copy ${PROJECT_DIR}/vagrant/.bashrc ~vagrant/.bashrc
}

config-php-fpm() {
  copy ${PROJECT_DIR}/vagrant/php.ini /etc/php5/fpm/php.ini
  copy ${PROJECT_DIR}/vagrant/fpm.conf /etc/php5/fpm/pool.d/www.conf
}

config-php-cli() {
  copy ${PROJECT_DIR}/vagrant/php.ini /etc/php5/cli/php.ini
}

config-nginx-cert() {
    configured nginx-cert
    if [ "$?" -gt 0 ]; then
        ensure-dir /etc/nginx/certs/
        openssl req -x509 -batch -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/certs/0sjob.ru.key -out /etc/nginx/certs/0sjob.ru.crt
        openssl req -x509 -batch -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/certs/0sjob.uz.key -out /etc/nginx/certs/0sjob.uz.crt
        openssl req -x509 -batch -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/certs/0sjob.ua.key -out /etc/nginx/certs/0sjob.ua.crt
        configured nginx-cert ok
    fi
}

config-nginx() {
    ensure-dir /var/log/www/
    ensure-dir /www/nginx/logs/
    ensure-dir /www/nginx/cache/
    ensure-rm /etc/nginx/sites-enabled/default
    copy "${PROJECT_DIR}/vagrant/sites-available/*" /etc/nginx/sites-enabled/
    copy ${PROJECT_DIR}/vagrant/nginx.conf /etc/nginx/nginx.conf
#    copy ${PROJECT_DIR}/vagrant/fastcgi_params /etc/nginx/fastcgi_params
}

config-apache() {
    a2enmod rewrite expires headers
    ensure-dir /srv/src/0sjob.public/
    ensure-dir /srv/src/0sjob.var/apache/
    ensure-dir /srv/src/0sjob.var/cache/
    ensure-dir /srv/src/0sjob.var/error_logs/
    ensure-rm /etc/apache2/sites-enabled/000-default.conf
    copy "${PROJECT_DIR}/vagrant/apache2/apache2.conf" /etc/apache2/
    copy "${PROJECT_DIR}/vagrant/apache2/ports.conf" /etc/apache2/
    copy "${PROJECT_DIR}/vagrant/apache2/vhosts.conf" /etc/apache2/sites-enabled/
}


config-locale() {
  configured locale
  if [ "$?" -gt 0 ]; then
    locale-gen ru_RU.UTF-8
    exiterr $? "Failed to generate locale ru_RU.UTF-8"
    copy ${PROJECT_DIR}/vagrant/locale /etc/default/locale
    exiterr $? "Failed to replace locale into /etc/default/locale"
    dpkg-reconfigure locales
    exiterr $? "Failed to reconfigure locale"
    configured locale ok
  fi
}


config-upstart() {
    copy "${PROJECT_DIR}/vagrant/upstart/*" /etc/init/
}
