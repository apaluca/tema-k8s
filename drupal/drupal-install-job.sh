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
  --site-name="Cloud-Native Demo Platform" \
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

# Get the correct Kubernetes node IP using multiple methods
echo "🔍 Detecting correct Kubernetes node IP..."
NODE_IP=""

# Method 1: Use environment variable from Kubernetes downward API (most reliable)
if [ ! -z "$KUBERNETES_NODE_IP" ] && [ "$KUBERNETES_NODE_IP" != "127.0.0.1" ]; then
    NODE_IP="$KUBERNETES_NODE_IP"
    echo "📍 Using Kubernetes downward API node IP: $NODE_IP"
fi

# Method 2: Try to get from host networking if available
if [ -z "$NODE_IP" ] && [ -f "/proc/net/route" ]; then
    # Try to get default route IP
    DEFAULT_ROUTE_IP=$(ip route | grep default | awk '{print $3}' | head -1 2>/dev/null || echo "")
    if [ ! -z "$DEFAULT_ROUTE_IP" ] && echo "$DEFAULT_ROUTE_IP" | grep -qvE '^127\.|^169\.254\.' 2>/dev/null; then
        # Get the interface IP that routes to this gateway
        ROUTE_IP=$(ip route get "$DEFAULT_ROUTE_IP" 2>/dev/null | grep -oP 'src \K[0-9.]+' | head -1 || echo "")
        if [ ! -z "$ROUTE_IP" ] && echo "$ROUTE_IP" | grep -qE '^192\.168\.|^10\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.'; then
            NODE_IP="$ROUTE_IP"
            echo "📍 Using route-based detection: $NODE_IP"
        fi
    fi
fi

# Method 3: Try to detect from network interfaces (look for common private IP ranges)
if [ -z "$NODE_IP" ]; then
    echo "🔍 Fallback: scanning network interfaces..."
    for ip in $(hostname -I 2>/dev/null || ip addr show | grep -oP 'inet \K[0-9.]+'); do
        # Check if IP is in common private ranges: 192.168.x.x, 10.x.x.x, 172.16-31.x.x
        if echo "$ip" | grep -qE '^192\.168\.|^10\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.'; then
            # Prefer 192.168.x.x range as it's most common for local networks
            if echo "$ip" | grep -qE '^192\.168\.'; then
                NODE_IP="$ip"
                echo "📍 Using preferred private IP: $NODE_IP"
                break
            elif [ -z "$NODE_IP" ]; then
                NODE_IP="$ip"
                echo "📍 Using private IP: $NODE_IP"
            fi
        fi
    done
fi

# Method 4: Fallback to a placeholder that can be easily replaced
if [ -z "$NODE_IP" ] || [ "$NODE_IP" = "127.0.0.1" ]; then
    NODE_IP="192.168.187.130"  # Use the known working IP as fallback
    echo "⚠️  Using fallback IP (known working): $NODE_IP"
    echo "⚠️  If this is incorrect, manually update the Drupal pages"
fi

echo "🎯 Final Node IP selected: $NODE_IP"

# Enable additional modules first
echo "🔌 Enabling additional modules..."
drush pm:enable menu_ui menu_link_content pathauto token admin_toolbar -y || echo "⚠️  Some modules failed to enable"

