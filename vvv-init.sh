#!/usr/bin/env bash

# =============================================================================
# WP Nostalgia
#
# By keesiemeijer
# https://github.com/keesiemeijer/wp-nostalgia
#
# VVV auto site setup script to install any version of WordPress.
# https://github.com/Varying-Vagrant-Vagrants/VVV
#
# Most earlier versions of WordPress are not compatible with PHP 5.3 or higher and produce (fatal) errors.
# WP-CLI requires 3.5.2 or higher to install WP. Use this script to install earlier versions.
#
# Warning!
#
#    The database and directory for the WordPress install are deleted prior to installing.
#    This script fixes (fatal) errors for earlier versions (WP < 2.0) by hacking core files.
#    This script hides errors by setting error_reporting off in:
#        wp-config.php (WP < 3.5.2)
#        wp-settings.php (WP < 3.0.0)
#
#
# After provisioning
#     (WP < 3.5.2)  Go to wp-nostalgia.test/readme.html and follow the install instructions
#     (WP >= 3.5.2) Go to wp-nostalgia.test/wp-admin and log in with: Username: admin, Password: password.
#
#
# This bash script can be used as a standalone script if you've already have wp-nostalgia.test running.
# Example install WordPress 2.2:
#     vagrant ssh
#     cd path/to/this/vvv-init.sh
#     bash vvv-init.sh 2.2
# 
# Credentials
#     DB Name: wp-nostalgia
#     DB User: wp
#     
# License: GPL-2.0+
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version. You may NOT assume that you can use any other version of the GPL. 
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# =============================================================================


# =============================================================================
# Variables
# 
# Note: Don't use spaces around the equal sign when editing variables below.
# =============================================================================

# Domain name
# Note: If edited, you'll need to edit it in the vvv-hosts and the vvv-nginx.conf files as well.
readonly HOME_URL="wp-nostalgia.test"


# WordPress version to be installed. Default: "0.71-gold"
# See the release archive: https://wordpress.org/download/release-archive/
# 
# Use a version number or "latest"
WP_VERSION="0.71-gold"

# Remove errors. Default true
readonly REMOVE_ERRORS=true

# Database credentials
readonly DB_NAME="wp-nostalgia"
readonly DB_USER="wp"
readonly DB_PASS="wp"

# Wordpress credentials
readonly WP_USER="admin"
readonly WP_PASS="password"


# =============================================================================
# 
# That's all, stop editing!
# 
# =============================================================================

# current path
readonly CURRENT_PATH=$(pwd)

# DocumentRoot dir in .conf file (if server is Apache)
readonly CURRENT_DIR="${PWD##*/}"

# path to the WordPress install for the developer reference website
readonly INSTALL_PATH="$CURRENT_PATH/public"

