<?php
/**
 * Plugin Name: Autoloader
 * Description: Autoload Composer dependencies.
 * Version: 1.0
 * Author: Luís Rodrigues
 * Author URI: https://github.com/goblindegook
 */

require_once ABSPATH . '../vendor/autoload.php';

\register_theme_directory( ABSPATH . 'wp-content/themes/' );