# Create a comprehensive homepage content
echo "🏠 Creating comprehensive homepage content..."
drush ev "
\$node = \Drupal::entityTypeManager()->getStorage('node')->create([
    'type' => 'article',
    'title' => 'Welcome to Cloud-Native Demo Platform',
    'body' => [
        'value' => '
            <div class=\"hero-section\" style=\"background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px; border-radius: 8px; margin-bottom: 30px;\">
                <h1 style=\"color: white; font-size: 2.5em; margin-bottom: 15px;\">🚀 Cloud-Native Demo Platform</h1>
                <p style=\"font-size: 1.2em; opacity: 0.9;\">A comprehensive demonstration of modern cloud-native technologies running on Kubernetes</p>
            </div>
            
            <div class=\"overview-section\" style=\"margin-bottom: 30px;\">
                <h2>🌟 Platform Overview</h2>
                <p>This demonstration platform showcases a complete cloud-native architecture built with modern technologies and best practices. The entire infrastructure is containerized and orchestrated using Kubernetes, demonstrating scalability, resilience, and modern deployment strategies.</p>
            </div>
            
            <div class=\"architecture-section\" style=\"margin-bottom: 30px;\">
                <h2>🏗️ Architecture Components</h2>
                <div style=\"display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin: 20px 0;\">
                    <div style=\"border: 1px solid #ddd; padding: 20px; border-radius: 8px; background-color: #f9f9f9;\">
                        <h3>🌐 Content Management</h3>
                        <ul>
                            <li><strong>Drupal 11</strong> - Modern CMS with Mahi theme</li>
                            <li><strong>MySQL 8.0</strong> - Persistent database storage</li>
                            <li><strong>6 Replicas</strong> - High availability setup</li>
                            <li><strong>Persistent Volumes</strong> - Data persistence</li>
                        </ul>
                    </div>
                    <div style=\"border: 1px solid #ddd; padding: 20px; border-radius: 8px; background-color: #f9f9f9;\">
                        <h3>💬 Real-time Communication</h3>
                        <ul>
                            <li><strong>Node.js + Express</strong> - Backend API server</li>
                            <li><strong>WebSocket</strong> - Real-time bidirectional communication</li>
                            <li><strong>Vue.js 3</strong> - Modern frontend framework</li>
                            <li><strong>MongoDB</strong> - Message persistence</li>
                            <li><strong>Redis</strong> - Pub/Sub for multi-replica scaling</li>
                        </ul>
                    </div>
                    <div style=\"border: 1px solid #ddd; padding: 20px; border-radius: 8px; background-color: #f9f9f9;\">
                        <h3>🤖 AI Integration</h3>
                        <ul>
                            <li><strong>Azure Computer Vision</strong> - OCR processing</li>
                            <li><strong>Azure Blob Storage</strong> - File storage</li>
                            <li><strong>Azure SQL Database</strong> - Processing history</li>
                            <li><strong>Vue.js Interface</strong> - File upload UI</li>
                        </ul>
                    </div>
                </div>
            </div>
            
            <div class=\"features-section\" style=\"margin-bottom: 30px;\">
                <h2>⚡ Key Features</h2>
                <div style=\"display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 15px;\">
                    <div style=\"padding: 15px; background-color: #e8f5e9; border-left: 4px solid #4caf50; border-radius: 4px;\">
                        <strong>🔄 Auto-scaling</strong><br>
                        Kubernetes deployments with replica management
                    </div>
                    <div style=\"padding: 15px; background-color: #e3f2fd; border-left: 4px solid #2196f3; border-radius: 4px;\">
                        <strong>🌐 Service Discovery</strong><br>
                        Internal DNS and service mesh communication
                    </div>
                    <div style=\"padding: 15px; background-color: #fff3e0; border-left: 4px solid #ff9800; border-radius: 4px;\">
                        <strong>💾 Data Persistence</strong><br>
                        Persistent volumes for stateful applications
                    </div>
                    <div style=\"padding: 15px; background-color: #fce4ec; border-left: 4px solid #e91e63; border-radius: 4px;\">
                        <strong>🔐 Secret Management</strong><br>
                        Kubernetes secrets for sensitive data
                    </div>
                    <div style=\"padding: 15px; background-color: #f9fbe7; border-left: 4px solid #8bc34a; border-radius: 4px;\">
                        <strong>🏗️ Multi-stage Builds</strong><br>
                        Optimized Docker images for production
                    </div>
                    <div style=\"padding: 15px; background-color: #f3e5f5; border-left: 4px solid #9c27b0; border-radius: 4px;\">
                        <strong>☁️ Cloud Integration</strong><br>
                        Azure services for AI and storage
                    </div>
                </div>
            </div>
            
            <div class=\"applications-section\" style=\"margin-bottom: 30px;\">
                <h2>🚀 Live Applications</h2>
                <div style=\"display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px;\">
                    <div style=\"border: 2px solid #4caf50; padding: 25px; border-radius: 8px; text-align: center; background: linear-gradient(135deg, #a8e6cf 0%, #dcedc8 100%);\">
                        <h3 style=\"color: #2e7d32; margin-bottom: 15px;\">💬 Real-time Chat</h3>
                        <p style=\"color: #388e3c; margin-bottom: 20px;\">Connect and communicate with other users in real-time using WebSocket technology.</p>
                        <a href=\"/chat-application\" style=\"background-color: #4caf50; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; font-weight: bold;\">Launch Chat →</a>
                    </div>
                    <div style=\"border: 2px solid #2196f3; padding: 25px; border-radius: 8px; text-align: center; background: linear-gradient(135deg, #bbdefb 0%, #e3f2fd 100%);\">
                        <h3 style=\"color: #1565c0; margin-bottom: 15px;\">🤖 AI Image Recognition</h3>
                        <p style=\"color: #1976d2; margin-bottom: 20px;\">Upload images and extract text using Azure Computer Vision OCR technology.</p>
                        <a href=\"/ai-image-recognition\" style=\"background-color: #2196f3; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; font-weight: bold;\">Launch OCR →</a>
                    </div>
                </div>
            </div>
            
            <div class=\"tech-stack\" style=\"margin-bottom: 30px;\">
                <h2>💻 Technology Stack</h2>
                <div style=\"display: flex; flex-wrap: wrap; gap: 10px; margin: 15px 0;\">
                    <span style=\"background-color: #007acc; color: white; padding: 5px 10px; border-radius: 15px; font-size: 0.9em;\">Kubernetes</span>
                    <span style=\"background-color: #0db7ed; color: white; padding: 5px 10px; border-radius: 15px; font-size: 0.9em;\">Docker</span>
                    <span style=\"background-color: #68217a; color: white; padding: 5px 10px; border-radius: 15px; font-size: 0.9em;\">Node.js</span>
                    <span style=\"background-color: #4fc08d; color: white; padding: 5px 10px; border-radius: 15px; font-size: 0.9em;\">Vue.js</span>
                    <span style=\"background-color: #0078d4; color: white; padding: 5px 10px; border-radius: 15px; font-size: 0.9em;\">Drupal</span>
                    <span style=\"background-color: #00618a; color: white; padding: 5px 10px; border-radius: 15px; font-size: 0.9em;\">MySQL</span>
                    <span style=\"background-color: #4db33d; color: white; padding: 5px 10px; border-radius: 15px; font-size: 0.9em;\">MongoDB</span>
                    <span style=\"background-color: #d82c20; color: white; padding: 5px 10px; border-radius: 15px; font-size: 0.9em;\">Redis</span>
                    <span style=\"background-color: #0072c6; color: white; padding: 5px 10px; border-radius: 15px; font-size: 0.9em;\">Azure</span>
                    <span style=\"background-color: #239120; color: white; padding: 5px 10px; border-radius: 15px; font-size: 0.9em;\">Nginx</span>
                </div>
            </div>
            
            <div class=\"infrastructure-details\" style=\"background-color: #f5f5f5; padding: 20px; border-radius: 8px; margin-bottom: 30px;\">
                <h2>🎯 Infrastructure Details</h2>
                <div style=\"display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-top: 15px;\">
                    <div><strong>🌐 Drupal CMS:</strong><br>6 replicas, NodePort 30080</div>
                    <div><strong>💬 Chat Backend:</strong><br>5 replicas, NodePort 30088</div>
                    <div><strong>💻 Chat Frontend:</strong><br>1 replica, NodePort 30090</div>
                    <div><strong>🤖 AI Backend:</strong><br>1 replica, NodePort 30101</div>
                    <div><strong>🖼️ AI Frontend:</strong><br>1 replica, NodePort 30180</div>
                    <div><strong>📊 Node IP:</strong><br>$NODE_IP</div>
                </div>
            </div>
            
            <div style=\"text-align: center; margin-top: 40px; padding: 20px; background-color: #e8f5e9; border-radius: 8px;\">
                <p style=\"color: #2e7d32; font-size: 1.1em; margin-bottom: 10px;\">🎓 <strong>Academic Project Demonstration</strong></p>
                <p style=\"color: #388e3c;\">This platform demonstrates modern cloud-native development practices, containerization, and Kubernetes orchestration.</p>
            </div>
        ',
        'format' => 'full_html'
    ],
    'status' => 1,
    'promote' => 1
]);
\$node->save();
echo 'Enhanced homepage created with nid: ' . \$node->id();
" || echo "⚠️  Failed to create homepage"

