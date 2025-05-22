FROM drupal:latest

# Install Drush
RUN composer require drush/drush

# Install Mahi theme
RUN composer require 'drupal/mahi:^1.1'

# Asigura permisiunile corecte
RUN chown -R www-data:www-data /var/www/html