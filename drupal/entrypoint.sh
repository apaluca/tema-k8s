#!/bin/bash
set -e

# Ensure directory exists and has correct permissions
mkdir -p /var/www/html/sites/default/files
chmod 777 /var/www/html/sites/default
chmod 777 /var/www/html/sites/default/files

# Copy settings file if it doesn't exist
if [ ! -f /var/www/html/sites/default/settings.php ]; then
    echo "Copying settings.php file..."
    cp /tmp/settings.php /var/www/html/sites/default/settings.php
    chmod 664 /var/www/html/sites/default/settings.php
fi

# Always ensure correct permissions
chown -R www-data:www-data /var/www/html/sites/default

# Run installation script in the background
echo "Starting auto-install script in background..."
nohup /usr/local/bin/auto-install.sh > /var/log/drupal-install.log 2>&1 &

# Start Apache in the foreground
echo "Starting Apache web server..."
exec "$@"