# Create Chat page
echo "💬 Creating Chat page..."
drush ev "
\$node = \Drupal::entityTypeManager()->getStorage('node')->create([
    'type' => 'page',
    'title' => 'Chat Application',
    'body' => [
        'value' => '
            <div style=\"background: linear-gradient(135deg, #a8e6cf 0%, #dcedc8 100%); padding: 30px; border-radius: 8px; margin-bottom: 20px;\">
                <h1 style=\"color: #2e7d32; margin-bottom: 15px;\">💬 Real-time Chat Application</h1>
                <p style=\"color: #388e3c; font-size: 1.1em;\">Connect and communicate with other users in real-time using WebSocket technology.</p>
            </div>
            
            <div style=\"margin-bottom: 20px;\">
                <h2>🚀 Features</h2>
                <ul style=\"font-size: 1.1em; line-height: 1.6;\">
                    <li><strong>Real-time messaging</strong> - Instant communication via WebSocket</li>
                    <li><strong>Message history</strong> - All messages are persisted in MongoDB</li>
                    <li><strong>Multi-user support</strong> - Chat with multiple users simultaneously</li>
                    <li><strong>Scalable architecture</strong> - 5 backend replicas with Redis pub/sub</li>
                </ul>
            </div>
            
            <div style=\"border: 2px solid #4caf50; border-radius: 8px; overflow: hidden;\">
                <iframe src=\"http://$NODE_IP:30090\" width=\"100%\" height=\"600px\" frameborder=\"0\" style=\"border: none;\"></iframe>
            </div>
        ',
        'format' => 'full_html'
    ],
    'status' => 1,
    'path' => ['alias' => '/chat-application']
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
        'value' => '
            <div style=\"background: linear-gradient(135deg, #bbdefb 0%, #e3f2fd 100%); padding: 30px; border-radius: 8px; margin-bottom: 20px;\">
                <h1 style=\"color: #1565c0; margin-bottom: 15px;\">🤖 AI Image Recognition & OCR</h1>
                <p style=\"color: #1976d2; font-size: 1.1em;\">Upload images and extract text using Azure Computer Vision OCR technology.</p>
            </div>
            
            <div style=\"margin-bottom: 20px;\">
                <h2>🎯 Capabilities</h2>
                <ul style=\"font-size: 1.1em; line-height: 1.6;\">
                    <li><strong>OCR Processing</strong> - Extract text from images using Azure Computer Vision</li>
                    <li><strong>Cloud Storage</strong> - Images stored in Azure Blob Storage</li>
                    <li><strong>Processing History</strong> - Complete history stored in Azure SQL Database</li>
                    <li><strong>Multi-format Support</strong> - Support for various image formats (JPEG, PNG, etc.)</li>
                </ul>
            </div>
            
            <div style=\"border: 2px solid #2196f3; border-radius: 8px; overflow: hidden;\">
                <iframe src=\"http://$NODE_IP:30180\" width=\"100%\" height=\"700px\" frameborder=\"0\" style=\"border: none;\"></iframe>
            </div>
        ',
        'format' => 'full_html'
    ],
    'status' => 1,
    'path' => ['alias' => '/ai-image-recognition']
]);
\$node->save();
echo 'AI OCR page created with nid: ' . \$node->id();
" || echo "⚠️  Failed to create AI OCR page"

