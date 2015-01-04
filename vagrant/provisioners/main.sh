#!/bin/bash
#########################
# vagrant provisioner   #
# @author John Pancoast #
#########################
DOMAIN_NAME=$1
WEB_DIRECTORY=$2
ALT_WEB_SERVER_EMAIL="support@${DOMAIN_NAME}"
WEB_SERVER_EMAIL=${3:-$ALT_WEB_SERVER_EMAIL}

if [ $# -lt 2 ]; then
    echo -e "\nProvision machine - expects domain name, web accessible directory, and email (optional)\n"
    echo -e "\nUsage: $0 {DOMAIN_NAME} {WEB_DIRECTORY} [WEB_SERVER_EMAIL]\n"
    exit
fi

echo -e "\nRUNNING PROVISIONER...\n"

####################################
### INSTALLS                       #
### Various installs               #
####################################

# add EL repository
echo -e "\nPROVISIONER: add EL repository\n"
sudo rpm -Uvh https://mirror.webtatic.com/yum/el6/latest.rpm

# add epel repo
echo -e "\nPROVISIONER: add EPEL repo\n"
sudo wget http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
sudo rpm -ivh epel-release-6-8.noarch.rpm

# install apache
echo -e "\nPROVISIONER: install apache\n"
sudo yum install -v httpd -y
sudo sed -i 's/#NameVirtualHost/NameVirtualHost/g' /etc/httpd/conf/httpd.conf
sudo service httpd start
sudo chkconfig httpd on

# install mysql
echo -e "\nPROVISIONER: install mysql\n"
sudo yum install -v mysql-server -y
sudo service mysqld start
sudo chkconfig mysqld on

# install php 5.5
echo -e "\nPROVISIONER: install php 5.5\n"
sudo yum install -v php55w php55w-opcache php55w-devel php55w-mysql php55w-gd php55w-xml php55w-mcrypt php55w-pear php55w-soap php55w-mbstring -y
sudo sed -i 's/;date.timezone =/date.timezone = UTC/g' /etc/php.ini
sudo sed -i 's/memory_limit = 128M/memory_limit = 256M/g' /etc/php.ini

# install mongo
echo -e "\nPROVISIONER: install mongo\n"
REPOPATH=/etc/yum.repos.d/mongodb.repo
echo -e "\n[mongodb]\n" > $REPOPATH
echo -e "\nname=MongoDB Repository\n" >> $REPOPATH
echo -e "\nbaseurl=http://downloads-distro.mongodb.org/repo/redhat/os/x86_64/\n" >> $REPOPATH
echo -e "\ngpgcheck=0\n" >> $REPOPATH
echo -e "\nenabled=1\n" >> $REPOPATH

sudo yum install -v -y mongodb-org-2.6.6

# install compilers
# note - needed before pear/pecl calls
echo -e "\nPROVISIONER: install compilers\n"
sudo yum install -v gcc gcc-c++ autoconf automake -y

# install pear (required for php-pear)
echo -e "\nPROVISIONER: install pear\n"
sudo yum install -v php-pear

# install php's mongo driver
echo -e "\nPROVISIONER: install php's mongo driver\n"
sudo pecl install mongo

# install wget
echo -e "\nPROVISIONERI: install wget\n"
sudo yum install -v wget -y

# install ImageMagick
echo -e "\nPROVISIONER: install ImageMagick\n"
sudo yum install -v ImageMagick -y

# install composer
echo -e "\nPROVISIONER: install composer\n"
if [ ! -a /usr/local/bin/composer/composer.phar ]; then
    curl -sS https://getcomposer.org/installer | php
    sudo mv /home/vagrant/composer.phar /usr/local/bin/composer
fi

# install phpunit
echo -e "\nPROVISIONER: install phpunit\n"
if [ ! -a /usr/local/bin/phpunit/phpunit.phar ]; then
    wget https://phar.phpunit.de/phpunit.phar
    chmod +x phpunit.phar
    sudo mv /home/vagrant/phpunit.phar /usr/local/bin/phpunit
fi

# install node
echo -e "\nPROVISIONER: install node (and npm)\n"
sudo yum install -v nodejs npm --enablerepo=epel -y

# install sails
#echo -e "\nPROVISION: install npm package - sails\n"
#sudo npm -g install sails

# install forever
#echo -e "\nPROVISIONER: install npm package - forever\n"
#sudo npm -g install forever

# install nodemon
# @todo use either forever or nodemon
#sudo npm -g install nodemon

# install various tools
echo -e "\nPROVISIONER: install various tools\n"
sudo yum install -v vim -y
sudo yum install -v git -y
sudo yum install -v screen -y

####################################
### CONFIGURATION                  #
####################################

# add universal mysql user
echo -e "\nPROVISIONER: add universal mysql user\n"
mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'dbuser'@'localhost' IDENTIFIED BY 'dbpass' WITH GRANT OPTION;"

echo -e "\nPROVISIONER: Setup mongo data dir\n"
sudo mkdir -p /data/db/
sudo chown `id -u` /data/db

# enable mongo support in php
echo -e "\nPROVISIONER: enable mongo support in php\n"
sudo echo -e "\nextension=mongo.so\n" >> /etc/php.d/mongo.ini

# set local timezone to UTC
echo -e "\nPROVISIONER: Set local timezone to UTC\n"
sudo mv /etc/localtime /etc/localtime-orig
sudo ln -s /usr/share/zoneinfo/US/UTC /etc/localtime

# compile Xdebug
echo -e "\nPROVISIONER: compile Xdebug\n"
sudo pecl install Xdebug
XDEBUG=$(grep '\[xdebug\]' /etc/php.ini)
if [ -z "$XDEBUG" ]; then
    sudo cat /home/vagrant/templates/xdebug.ini >> /etc/php.ini
fi

# set apache user to vagrant
echo -e "\nPROVISIONER: change apache user\n"
sudo sed -i "s/User apache/User vagrant/" /etc/httpd/conf/httpd.conf
sudo sed -i "s/Group apache/Group vagrant/" /etc/httpd/conf/httpd.conf

# set perms for session dir
sudo chgrp -R vagrant /var/lib/php/session/

# create apache vhost
echo -e "\nPROVISIONER: Create vhost $DOMAIN_NAME > $WEB_DIRECTORY\n"
sudo cp /home/vagrant/templates/vhost.conf /etc/httpd/conf.d/$DOMAIN_NAME.conf
sudo sed -i "s|{{DOMAIN}}|$DOMAIN_NAME|g" /etc/httpd/conf.d/$DOMAIN_NAME.conf
sudo sed -i "s|{{DIRECTORY}}|$WEB_DIRECTORY|g" /etc/httpd/conf.d/$DOMAIN_NAME.conf
sudo sed -i "s|{{EMAIL}}|$WEB_SERVER_EMAIL|g" /etc/httpd/conf.d/$DOMAIN_NAME.conf

# create db
echo -e "\nPROVISIONER: Create database\n"
/vagrant/app/console doctrine:database:create
/vagrant/app/console doctrine:schema:create

####################################
### SERVICES                       #
### Initialize needed services     #
####################################
# restart apache
echo -e "\nPROVISIONER: restart apache\n"
sudo service httpd restart

echo -e "\nPROVISIONER: run mongo\n"
mongod --quiet &

#echo -e "\nPROVISIONER: start sails\n"
#cd /vagrant
#nodemon -V -e .js,.ejs app.js 2>&1

echo -e "\nPROVISIONER: Done\n"
