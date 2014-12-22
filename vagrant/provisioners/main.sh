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
    echo "Provision machine - expects domain name, web accessible directory, and email (optional)"
    echo "Usage: $0 [DOMAIN_NAME] [WEB_DIRECTORY] [WEB_SERVER_EMAIL]"
    exit
fi

echo "RUNNING PROVISIONER..."

####################################
### INSTALLS                       #
### Various installs               #
####################################

# add EL repository
echo "PROVISIONER: add EL repository"
sudo rpm -Uvh https://mirror.webtatic.com/yum/el6/latest.rpm

# add epel repo
echo "PROVISIONER: add EPEL repo"
sudo wget http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
sudo rpm -ivh epel-release-6-8.noarch.rpm

# install apache
echo "PROVISIONER: install apache"
sudo yum install -v httpd -y
sudo sed -i 's/#NameVirtualHost/NameVirtualHost/g' /etc/httpd/conf/httpd.conf
sudo service httpd start
sudo chkconfig httpd on

# install mysql
echo "PROVISIONER: install mysql"
sudo yum install -v mysql-server -y
sudo service mysqld start
sudo chkconfig mysqld on

# install php 5.5
echo "PROVISIONER: install php 5.5"
sudo yum install -v php55w php55w-opcache php55w-devel php55w-mysql php55w-gd php55w-xml php55w-mcrypt php55w-pear php55w-soap -y
sudo sed -i 's/;date.timezone =/date.timezone = UTC/g' /etc/php.ini
sudo sed -i 's/memory_limit = 128M/memory_limit = 256M/g' /etc/php.ini

# install mongo
echo "PROVISIONER: install mongo"
REPOPATH=/etc/yum.repos.d/mongodb.repo
echo "[mongodb]" > $REPOPATH
echo "name=MongoDB Repository" >> $REPOPATH
echo "baseurl=http://downloads-distro.mongodb.org/repo/redhat/os/x86_64/" >> $REPOPATH
echo "gpgcheck=0" >> $REPOPATH
echo "enabled=1" >> $REPOPATH

sudo yum install -v -y mongodb-org-2.6.6

# install compilers
# note - needed before pear/pecl calls
echo "PROVISIONER: install compilers"
sudo yum install -v gcc gcc-c++ autoconf automake -y

# install pear (required for php-pear)
echo "PROVISIONER: install pear"
sudo yum install -v php-pear

# install php's mongo driver
echo "PROVISIONER: install php's mongo driver"
sudo pecl install mongo

# install wget
echo "PROVISIONERI: install wget"
sudo yum install -v wget -y

# install ImageMagick
echo "PROVISIONER: install ImageMagick"
sudo yum install -v ImageMagick -y

# install composer
echo "PROVISIONER: install composer"
if [ ! -a /usr/local/bin/composer/composer.phar ]; then
    curl -sS https://getcomposer.org/installer | php
    sudo mv /home/vagrant/composer.phar /usr/local/bin/composer
fi

# install phpunit
echo "PROVISIONER: install phpunit"
if [ ! -a /usr/local/bin/phpunit/phpunit.phar ]; then
    wget https://phar.phpunit.de/phpunit.phar
    chmod +x phpunit.phar
    sudo mv /home/vagrant/phpunit.phar /usr/local/bin/phpunit
fi

# install node
echo "PROVISIONER: install node (and npm)"
sudo yum install -v nodejs npm --enablerepo=epel -y

# install sails
#echo "PROVISION: install npm package - sails"
#sudo npm -g install sails

# install forever
#echo "PROVISIONER: install npm package - forever"
#sudo npm -g install forever

# install nodemon
# @todo use either forever or nodemon
#sudo npm -g install nodemon

# install various tools
echo "PROVISIONER: install various tools"
sudo yum install -v vim -y
sudo yum install -v git -y
sudo yum install -v screen -y

####################################
### CONFIGURATION                  #
####################################

# add universal mysql user
echo "PROVISIONER: add universal mysql user"
mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'dbuser'@'localhost' IDENTIFIED BY 'dbpass' WITH GRANT OPTION;"

echo "PROVISIONER: Setup mongo data dir"
sudo mkdir -p /data/db/
sudo chown `id -u` /data/db

# enable mongo support in php
echo "PROVISIONER: enable mongo support in php"
sudo echo "extension=mongo.so" >> /etc/php.d/mongo.ini

# set local timezone to UTC
echo "PROVISIONER: Set local timezone to UTC"
sudo mv /etc/localtime /etc/localtime-orig
sudo ln -s /usr/share/zoneinfo/US/UTC /etc/localtime

# compile Xdebug
echo "PROVISIONER: compile Xdebug"
sudo pecl install Xdebug
XDEBUG=$(grep '\[xdebug\]' /etc/php.ini)
if [ -z "$XDEBUG" ]; then
    sudo cat /home/vagrant/templates/xdebug.ini >> /etc/php.ini
fi

# create apache vhost
echo "PROVISIONER: Create vhost $DOMAIN_NAME > $WEB_DIRECTORY"
sudo cp /home/vagrant/templates/vhost.conf /etc/httpd/conf.d/$DOMAIN_NAME.conf
sudo sed -i "s|{{DOMAIN}}|$DOMAIN_NAME|g" /etc/httpd/conf.d/$DOMAIN_NAME.conf
sudo sed -i "s|{{DIRECTORY}}|$WEB_DIRECTORY|g" /etc/httpd/conf.d/$DOMAIN_NAME.conf
sudo sed -i "s|{{EMAIL}}|$WEB_SERVER_EMAIL|g" /etc/httpd/conf.d/$DOMAIN_NAME.conf

####################################
### SERVICES                       #
### Initialize needed services     #
####################################
# restart apache
echo "PROVISIONER: restart apache"
sudo service httpd restart

echo "PROVISIONER: run mongo"
mongod --quiet &

#echo "PROVISIONER: start sails"
#cd /vagrant
#nodemon -V -e .js,.ejs app.js 2>&1

echo "PROVISIONER: Done"