# Create main menu and add login link
echo "🔗 Creating main menu with login link..."
drush ev "
// Get or create the main menu
\$menu_storage = \Drupal::entityTypeManager()->getStorage('menu');
\$main_menu = \$menu_storage->load('main');

if (!\$main_menu) {
    \$main_menu = \$menu_storage->create([
        'id' => 'main',
        'label' => 'Main navigation',
        'description' => 'Site main navigation menu.'
    ]);
    \$main_menu->save();
}

// Create menu link storage
\$menu_link_storage = \Drupal::entityTypeManager()->getStorage('menu_link_content');

// First, clean up any existing menu links to avoid duplicates
\$existing_links = \$menu_link_storage->loadByProperties(['menu_name' => 'main']);
foreach (\$existing_links as \$link) {
    \$link->delete();
}

// Update the existing default Home link instead of creating a new one
\$menu_link_manager = \Drupal::service('plugin.manager.menu.link');
\$menu_links = \$menu_link_manager->loadLinksByRoute('<front>');
foreach (\$menu_links as \$menu_link) {
    if (\$menu_link->getMenuName() == 'main') {
        // Update the existing home link
        \$menu_link_manager->updateDefinition(\$menu_link->getPluginId(), [
            'title' => '🏠 Home',
            'weight' => -10,
        ]);
        break;
    }
}

