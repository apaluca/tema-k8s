#!/bin/bash
set -e

echo "🚀 Starting Drupal installation Job..."

# Wait for database to be ready
echo "⏳ Waiting for database connection..."
wait-for-it ${DRUPAL_DATABASE_HOST}:${DRUPAL_DATABASE_PORT} -t 120

# Give database extra time to be fully ready
sleep 10

# Clean database completely to ensure fresh install
echo "🧹 Cleaning database completely..."
mysql -h${DRUPAL_DATABASE_HOST} -P${DRUPAL_DATABASE_PORT} -u${DRUPAL_DATABASE_USERNAME} -p${DRUPAL_DATABASE_PASSWORD} -e "
DROP DATABASE IF EXISTS ${DRUPAL_DATABASE_NAME}; 
CREATE DATABASE ${DRUPAL_DATABASE_NAME};" 2>/dev/null || {
    echo "❌ Failed to clean database. Exiting."
    exit 1
}

# Ensure proper permissions
mkdir -p /var/www/html/sites/default/files
chmod 777 /var/www/html/sites/default
chmod 777 /var/www/html/sites/default/files

# Copy settings file
if [ ! -f /var/www/html/sites/default/settings.php ]; then
    echo "📄 Copying settings.php file..."
    cp /tmp/settings.php /var/www/html/sites/default/settings.php
    chmod 664 /var/www/html/sites/default/settings.php
fi

cd /var/www/html

echo "🔧 Installing Drupal..."

# Run the Drupal installation
drush site:install standard \
  --site-name="Kubernetes Demo Site" \
  --account-name=admin \
  --account-pass=admin123 \
  --account-mail=admin@example.com \
  --db-url=mysql://${DRUPAL_DATABASE_USERNAME}:${DRUPAL_DATABASE_PASSWORD}@${DRUPAL_DATABASE_HOST}:${DRUPAL_DATABASE_PORT}/${DRUPAL_DATABASE_NAME} \
  --yes || {
    echo "❌ Drupal installation failed"
    exit 1
  }

echo "✅ Drupal core installation complete."

# Activate Mahi theme
echo "🎨 Activating Mahi theme..."
drush theme:enable mahi
drush config:set system.theme default mahi -y

# Get the current node IP dynamically
echo "🔍 Detecting node IP..."
NODE_IP=$(hostname -I | awk '{print $1}')
if [ -z "$NODE_IP" ] || [ "$NODE_IP" = "127.0.0.1" ]; then
    # Fallback: try to get from environment or use a default
    NODE_IP="192.168.1.100"  # You'll need to replace this with your actual node IP
    echo "⚠️  Using fallback IP: $NODE_IP"
else
    echo "📍 Detected node IP: $NODE_IP"
fi

# Create Chat page
echo "💬 Creating Chat page..."
drush ev "
\$node = \Drupal::entityTypeManager()->getStorage('node')->create([
    'type' => 'page',
    'title' => 'Chat Application',
    'body' => [
        'value' => '<h2>Real-time Chat Application</h2><p>Connect and chat with other users in real-time.</p><iframe src=\"http://$NODE_IP:30090\" width=\"100%\" height=\"600px\" frameborder=\"0\" style=\"border: 1px solid #ccc; border-radius: 5px;\"></iframe>',
        'format' => 'full_html'
    ],
    'status' => 1
]);
\$node->save();
echo 'Chat page created with nid: ' . \$node->id();
" || echo "⚠️  Failed to create Chat page"

# Create AI OCR page
echo "🤖 Creating AI OCR page..."
drush ev "
\$node = \Drupal::entityTypeManager()->getStorage('node')->create([
    'type' => 'page',
    'title' => 'AI Image Recognition',
    'body' => [
        'value' => '<h2>OCR Image Processing with Azure AI</h2><p>Upload images to extract text using Azure Computer Vision OCR.</p><iframe src=\"http://$NODE_IP:30180\" width=\"100%\" height=\"700px\" frameborder=\"0\" style=\"border: 1px solid #ccc; border-radius: 5px;\"></iframe>',
        'format' => 'full_html'
    ],
    'status' => 1
]);
\$node->save();
echo 'AI OCR page created with nid: ' . \$node->id();
" || echo "⚠️  Failed to create AI OCR page"

# Create a welcome/homepage
echo "🏠 Creating homepage content..."
drush ev "
\$node = \Drupal::entityTypeManager()->getStorage('node')->create([
    'type' => 'page',
    'title' => 'Welcome to Kubernetes Demo',
    'body' => [
        'value' => '<h2>Kubernetes Web Application Demo</h2>
                   <p>This site demonstrates a complete web application running on Kubernetes with:</p>
                   <ul>
                     <li><strong>Drupal CMS</strong> - Content management with Mahi theme</li>
                     <li><strong>Real-time Chat</strong> - WebSocket-based communication</li>
                     <li><strong>AI OCR Processing</strong> - Azure Computer Vision integration</li>
                   </ul>
                   <h3>Quick Links:</h3>
                   <p><a href=\"/node/1\" class=\"button\">💬 Chat Application</a></p>
                   <p><a href=\"/node/2\" class=\"button\">🤖 AI Image Recognition</a></p>',
        'format' => 'full_html'
    ],
    'status' => 1,
    'promote' => 1
]);
\$node->save();
echo 'Homepage created with nid: ' . \$node->id();
" || echo "⚠️  Failed to create homepage"

# Enable additional modules
echo "🔌 Enabling additional modules..."
drush pm:enable pathauto token admin_toolbar -y || echo "⚠️  Some modules failed to enable"

# Set homepage
echo "🏠 Setting front page..."
drush config:set system.site page.front /node/3 -y || echo "⚠️  Failed to set front page"

# Set final permissions
echo "🔒 Setting final permissions..."
chown -R www-data:www-data /var/www/html/sites/default

# Create completion marker
echo "📝 Creating installation completion marker..."
touch /var/www/html/sites/default/files/.drupal_installed
echo "Installation completed at: $(date)" > /var/www/html/sites/default/files/.drupal_installed

echo "🎉 Drupal installation and configuration completed successfully!"
echo "📊 Installation summary:"
echo "   - Site name: Kubernetes Demo Site"
echo "   - Admin user: admin / admin123"
echo "   - Theme: Mahi"
echo "   - Pages created: Welcome, Chat, AI OCR"
echo "   - Node IP used: $NODE_IP"