if [ $# == 1 ]; then
	WP_VERSION=$1
fi

function is_file() {
	local file=$1
	[[ -f $file ]]
}

function is_dir() {
	local dir=$1
	[[ -d $dir ]]
}

printf "\nStart Setup '%s'...\n" "$HOME_URL"


# =============================================================================
# Create vvv-hosts file (if it doesn't exist)
# =============================================================================

if ! is_file "$CURRENT_PATH/vvv-hosts"; then
	printf "Creating vvv-hosts file in %s\n" "$CURRENT_PATH"
	touch "$CURRENT_PATH/vvv-hosts"
	printf "%s\n" "$HOME_URL" >> "%s/vvv-hosts" "$CURRENT_PATH"
fi

# =============================================================================
# Creating database and 'public' directory
# =============================================================================

printf "Resetting database '%s'...\n" "$DB_NAME"
mysql -u root --password=root -e "DROP DATABASE IF EXISTS \`$DB_NAME\`"
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO $DB_USER@localhost IDENTIFIED BY '$DB_PASS';"


printf "Creating directory %s...\n" "$INSTALL_PATH"
if ! is_dir "$INSTALL_PATH"; then
	mkdir "$INSTALL_PATH"
else 
	rm -rf "$INSTALL_PATH"
	mkdir "$INSTALL_PATH"
fi

cd "$INSTALL_PATH" || exit

# =============================================================================
# Check Network Detection
#
# Make an HTTP request to google.com to determine if outside access is available
# to us. If 3 attempts with a timeout of 5 seconds are not successful, then we'll
# skip a few things further in provisioning rather than create a bunch of errors.
# =============================================================================
printf "Checking network connection...\n"
if ping -c 3 --linger=5 8.8.8.8 >> /dev/null 2>&1; then
	printf "Network connection detected...\n"
	printf "Downloading WordPress %s in %s...\n" "$WP_VERSION" "$INSTALL_PATH"
else
	printf "No network connection detected. ...\n"
	printf "Trying to get WordPress %s from cache...\n" "$WP_VERSION"
fi

if [[ "$WP_VERSION" = "latest" ]]; then
	wp core download --allow-root --force 2> /dev/null
	if is_file "$INSTALL_PATH/wp-includes/version.php"; then
		if grep -q "wp_version = " "$INSTALL_PATH/wp-includes/version.php"; then
			WP_VERSION=$(grep "wp_version = " "$INSTALL_PATH/wp-includes/version.php"|awk -F\' '{print $2}')
		fi
	fi
else
	wp core download --version="$WP_VERSION" --force --allow-root 2> /dev/null
fi

# Check if WordPress was downloaded
if ! is_file "$INSTALL_PATH/wp-config-sample.php"; then
	printf "Could not install WordPress. ...\n"
	printf "Make sure you are connected to the internet. ...\n"
	exit
fi

readonly TITLE="Wordpress $WP_VERSION"
readonly WP_VERSION="$WP_VERSION"

# =============================================================================
# Installing WordPress
# =============================================================================

finished=''
config_error=$(wp core config --dbname=$DB_NAME --dbuser=$DB_USER --dbpass=$DB_PASS --allow-root 2>&1 >/dev/null)

if [[ ! "$config_error" ]]; then
	# WP >= 3.5.2

	wp core install --url="$HOME_URL" --title="$TITLE" --admin_user="$WP_USER" --admin_password="$WP_PASS" --admin_email=demo@example.com --allow-root
	finished="Visit $HOME_URL/wp-admin Username: admin, Password: password"
else
	# WP < 3.5.2

	config_file="wp-config-sample.php"
	finished="Visit $HOME_URL/readme.html and follow the install instructions"

	if is_file "$INSTALL_PATH/$config_file"; then

		printf "Renaming wp-config-sample.php \n"
		cp "$INSTALL_PATH/wp-config-sample.php" "$INSTALL_PATH/wp-config.php"	

		if is_file "$INSTALL_PATH/wp-config.php"; then
			config_file="wp-config.php"
		fi	

		if [[ "$REMOVE_ERRORS" = true ]]; then
			# SRSLY Don't you dare show me any errors.
			sed -i -e "s/require_once(ABSPATH.'wp-settings.php');/error_reporting( 0 );\nrequire_once(ABSPATH.'wp-settings.php');\nerror_reporting( 0 );/g" "$INSTALL_PATH/$config_file"
			sed -i -e "s/require_once(ABSPATH . 'wp-settings.php');/error_reporting( 0 );\nrequire_once(ABSPATH . 'wp-settings.php');\nerror_reporting( 0 );/g" "$INSTALL_PATH/$config_file"
			if is_file "$INSTALL_PATH/wp-settings.php"; then
				sed -i -e "s/error_reporting(E_ALL ^ E_NOTICE);/error_reporting( 0 );/g" "$INSTALL_PATH/wp-settings.php"
				sed -i -e "s/error_reporting(E_ALL ^ E_NOTICE ^ E_USER_NOTICE);/error_reporting( 0 );/g" "$INSTALL_PATH/wp-settings.php"
				# Database errors
				sed -i -e "s/\$wpdb->show_errors();/\$wpdb->hide_errors();/g" "$INSTALL_PATH/wp-settings.php"
			fi
		fi
	fi	

	# WordPress 0.71-gold
	if is_file "$INSTALL_PATH/b2config.php"; then

		config_file="b2config.php"
		sed -i -e "s/http:\/\/example.com/http:\/\/$HOME_URL/g" "$INSTALL_PATH/$config_file"

		if [[ "$REMOVE_ERRORS" = true ]]; then
			printf "\n<?php error_reporting( 0 ); ?>\n" >> "$INSTALL_PATH/$config_file"
		fi
	fi

	if is_file "$INSTALL_PATH/$config_file"; then

		echo "Adding database credentials in $INSTALL_PATH/$config_file"

		sed -i -e "s/database_name_here/$DB_NAME/g" "$INSTALL_PATH/$config_file"
		sed -i -e "s/username_here/$DB_USER/g" "$INSTALL_PATH/$config_file"
		sed -i -e "s/password_here/$DB_PASS/g" "$INSTALL_PATH/$config_file"
		sed -i -e "s/define('DB_NAME', 'wordpress');/define('DB_NAME', '$DB_NAME');/g" "$INSTALL_PATH/$config_file"
		sed -i -e "s/define('DB_USER', 'username');/define('DB_USER', '$DB_USER');/g" "$INSTALL_PATH/$config_file"
		sed -i -e "s/define('DB_PASSWORD', 'password');/define('DB_PASSWORD', '$DB_PASS');/g" "$INSTALL_PATH/$config_file"
		sed -i -e "s/define('DB_NAME', 'putyourdbnamehere');/define('DB_NAME', '$DB_NAME');/g" "$INSTALL_PATH/$config_file"
		sed -i -e "s/define('DB_USER', 'usernamehere');/define('DB_USER', '$DB_USER');/g" "$INSTALL_PATH/$config_file"
		sed -i -e "s/define('DB_PASSWORD', 'yourpasswordhere');/define('DB_PASSWORD', '$DB_PASS');/g" "$INSTALL_PATH/$config_file"
		sed -i -e "s/define('DB_NAME', 'b2');/define('DB_NAME', '$DB_NAME');/g" "$INSTALL_PATH/$config_file"
		sed -i -e "s/define('DB_USER', 'user');/define('DB_USER', '$DB_USER');/g" "$INSTALL_PATH/$config_file"
		sed -i -e "s/define('DB_PASSWORD', 'pass');/define('DB_PASSWORD', '$DB_PASS');/g" "$INSTALL_PATH/$config_file"
	fi
fi

# =============================================================================
# Removing Errors
# =============================================================================

if [[ "$REMOVE_ERRORS" = true && "$config_error" ]]; then
	echo "Removing errors"

	# Blank admin screen WP version 3.3.*
	if [[ ${WP_VERSION:0:3} == "3.3" ]]; then
		if is_file "$INSTALL_PATH/wp-admin/includes/screen.php"; then
			sed -i -e "s/echo self\:\:\$this->_help_sidebar;/echo \$this->_help_sidebar;/g" "$INSTALL_PATH/wp-admin/includes/screen.php"
		fi
	fi

	# Remove errors for versions 0.* and 1.* (error with PHP 5 and higher)
	if [[ ${WP_VERSION:0:1} == "1" || ${WP_VERSION:0:1} == "0" ]]; then

		# WP version 0.71-gold (error with PHP 5.3.0 and higher)
		# Call-time pass-by-reference has been deprecated
		if is_file "$INSTALL_PATH/b2-include/b2template.functions.php"; then
			sed -i -e 's/\&\$/\$/g' "$INSTALL_PATH/b2-include/b2template.functions.php"
		fi

		# Blank Step 3 for the install process
		# Cannot use object of type stdClass as array (error with PHP 5 and higher)
		if is_file "$INSTALL_PATH/wp-admin/upgrade-functions.php" ; then
			sed -i -e "s/res\[0\]\['Type'\]/res\[0\]->Type/g" "$INSTALL_PATH/wp-admin/upgrade-functions.php"
		fi


		find "$INSTALL_PATH" ! -name "$(printf "*\n*")" -name "*.php" > tmp
		while IFS= read -r file
		do
			sed -i -e "s/\$HTTP_GET_VARS/\$_GET/g" "$file"
			sed -i -e "s/\$HTTP_POST_VARS/\$_POST/g" "$file"
			sed -i -e "s/\$HTTP_SERVER_VARS/\$_SERVER/g" "$file"
			sed -i -e "s/\$HTTP_COOKIE_VARS/\$_COOKIE/g" "$file"
		done < tmp
		rm tmp
	fi
fi

printf "\nFinished Setup %s with version: %s!\n" "$HOME_URL" "$WP_VERSION"
echo "$finished"
echo ""