// Add Chat link  
\$chat_link = \$menu_link_storage->create([
    'title' => '💬 Chat',
    'link' => ['uri' => 'internal:/chat-application'],
    'menu_name' => 'main',
    'weight' => -8,
]);
\$chat_link->save();

// Add AI OCR link
\$ai_link = \$menu_link_storage->create([
    'title' => '🤖 AI OCR',
    'link' => ['uri' => 'internal:/ai-image-recognition'],
    'menu_name' => 'main',
    'weight' => -6,
]);
\$ai_link->save();

// Add Login link
\$login_link = \$menu_link_storage->create([
    'title' => '🔐 Login',
    'link' => ['uri' => 'internal:/user/login'],
    'menu_name' => 'main',
    'weight' => 10,
]);
\$login_link->save();

// Add Admin link (only visible to authenticated users)
\$admin_link = \$menu_link_storage->create([
    'title' => '⚙️ Admin',
    'link' => ['uri' => 'internal:/admin'],
    'menu_name' => 'main', 
    'weight' => 15,
]);
\$admin_link->save();

echo 'Main menu updated with login link and navigation items (duplicates removed)';
" || echo "⚠️  Failed to create menu"

# Configure the theme to show the main menu
echo "🎨 Configuring theme to display main menu..."
drush ev "
// Place the main menu block in the primary menu region
\$block_storage = \Drupal::entityTypeManager()->getStorage('block');

// Create main menu block
\$main_menu_block = \$block_storage->create([
    'id' => 'mahi_main_menu',
    'theme' => 'mahi',
    'region' => 'primary_menu',
    'plugin' => 'system_menu_block:main',
    'settings' => [
        'label' => 'Main navigation',
        'label_display' => 0,
        'level' => 1,
        'depth' => 0,
    ],
    'weight' => 0,
]);
\$main_menu_block->save();

echo 'Main menu block placed in theme';
" || echo "⚠️  Failed to configure menu block"

# Set homepage and configure site settings
echo "🏠 Configuring site settings..."
drush config:set system.site page.front /node/1 -y || echo "⚠️  Failed to set front page"

# Configure user registration and permissions
echo "👥 Configuring user settings..."
drush config:set user.settings register visitors_admin_approval -y

# Clear all caches
echo "🧹 Clearing caches..."
drush cache:rebuild

# Set final permissions
echo "🔒 Setting final permissions..."
chown -R www-data:www-data /var/www/html/sites/default

# Create completion marker
echo "📝 Creating installation completion marker..."
touch /var/www/html/sites/default/files/.drupal_installed
echo "Installation completed at: $(date)" > /var/www/html/sites/default/files/.drupal_installed
echo "Node IP used: $NODE_IP" >> /var/www/html/sites/default/files/.drupal_installed
echo "Kubernetes Node IP env: ${KUBERNETES_NODE_IP:-not-set}" >> /var/www/html/sites/default/files/.drupal_installed
echo "Site features: Enhanced homepage, Login menu, Chat integration, AI OCR" >> /var/www/html/sites/default/files/.drupal_installed

echo "🎉 Drupal installation and configuration completed successfully!"
echo "📊 Installation summary:"
echo "   - Site name: Cloud-Native Demo Platform"
echo "   - Admin user: admin / admin123"
echo "   - Theme: Mahi with custom styling"
echo "   - Pages: Enhanced homepage, Chat app, AI OCR app"
echo "   - Menu: Main navigation with login link"
echo "   - Node IP: $NODE_IP"
echo "   - Login URL: http://$NODE_IP:30080/user/login"
echo "   - Admin URL: http://$NODE_IP:30080/admin"
echo ""
echo "🔐 Login Information:"
echo "   - Username: admin"
echo "   - Password: admin123"
echo "   - Direct login: http://$NODE_IP:30080/user/login"