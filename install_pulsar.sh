#!/bin/sh

#COLORS
# Reset
Color_Off='\033[0m'       # Text Reset

# Regular Colors
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan

# Update packages and Upgrade system
echo "$Cyan \n Updating System... $Color_Off"
apt update -y && apt-get upgrade -y > /dev/null 2>&1

## Install AMP
echo "$Cyan \n Installing Apache2... $Color_Off"
apt install apache2 apache2-utils libexpat1 ssl-cert -y > /dev/null 2>&1

echo "$Cyan \n Installing PHP & Requirements... $Color_Off"
apt install libapache2-mod-php php php-common php-curl php-dev php-gd php-pear php-imagick php-mysql php-ps php-pspell php-xsl -y > /dev/null 2>&1

echo "$Cyan \n Installing MySQL... $Color_Off"
apt install mariadb-server -y > /dev/null 2>&1

echo "$Cyan \n Installing Git... $Color_Off"
apt-get install git -y

echo "$Cyan \n Verifying installs... $Color_Off"
apt install apache2 libapache2-mod-php php mariadb-server php-pear php-mysql php-mysql php-gd -y > /dev/null 2>&1

## TWEAKS and Settings

# Permissions
echo "$Cyan \n Permissions for /var/www... $Color_Off"
chown -R www-data:www-data /var/www
echo "$Green \n Permissions have been set! $Color_Off"

# Enabling Mod Rewrite, required for WordPress permalinks and .htaccess files
echo  "$Cyan \n Enabling Modules... $Color_Off"
sudo a2enmod rewrite > /dev/null 2>&1

# Restart Apache
echo "$Cyan \n Restarting Apache... $Color_Off"
sudo service apache2 restart > /dev/null 2>&1

# create system user
echo "$Cyan \n Creating system user... $Color_Off"
/usr/sbin/adduser pulsarsys
/usr/sbin/usermod -aG sudo pulsarsys

# Installing composer
echo "$Cyan \n Installing composer... $Color_Off"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
su - pulsarsys -c "php composer-setup.php --install-dir=/usr/local/bin --filename=composer"
chmod +x /usr/local/bin/composer
su - pulsarsys -c "composer --version"
echo "$Green \n Composer installed! $Color_Off"

# Making filesystem...
echo "$Cyan \n Making Filesystem... $Color_Off"
mkdir /var/www/pulsar
mkdir /var/www/pulsar/web
chmod -R 777 /var/www/pulsar


# Deploying Pulsar infrastructure...
echo "$Cyan \n Deploying Pulsar infrastructure... $Color_Off"

cd /var/www/pulsar/web
git clone https://github.com/andreyuok/pulsar-panel.git
wget https://getcomposer.org/download/latest-stable/composer.phar
mv composer.phar /var/www/pulsar/web/pulsar-panel/composer.phar
chmod +x /var/www/pulsar/web/pulsar-panel/composer.phar
chmod -R 777 /var/www/pulsar/web/pulsar-panel
su - pulsarsys -c "cd /var/www/pulsar/web/pulsar-panel/ && php composer.phar install"



#create pulsar mysql resources

mysql << EOF
DROP DATABASE IF EXISTS pulsar;
DROP USER IF EXISTS 'pulsar'@'localhost';
CREATE DATABASE pulsar;
CREATE USER  'pulsar'@'localhost' IDENTIFIED BY 'admin';
GRANT ALL PRIVILEGES ON *.* TO 'pulsar'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

rm /etc/apache2/sites-available/pulsar.webpanel.conf
cat > /etc/apache2/sites-available/pulsar.webpanel.conf << EOF
<VirtualHost *:80>
    ServerName pulsar.webpanel
    ServerAlias www.pulsar.webpanel

    DocumentRoot  /var/www/pulsar/web/pulsar-panel/public
    <Directory  /var/www/pulsar/web/pulsar-panel/public>
        AllowOverride All
        Order Allow,Deny
        Allow from All
    </Directory>

    # uncom ment the following lines if you install assets as symlinks
    # or run into problems when compiling LESS/Sass/CoffeeScript assets
    # <Directory /var/www/project>
    #     Options FollowSymlinks
    # </Directory>

    ErrorLog /var/log/apache2/project_error.log
    CustomLog /var/log/apache2/project_access.log combined
</VirtualHost>
EOF

sudo a2ensite pulsar.webpanel.conf
sudo service apache2 restart > /dev/null 2>&1
