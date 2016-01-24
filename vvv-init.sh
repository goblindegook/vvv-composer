#!/bin/bash

## FUNCTIONS ##

noroot() {
  sudo -EH -u vagrant HTTP_HOST="${SITE_HOST}" "$@";
}

get_yaml() {
  local yaml=$1
  local key=$2
  local s='[[:space:]]*'
  local w='[a-zA-Z0-9_]*'

  sed -n "s/^$s$key$s:$s\($w\)$s$/\1/ p" "$yaml"
}

## PROVISIONING ##

DATABASE=$(get_yaml "wp-cli.local.yml" dbname)

echo "Setting up a local WordPress project for development..."

noroot composer update

if [ ! -f "index.php" ]; then
    noroot cat >"index.php" <<PHP
<?php require dirname( __FILE__ ) . '/wp/index.php';
PHP
fi

if ! $(noroot wp core is-installed); then

    echo " * Creating database schema ${DATABASE}"

    mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS ${DATABASE}"
    mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON ${DATABASE}.* TO wp@localhost IDENTIFIED BY 'wp';"

    echo " * Configuring WordPress"

    WP_CACHE_KEY_SALT=`date +%s | sha256sum | head -c 64`

    noroot wp core config --extra-php <<PHP

define( 'WP_CACHE', true );
define( 'WP_CACHE_KEY_SALT', '$WP_CACHE_KEY_SALT' );

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

    noroot mv wp/wp-config.php .

    noroot wp core install

    echo " * Setting additional options"

    HOMEURL=$(noroot wp option get home)
    noroot wp option update siteurl "$HOMEURL/wp"
    noroot wp option update permalink_structure "/%postname%/"

    echo " * Importing test content"

    noroot curl -OLs https://raw.githubusercontent.com/manovotny/wptest/master/wptest.xml
    noroot wp plugin activate wordpress-importer
    noroot wp import wptest.xml --authors=create
    noroot rm wptest.xml
fi

echo "All done!"
