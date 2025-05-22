#!/bin/bash
set -e

echo "Starting Drupal auto-installation process..."

# Wait for database to be ready
echo "Waiting for database connection..."
wait-for-it ${DRUPAL_DATABASE_HOST}:${DRUPAL_DATABASE_PORT} -t 60

# Clean up database to handle repeated installations
echo "Checking database state..."
if mysql -h${DRUPAL_DATABASE_HOST} -P${DRUPAL_DATABASE_PORT} -u${DRUPAL_DATABASE_USERNAME} -p${DRUPAL_DATABASE_PASSWORD} -e "USE ${DRUPAL_DATABASE_NAME}; SHOW TABLES;" 2>/dev/null | grep -q "drupal_install_test"; then
    echo "Found existing installation. Cleaning database..."
    mysql -h${DRUPAL_DATABASE_HOST} -P${DRUPAL_DATABASE_PORT} -u${DRUPAL_DATABASE_USERNAME} -p${DRUPAL_DATABASE_PASSWORD} -e "DROP DATABASE ${DRUPAL_DATABASE_NAME}; CREATE DATABASE ${DRUPAL_DATABASE_NAME};"
    echo "Database reset complete."
fi

cd /var/www/html

# Check if Drupal is already installed by looking for system.site configuration
if drush status bootstrap 2>/dev/null | grep -q "Successful"; then
    echo "Drupal already installed and bootstrap successful. Skipping installation."
    
    # Still ensure our theme and custom pages exist
    echo "Ensuring theme and custom pages are configured..."
    drush theme:enable mahi 2>/dev/null || true
    drush config:set system.theme default mahi -y 2>/dev/null || true
    
    # Check if Chat page exists, create if not
    if ! drush sql:query "SELECT 1 FROM node_field_data WHERE title='Chat' LIMIT 1" 2>/dev/null | grep -q "1"; then
        echo "Creating Chat page..."
        drush ev "\Drupal::service('entity_type.manager')->getStorage('node')->create(['type' => 'page', 'title' => 'Chat', 'body' => ['value' => '<h2>Real-time Chat Application</h2><iframe src=\"http://NODE_IP:30090\" width=\"100%\" height=\"600px\" frameborder=\"0\"></iframe>', 'format' => 'full_html'], 'status' => 1])->save();" || true
    fi
    
    # Check if AI OCR page exists, create if not
    if ! drush sql:query "SELECT 1 FROM node_field_data WHERE title='AI OCR' LIMIT 1" 2>/dev/null | grep -q "1"; then
        echo "Creating AI OCR page..."
        drush ev "\Drupal::service('entity_type.manager')->getStorage('node')->create(['type' => 'page', 'title' => 'AI OCR', 'body' => ['value' => '<h2>OCR Image Processing</h2><iframe src=\"http://NODE_IP:30180\" width=\"100%\" height=\"700px\" frameborder=\"0\"></iframe>', 'format' => 'full_html'], 'status' => 1])->save();" || true
    fi
    
    echo "Configuration complete."
    exit 0
fi

echo "Installing Drupal..."

# Run the Drupal installation
drush site:install standard --site-name="Kubernetes Demo Site" \
  --account-name=admin \
  --account-pass=admin123 \
  --account-mail=admin@example.com \
  --db-url=mysql://${DRUPAL_DATABASE_USERNAME}:${DRUPAL_DATABASE_PASSWORD}@${DRUPAL_DATABASE_HOST}:${DRUPAL_DATABASE_PORT}/${DRUPAL_DATABASE_NAME} \
  --yes

echo "Drupal core installation complete."

# Activate Mahi theme
echo "Activating Mahi theme..."
drush theme:enable mahi
drush config:set system.theme default mahi -y

# Create a basic page for Chat iframe - replace NODE_IP with the actual IP later
echo "Creating Chat page..."
NODE_IP=$(getent hosts | grep -v 127.0.0.1 | grep -v ::1 | head -1 | awk '{print $1}')
drush ev "\Drupal::service('entity_type.manager')->getStorage('node')->create(['type' => 'page', 'title' => 'Chat', 'body' => ['value' => '<h2>Real-time Chat Application</h2><iframe src=\"http://$NODE_IP:30090\" width=\"100%\" height=\"600px\" frameborder=\"0\"></iframe>', 'format' => 'full_html'], 'status' => 1])->save();"

# Create a basic page for AI OCR iframe
echo "Creating AI OCR page..."
drush ev "\Drupal::service('entity_type.manager')->getStorage('node')->create(['type' => 'page', 'title' => 'AI OCR', 'body' => ['value' => '<h2>OCR Image Processing</h2><iframe src=\"http://$NODE_IP:30180\" width=\"100%\" height=\"700px\" frameborder=\"0\"></iframe>', 'format' => 'full_html'], 'status' => 1])->save();"

# Enable required modules
echo "Enabling additional modules..."
drush pm:enable pathauto token admin_toolbar -y || true

# Update permissions
echo "Setting final permissions..."
chown -R www-data:www-data /var/www/html/sites/default

echo "Drupal installation and configuration completed successfully!"