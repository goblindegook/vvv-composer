#!/bin/bash

## CONFIGURATION ##

DATABASE="wordpress_composer"

## PROVISIONING ##

echo "Setting up a local WordPress project for development..."

composer update

if [ ! -f "index.php" ]; then
    cat >"index.php" <<PHP
<?php require dirname( __FILE__ ) . '/wp/index.php';
PHP
fi

if ! $(wp core is-installed); then

    echo " * Creating database schema ${DATABASE}"

    mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS ${DATABASE}"
    mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON ${DATABASE}.* TO wp@localhost IDENTIFIED BY 'wp';"

    echo " * Configuring WordPress"

    WP_CACHE_KEY_SALT=`date +%s | sha256sum | head -c 64`

    wp core config --dbname="${DATABASE}" --extra-php <<PHP

define( 'WP_CACHE', true );
define( 'WP_CACHE_KEY_SALT', '$WP_CACHE_KEY_SALT' );

\$redis_server = array( 'host' => '127.0.0.1', 'port' => 6379 );

define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', true );
define( 'WP_DEBUG_DISPLAY', false );
define( 'SAVEQUERIES', false );
define( 'JETPACK_DEV_DEBUG', true );

@ini_set( 'display_errors', 0 );

define( 'WP_LOCAL_DEV', true );
define( 'WP_ENV', 'development' );

define( 'WP_CONTENT_DIR', dirname( __FILE__ ) . '/content' );

if ( defined( 'WP_HOME' ) ) {
    define( 'WP_CONTENT_URL', WP_HOME . '/content' );
} else {
    define( 'WP_CONTENT_URL', 'http://' . \$_SERVER['HTTP_HOST'] . '/content' );
}

if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', dirname( __FILE__ ) . '/wp/' );
}
PHP

    mv wp/wp-config.php .

    wp core install

    echo " * Setting additional options"

    HOMEURL=$(wp option get home)
    wp option update siteurl "$HOMEURL/wp"
    wp option update permalink_structure "/%postname%/"

    ## OBJECT CACHE ##

    echo " * Setting up object cache"

    sudo apt-get -y install redis-server php5-redis
    sudo service php5-fpm restart
    cp content/plugins/wp-redis/object-cache.php content/object-cache.php
    touch content/advanced-cache.php

    echo " * Importing test content"

    curl -OLs https://raw.githubusercontent.com/manovotny/wptest/master/wptest.xml
    wp plugin activate wordpress-importer
    wp import wptest.xml --authors=create
    rm wptest.xml
fi

echo "All done!"
