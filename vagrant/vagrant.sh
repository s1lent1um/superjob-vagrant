#!/bin/bash
PROJECT_DIR="/vagrant"

CURRENT_DIR=$(pwd)

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
#    echo "$@"
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

pecl-install() {
  package=$1
  package=${package%-beta}
  package=${package%-alpha}
  package=${package%-devel}
  installed pecl-$package
  if [ "$?" -gt 0 ]; then
    printf "\n" | pecl install -a $2 $1 || exiterr $? "pecl $1 installation fault"
    echo "extension=$package.so" > /etc/php5/mods-available/${package}.ini
    php5enmod $package
    installed pecl-$package ok
  fi
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


install-openresty() {
    installed openresty
    if [ "$?" -gt 0 ]; then
        wget http://info.8bitgroup.com/pkgs/openresty_1.7.4.1_amd64.deb
        wget http://info.8bitgroup.com/pkgs/libip2location7_7.0.0-1_amd64.deb
        dpkg -i libip2location7_7.0.0-1_amd64.deb openresty_1.7.4.1_amd64.deb
        installed openresty ok

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

add-docker-repository() {
  configured docker-repository
  if [ "$?" -gt 0 ]; then
    apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
    exiterr $? "Failed to add the docker repository key"
    echo 'deb https://apt.dockerproject.org/repo ubuntu-trusty main' > /etc/apt/sources.list.d/docker.list
    configured docker-repository ok
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

config-nginx() {
    ensure-dir /var/log/www/
    ensure-rm /etc/nginx/sites-enabled/default
    copy "${PROJECT_DIR}/vagrant/sites-available/*" /etc/nginx/sites-enabled/
    copy ${PROJECT_DIR}/vagrant/nginx.conf /etc/nginx/nginx.conf
#    copy ${PROJECT_DIR}/vagrant/fastcgi_params /etc/nginx/fastcgi_params
}

config-openresty() {
    ensure-dir /var/log/www/
    ensure-dir /var/log/nginx/
    ensure-rm /usr/local/openresty/nginx/conf/default
    copy "${PROJECT_DIR}/vagrant/sites-available/*" /usr/local/openresty/nginx/conf/sites-enabled/
    copy ${PROJECT_DIR}/vagrant/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
#    copy ${PROJECT_DIR}/vagrant/fastcgi_params /usr/local/openresty/nginx/conf/fastcgi_params
}

config-beanstalk() {
    copy ${PROJECT_DIR}/vagrant/beanstalkd /etc/default/beanstalkd
    service beanstalkd restart
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

config-mysql() {
  configured mysql
  if [ "$?" -gt 0 ]; then
    mysql -uroot -e "GRANT ALL ON *.* TO 'shakes'@'%' IDENTIFIED BY 'uVnYMcQvtQop9fpsD6Kc'; FLUSH PRIVILEGES;" || exiterr $? "Unable to configure mysql user shakes"
    mysql -uroot -e "GRANT ALL ON *.* TO 'shakes_console'@'%' IDENTIFIED BY 'tyFoeZgyRWXqGx4KCmmV'; FLUSH PRIVILEGES;" || exiterr $? "Unable to configure mysql user shakes_console"
    mysql -uroot -e "GRANT ALL ON *.* TO 'shakes_tests'@'%' IDENTIFIED BY '6FjGjcWBPEDvHox7bMcg'; FLUSH PRIVILEGES;" || exiterr $? "Unable to configure mysql user shakes_tests"
    mysql -uroot -e "GRANT ALL ON *.* TO 'partners2'@'%' IDENTIFIED BY 'HVpGl2k1CXK5DfWl'; FLUSH PRIVILEGES;" || exiterr $? "Unable to configure mysql user partners2"
    mysql -uroot -e "CREATE DATABASE IF NOT EXISTS partners COLLATE utf8_general_ci;" || exiterr $? "Unable to configure mysql db partners"
    mysql -uroot -e "CREATE DATABASE IF NOT EXISTS shakes COLLATE utf8_general_ci;" || exiterr $? "Unable to configure mysql db shakes"
    mysql -uroot -e "CREATE DATABASE IF NOT EXISTS shakes_stats COLLATE utf8_general_ci;" || exiterr $? "Unable to configure mysql db shakes_stats"
    mysql -uroot -e "CREATE DATABASE IF NOT EXISTS shakes_tests COLLATE utf8_general_ci;" || exiterr $? "Unable to configure mysql db shakes_tests"
    mysql -uroot -e "CREATE DATABASE IF NOT EXISTS shakes_stats_tests COLLATE utf8_general_ci;" || exiterr $? "Unable to configure mysql db shakes_stats_tests"
    configured mysql ok
  fi
}



config-mongo() {
    configured mongo
    if [ "$?" -gt 0 ]; then
        ensure-dir /var/log/mongodb
        chown mongodb:mongodb /var/log/mongodb
        ensure-dir /var/lib/mongodb/mongo1/
        ensure-dir /var/lib/mongodb/mongo2/
        ensure-dir /var/lib/mongodb/mongoc/
        ensure-dir /var/lib/mongodb/mongos/
        chown mongodb:mongodb -R /var/lib/mongodb
        copy "${PROJECT_DIR}/vagrant/mongo/*.conf" /etc/
        configured mongo ok
    fi
}

config-db() {
    configured db
    if [ "$?" -gt 0 ]; then
        mongo admin --eval 'sh.addShard("localhost:27011")'
        exiterr $? "Failed to add shard mongo1"
        mongo admin --eval 'sh.addShard("localhost:27012")'
        exiterr $? "Failed to add shard mongo2"
#        mongo posts --eval 'db.createCollection("hub");sh.enableSharding("posts");'
#        exiterr $? "Failed to enable sharding"
        # TODO: restore all mongo dumps
#        mongorestore -d router ${PROJECT_DIR}/vagrant/mongo/router/
#        exiterr $? "Failed to restore router"
        configured db ok
    fi
}


config-upstart() {
    configured upstart-mongo
    if [ "$?" -gt 0 ]; then
        stop mongod
        if [ -f /etc/init/mongod.conf ]; then
            mv /etc/init/mongod.conf /etc/init/mongod.conf.bak
        fi
        copy "${PROJECT_DIR}/vagrant/upstart/*.conf" /etc/init/
        start mongoc
        exiterr $? "Failed to start mongoc"
        start mongo1
        exiterr $? "Failed to start mongo1"
        start mongo2
        exiterr $? "Failed to start mongo2"
        sleep 2
        start mongos
        exiterr $? "Failed to start mongos"
        configured upstart-mongo ok
        sleep 2
    fi
}
